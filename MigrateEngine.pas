unit MigrateEngine;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.StrUtils,
  Vcl.ComCtrls, Vcl.StdCtrls,
  Data.DB,
  BDE.DBTables,                        // BDE per Paradox
  FireDAC.Comp.Client,                 // FireDAC per Firebird
  FireDAC.Comp.DataSet, FireDAC.Stan.Intf,
  FireDAC.Stan.Param,
  FireDAC.DApt;  // 🔧 aggiungi questa riga

type
  TTableReport = record
    TableName: string;
    RecordsCopied: Integer;
    PrimaryKey: string;
    Indices: TStringList;
    ForeignKeys: TStringList;
    AutoIncFields: TStringList;
    Errors: TStringList;
  end;

procedure RunMigrationSelective(ParadoxDB: TDatabase;
                                FBConn: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar;
                                Log: TMemo);

implementation

var
  ReportList: array of TTableReport;

{------------------------------------------------------------------------------}
{  UTILITY }
{------------------------------------------------------------------------------}

procedure ExecSQL(const Conn: TFDConnection; const SQL: string);
begin
  Conn.ExecSQL(SQL);
end;

function FBIdent(const S: string): string;
begin
  Result := StringReplace(S, ' ', '_', [rfReplaceAll]);
end;

function MapFieldTypeToFB(Field: TField): string;
begin
  case Field.DataType of
    ftString, ftWideString: Result := 'VARCHAR(' + Field.Size.ToString + ')';
    ftInteger:              Result := 'INTEGER';
    ftSmallint:             Result := 'SMALLINT';
    ftLargeint:             Result := 'BIGINT';
    ftFloat:                Result := 'DOUBLE PRECISION';
    ftCurrency:             Result := 'NUMERIC(18,4)';
    ftBCD, ftFMTBcd:        Result := 'NUMERIC(18,4)';
    ftDate:                 Result := 'DATE';
    ftTime:                 Result := 'TIME';
    ftDateTime,
    ftTimeStamp:            Result := 'TIMESTAMP';
    ftMemo, ftWideMemo:     Result := 'BLOB SUB_TYPE TEXT';
    ftBlob:                 Result := 'BLOB';
    ftAutoInc:              Result := 'INTEGER';
  else
    Result := 'VARCHAR(100)';
  end;
end;

{------------------------------------------------------------------------------}
{  CREA TABELLA FIREBIRD DA METADATI PARADOX }
{------------------------------------------------------------------------------}

procedure CreateFBTableWithMeta(const TableName: string;
                                ParadoxDB: TDatabase;
                                FBConn: TFDConnection;
                                Log: TMemo;
                                Report: TTableReport);
var
  PX: TTable;
  SQL: TStringList;
  I: Integer;
  Field: TField;
  PKFields: string;
begin
  PX := TTable.Create(nil);
  SQL := TStringList.Create;
  try
    PX.DatabaseName := ParadoxDB.DatabaseName;
    PX.TableName := TableName;
    PX.IndexDefs.Update;
    PX.FieldDefs.Update;
    PX.Open;

    SQL.Add('CREATE TABLE ' + FBIdent(TableName) + ' (');

    PKFields := '';

    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];

      if Field.DataType = ftAutoInc then
        Report.AutoIncFields.Add(Field.FieldName);

      SQL.Add('  ' + FBIdent(Field.FieldName) + ' ' + MapFieldTypeToFB(Field) +
              IfThen(I < PX.FieldCount - 1, ',', ''));

      if (ixPrimary in PX.IndexDefs.GetIndexForFields(Field.FieldName, False).Options) then
      begin
        if PKFields <> '' then PKFields := PKFields + ',';
        PKFields := PKFields + FBIdent(Field.FieldName);
      end;
    end;

    Report.PrimaryKey := PKFields;

    if PKFields <> '' then
      SQL.Add(', CONSTRAINT PK_' + FBIdent(TableName) +
              ' PRIMARY KEY (' + PKFields + ')');

    SQL.Add(');');

    ExecSQL(FBConn, SQL.Text);

    { Indici secondari }
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      if (ixPrimary in PX.IndexDefs[I].Options) then Continue;
      if PX.IndexDefs[I].Fields = '' then Continue;

      SQL.Clear;
      SQL.Add('CREATE INDEX IX_' + FBIdent(TableName) + '_' +
              FBIdent(PX.IndexDefs[I].Name) + ' ON ' + FBIdent(TableName) +
              ' (' + StringReplace(PX.IndexDefs[I].Fields, ';', ',', [rfReplaceAll]) + ');');

      ExecSQL(FBConn, SQL.Text);
      Report.Indices.Add(PX.IndexDefs[I].Name + ' (' + PX.IndexDefs[I].Fields + ')');
    end;

  except
    on E: Exception do
      Report.Errors.Add(E.Message);
  end;

  PX.Free;
  SQL.Free;
