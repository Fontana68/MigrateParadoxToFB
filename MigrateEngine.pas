unit MigrateEngine;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils,
  Vcl.ComCtrls, Vcl.StdCtrls,
  Data.DB,
  Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client,
  FireDAC.Comp.BatchMove, FireDAC.Comp.BatchMove.DataSet,
  FireDAC.Stan.Intf, FireDAC.Stan.Param, FireDAC.Stan.Option;

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

procedure RunMigrationSelective(ConnPX, ConnFB: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar; Log: TMemo);

implementation

var
  ReportList: array of TTableReport;

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
    ftString, ftWideString:
      Result := 'VARCHAR(' + Field.Size.ToString + ')';
    ftInteger:   Result := 'INTEGER';
    ftSmallint:  Result := 'SMALLINT';
    ftLargeint:  Result := 'BIGINT';
    ftFloat:     Result := 'DOUBLE PRECISION';
    ftCurrency:  Result := 'NUMERIC(18,4)';
    ftBCD, ftFMTBcd:
      Result := 'NUMERIC(18,4)';
    ftDate:      Result := 'DATE';
    ftTime:      Result := 'TIME';
    ftDateTime,
    ftTimeStamp: Result := 'TIMESTAMP';
    ftMemo, ftWideMemo:
      Result := 'BLOB SUB_TYPE TEXT';
    ftBlob:      Result := 'BLOB';
    ftAutoInc:   Result := 'INTEGER';
  else
    Result := 'VARCHAR(100)';
  end;
end;

procedure CreateFBTableWithMeta(const TableName: string; ConnPX, ConnFB: TFDConnection;
                                Log: TMemo; Report: TTableReport);
var
  PX: TFDTable;
  SQL: TStringList;
  I: Integer;
  Field: TField;
  PKFields: string;
begin
  PX := TFDTable.Create(nil);
  SQL := TStringList.Create;
  try
    PX.Connection := ConnPX;
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
        if PKFields <> '' then
          PKFields := PKFields + ',';
        PKFields := PKFields + FBIdent(Field.FieldName);
      end;
    end;

    Report.PrimaryKey := PKFields;

    if PKFields <> '' then
    begin
      SQL.Add(' ,CONSTRAINT PK_' + FBIdent(TableName) +
              ' PRIMARY KEY (' + PKFields + ')');
    end;

    SQL.Add(');');

    ExecSQL(ConnFB, SQL.Text);

    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      if (ixPrimary in PX.IndexDefs[I].Options) then
        Continue;

      if PX.IndexDefs[I].Fields = '' then
        Continue;

      SQL.Clear;
      SQL.Add('CREATE INDEX IX_' + FBIdent(TableName) + '_' +
              FBIdent(PX.IndexDefs[I].Name) + ' ON ' + FBIdent(TableName) +
              ' (' + StringReplace(PX.IndexDefs[I].Fields, ';', ',', [rfReplaceAll]) + ');');

      ExecSQL(ConnFB, SQL.Text);
      Report.Indices.Add(PX.IndexDefs[I].Name + ' (' + PX.IndexDefs[I].Fields + ')');
    end;

    for I := 0 to Report.AutoIncFields.Count - 1 do
    begin
      SQL.Clear;
      SQL.Add('CREATE SEQUENCE GEN_' + FBIdent(TableName) + '_' + FBIdent(Report.AutoIncFields[I]) + ';');
      ExecSQL(ConnFB, SQL.Text);

      SQL.Clear;
      SQL.Add('CREATE TRIGGER BI_' + FBIdent(TableName) + '_' + FBIdent(Report.AutoIncFields[I]));
      SQL.Add('FOR ' + FBIdent(TableName));
      SQL.Add('ACTIVE BEFORE INSERT POSITION 0');
      SQL.Add('AS');
      SQL.Add('BEGIN');
      SQL.Add('  IF (NEW.' + FBIdent(Report.AutoIncFields[I]) + ' IS NULL) THEN');
      SQL.Add('    NEW.' + FBIdent(Report.AutoIncFields[I]) + ' = NEXT VALUE FOR GEN_' +
              FBIdent(TableName) + '_' + FBIdent(Report.AutoIncFields[I]) + ';');
      SQL.Add('END;');
      ExecSQL(ConnFB, SQL.Text);
    end;

  except
    on E: Exception do
      Report.Errors.Add(E.Message);
  end;

  PX.Free;
  SQL.Free;
end;

procedure CreateForeignKeysHeuristic(const TableName: string; ConnFB: TFDConnection;
                                     Log: TMemo; Report: TTableReport);
var
  Q: TFDQuery;
  FieldName, RefTable: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := ConnFB;
    Q.SQL.Text := 'SELECT RDB$FIELD_NAME FROM RDB$RELATION_FIELDS ' +
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
          ConnFB.ExecSQL(
            'ALTER TABLE ' + FBIdent(TableName) +
            ' ADD CONSTRAINT FK_' + FBIdent(TableName) + '_' + FBIdent(FieldName) +
            ' FOREIGN KEY (' + FBIdent(FieldName) + ') REFERENCES ' + FBIdent(RefTable) + '(ID);'
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

procedure CopyData(const TableName: string; ConnPX, ConnFB: TFDConnection;
                   Log: TMemo; Report: TTableReport);
var
  Src: TFDTable;
  Dst: TFDQuery;
  Move: TFDBatchMove;
  Reader: TFDBatchMoveDataSetReader;
  Writer: TFDBatchMoveDataSetWriter;
begin
  Src := TFDTable.Create(nil);
  Dst := TFDQuery.Create(nil);
  Move := TFDBatchMove.Create(nil);
  Reader := TFDBatchMoveDataSetReader.Create(nil);
  Writer := TFDBatchMoveDataSetWriter.Create(nil);
  try
    Src.Connection := ConnPX;
    Src.TableName := TableName;

    Dst.Connection := ConnFB;
    Dst.SQL.Text := 'SELECT * FROM ' + FBIdent(TableName);

    Reader.DataSet := Src;
    Writer.DataSet := Dst;

    Move.Reader := Reader;
    Move.Writer := Writer;
    Move.Options := [poClearDest, poIdentityInsert];
    Move.Execute;

    Report.RecordsCopied := Src.RecordCount;

  except
    on E: Exception do
      Report.Errors.Add(E.Message);
  end;

  Src.Free;
  Dst.Free;
  Move.Free;
  Reader.Free;
  Writer.Free;
end;

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

      SL.Add('<tr><td>Record copiati</td><td>' + ReportList[I].RecordsCopied.ToString + '</td></tr>');
      SL.Add('<tr><td>Primary Key</td><td>' + ReportList[I].PrimaryKey + '</td></tr>');

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

procedure RunMigrationSelective(ConnPX, ConnFB: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar; Log: TMemo);
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
    CreateFBTableWithMeta(T, ConnPX, ConnFB, Log, ReportList[I]);

    Log.Lines.Add('Copia dati: ' + T);
    CopyData(T, ConnPX, ConnFB, Log, ReportList[I]);

    Log.Lines.Add('Foreign key (euristica): ' + T);
    CreateForeignKeysHeuristic(T, ConnFB, Log, ReportList[I]);

    Progress.Position := Progress.Position + 1;
  end;

  ForceDirectories('.\Report');
  SaveHTMLReport('.\Report\MigrationReport.html');

  ShellExecute(0, 'open', PChar('.\Report\MigrationReport.html'), nil, nil, SW_SHOWNORMAL);
end;

end.