end;

function MakeParamList(Count: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Count do
  begin
    Result := Result + '?,';
  end;
  Result := Copy(Result, 1, Length(Result)-1); // rimuove ultima virgola
end;


{------------------------------------------------------------------------------}
{  COPIA DATI PARADOX → FIREBIRD }
{------------------------------------------------------------------------------}

procedure CopyData(const TableName: string;
                   ParadoxDB: TDatabase;
                   FBConn: TFDConnection;
                   Log: TMemo;
                   Report: TTableReport);
var
  PX: TTable;
  FBQuery: TFDQuery;
  I: Integer;
begin
  PX := TTable.Create(nil);
  FBQuery := TFDQuery.Create(nil);
  try
    PX.DatabaseName := ParadoxDB.DatabaseName;
    PX.TableName := TableName;
    PX.Open;

    FBQuery.Connection := FBConn;

  FBQuery.SQL.Text :=
      'INSERT INTO ' + FBIdent(TableName) +
      ' VALUES (' + MakeParamList(PX.FieldCount) + ')';

    while not PX.Eof do
    begin
      FBQuery.Params.Clear;
      for I := 0 to PX.FieldCount - 1 do
        FBQuery.Params.Add.Value := PX.Fields[I].Value;

      try
        FBQuery.ExecSQL;
      except
        on E: Exception do
          Report.Errors.Add(E.Message);
      end;

      PX.Next;
    end;

    Report.RecordsCopied := PX.RecordCount;

  finally
    PX.Free;
    FBQuery.Free;
  end;
end;

{------------------------------------------------------------------------------}
{  FOREIGN KEY EURISTICA }
{------------------------------------------------------------------------------}

procedure CreateForeignKeysHeuristic(const TableName: string;
                                     FBConn: TFDConnection;
                                     Log: TMemo;
                                     Report: TTableReport);
var
  Q: TFDQuery;
  FieldName, RefTable: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FBConn;
    Q.SQL.Text :=
      'SELECT RDB$FIELD_NAME FROM RDB$RELATION_FIELDS ' +
      'WHERE RDB$RELATION_NAME = :T';
    Q.ParamByName('T').AsString := UpperCase(TableName);
    Q.Open;

    while not Q.Eof do
    begin
      FieldName := Trim(Q.Fields[0].AsString);

      if FieldName.EndsWith('_ID') then
      begin
        RefTable := Copy(FieldName, 1, Length(FieldName) - 3);

        try
          FBConn.ExecSQL(
            'ALTER TABLE ' + FBIdent(TableName) +
            ' ADD CONSTRAINT FK_' + FBIdent(TableName) + '_' + FBIdent(FieldName) +
            ' FOREIGN KEY (' + FBIdent(FieldName) + ') REFERENCES ' +
            FBIdent(RefTable) + '(ID);'
          );

          Report.ForeignKeys.Add(FieldName + ' → ' + RefTable);

        except
          Report.Errors.Add('FK fallita: ' + FieldName + ' → ' + RefTable);
        end;
      end;

      Q.Next;
    end;

  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
{  SALVA REPORT HTML }
{------------------------------------------------------------------------------}

procedure SaveHTMLReport(const FileName: string);
var
  SL: TStringList;
  I, J: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="UTF-8">');
    SL.Add('<style>');
    SL.Add('body { font-family: Segoe UI; margin: 20px; }');
    SL.Add('table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }');
    SL.Add('th, td { border: 1px solid #ccc; padding: 8px; }');
    SL.Add('th { background: #eee; }');
    SL.Add('.error { color: red; }');
    SL.Add('</style></head><body>');

    SL.Add('<h1>Report Migrazione Paradox → Firebird</h1>');
    SL.Add('<p>Generato il ' + DateTimeToStr(Now) + '</p>');

    for I := 0 to High(ReportList) do
    begin
      SL.Add('<h2>Tabella: ' + ReportList[I].TableName + '</h2>');
      SL.Add('<table>');
      SL.Add('<tr><th>Campo</th><th>Valore</th></tr>');

      SL.Add('<tr><td>Record copiati</td><td>' +
             ReportList[I].RecordsCopied.ToString + '</td></tr>');
      SL.Add('<tr><td>Primary Key</td><td>' +
             ReportList[I].PrimaryKey + '</td></tr>');

      SL.Add('<tr><td>Indici</td><td><ul>');
      for J := 0 to ReportList[I].Indices.Count - 1 do
        SL.Add('<li>' + ReportList[I].Indices[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Foreign Keys</td><td><ul>');
      for J := 0 to ReportList[I].ForeignKeys.Count - 1 do
        SL.Add('<li>' + ReportList[I].ForeignKeys[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Autoincrement</td><td><ul>');
      for J := 0 to ReportList[I].AutoIncFields.Count - 1 do
        SL.Add('<li>' + ReportList[I].AutoIncFields[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Errori</td><td><ul>');
      for J := 0 to ReportList[I].Errors.Count - 1 do
        SL.Add('<li class="error">' + ReportList[I].Errors[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('</table>');
    end;

    SL.Add('</body></html>');
    SL.SaveToFile(FileName, TEncoding.UTF8);

  finally
    SL.Free;
  end;
end;

{------------------------------------------------------------------------------}
{  MAIN }
{------------------------------------------------------------------------------}

procedure RunMigrationSelective(ParadoxDB: TDatabase;
                                FBConn: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar;
                                Log: TMemo);
var
  I: Integer;
  T: string;
begin
  SetLength(ReportList, Tables.Count);

  Progress.Max := Tables.Count;
  Progress.Position := 0;

  for I := 0 to Tables.Count - 1 do
  begin
    T := Tables[I];

    ReportList[I].TableName := T;
    ReportList[I].Indices := TStringList.Create;
    ReportList[I].ForeignKeys := TStringList.Create;
    ReportList[I].AutoIncFields := TStringList.Create;
    ReportList[I].Errors := TStringList.Create;

    Log.Lines.Add('Creazione schema: ' + T);
    CreateFBTableWithMeta(T, ParadoxDB, FBConn, Log, ReportList[I]);

    Log.Lines.Add('Copia dati: ' + T);
    CopyData(T, ParadoxDB, FBConn, Log, ReportList[I]);

    Log.Lines.Add('Foreign key (euristica): ' + T);
    CreateForeignKeysHeuristic(T, FBConn, Log, ReportList[I]);

    Progress.Position := Progress.Position + 1;
  end;

  ForceDirectories('.\Report');
  SaveHTMLReport('.\Report\MigrationReport.html');

  ShellExecute(0, 'open', PChar('.\Report\MigrationReport.html'), nil, nil, SW_SHOWNORMAL);
end;

end.

