unit MigrateEngine;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.StrUtils,
  Vcl.ComCtrls, Vcl.StdCtrls,
  Data.DB, BDE.DBTables,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  FireDAC.Stan.Intf, FireDAC.Stan.Param, FireDAC.DApt;

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

{----------------------------- utilities ------------------------------------}

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
    ftDateTime, ftTimeStamp:Result := 'TIMESTAMP';
    ftMemo, ftWideMemo:     Result := 'BLOB SUB_TYPE TEXT';
    ftBlob:                 Result := 'BLOB';
    ftAutoInc:              Result := 'INTEGER';
  else
    Result := 'VARCHAR(100)';
  end;
end;

function NormalizeIndexFields(const S: string): TStringList;
var
  tmp: string;
  parts: TArray<string>;
  i: Integer;
begin
  Result := TStringList.Create;
  tmp := StringReplace(S, ';', ',', [rfReplaceAll]);
  tmp := StringReplace(tmp, ' ', '', [rfReplaceAll]);
  if tmp = '' then Exit;
  parts := tmp.Split([',']);
  for i := 0 to Length(parts) - 1 do
    if parts[i] <> '' then
      Result.Add(UpperCase(parts[i]));
end;

function FieldIsPrimary(PX: TTable; const AFieldName: string; Log: TMemo): Boolean;
var
  i, j: Integer;
  idxDef: TIndexDef;
  fieldsList: TStringList;
  fName: string;
begin
  Result := False;
  if (PX = nil) or (AFieldName = '') then Exit;

  try
    PX.IndexDefs.Update;
  except
    // se Update fallisce, logga e esci
    if Assigned(Log) then Log.Lines.Add('Warning: IndexDefs.Update failed for ' + PX.TableName);
    Exit;
  end;

  for i := 0 to PX.IndexDefs.Count - 1 do
  begin
    idxDef := PX.IndexDefs[i];
    if idxDef = nil then Continue;

    // solo indici marcati come primari
    if not (ixPrimary in idxDef.Options) then Continue;

    fieldsList := NormalizeIndexFields(idxDef.Fields);
    try
      for j := 0 to fieldsList.Count - 1 do
      begin
        fName := fieldsList[j];
        if SameText(fName, UpperCase(AFieldName)) then
        begin
          Result := True;
          Exit;
        end;
      end;
    finally
      fieldsList.Free;
    end;
  end;

  // fallback: campo chiamato ID o che termina con _ID
  if not Result then
    if SameText(AFieldName, 'ID') or AnsiEndsText('_ID', AFieldName) then
      Result := True;
end;

function MakeParamList(Count: Integer): string;
var
  i: Integer;
begin
  Result := '';
  if Count <= 0 then Exit;
  for i := 1 to Count do
  begin
    Result := Result + ':p' + IntToStr(i);
    if i < Count then
      Result := Result + ',';
  end;
end;

{----------------------------- CreateFBTableWithMeta ------------------------}

procedure CreateFBTableWithMeta(const TableName: string;
                                ParadoxDB: TDatabase;
                                FBConn: TFDConnection;
                                Log: TMemo;
                                var Report: TTableReport);
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
    try
      PX.IndexDefs.Update;
      PX.FieldDefs.Update;
      PX.Open;
    except
      on E: Exception do
      begin
        Report.Errors.Add('Errore apertura tabella ' + TableName + ': ' + E.Message);
        Exit;
      end;
    end;

    SQL.Add('CREATE TABLE ' + FBIdent(TableName) + ' (');

    PKFields := '';

    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];

      if Field.DataType = ftAutoInc then
        Report.AutoIncFields.Add(Field.FieldName);

      SQL.Add('  ' + FBIdent(Field.FieldName) + ' ' + MapFieldTypeToFB(Field) +
              IfThen(I < PX.FieldCount - 1, ',', ''));

      // usa la funzione robusta per verificare PK
      if FieldIsPrimary(PX, Field.FieldName, Log) then
      begin
        if PKFields <> '' then PKFields := PKFields + ',';
        PKFields := PKFields + FBIdent(Field.FieldName);
      end;
    end;

    if PKFields <> '' then
      SQL.Add(', CONSTRAINT PK_' + FBIdent(TableName) + ' PRIMARY KEY (' + PKFields + ')');

    SQL.Add(');');

    try
      ExecSQL(FBConn, SQL.Text);
    except
      on E: Exception do
        Report.Errors.Add('Errore CREATE TABLE ' + TableName + ': ' + E.Message);
    end;

    // Indici secondari
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      if (ixPrimary in PX.IndexDefs[I].Options) then Continue;
      if PX.IndexDefs[I].Fields = '' then Continue;

      SQL.Clear;
      SQL.Add('CREATE INDEX IX_' + FBIdent(TableName) + '_' +
              FBIdent(PX.IndexDefs[I].Name) + ' ON ' + FBIdent(TableName) +
              ' (' + StringReplace(PX.IndexDefs[I].Fields, ';', ',', [rfReplaceAll]) + ');');

      try
        ExecSQL(FBConn, SQL.Text);
        Report.Indices.Add(PX.IndexDefs[I].Name + ' (' + PX.IndexDefs[I].Fields + ')');
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE INDEX ' + PX.IndexDefs[I].Name + ': ' + E.Message);
      end;
    end;

    // Se ci sono campi autoincrement, crea sequence e trigger
    for I := 0 to Report.AutoIncFields.Count - 1 do
    begin
      SQL.Clear;
      SQL.Add('CREATE SEQUENCE GEN_' + FBIdent(TableName) + '_' + FBIdent(Report.AutoIncFields[I]) + ';');
      try
        ExecSQL(FBConn, SQL.Text);
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE SEQUENCE: ' + E.Message);
      end;

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

      try
        ExecSQL(FBConn, SQL.Text);
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE TRIGGER: ' + E.Message);
      end;
    end;

  finally
    PX.Free;
    SQL.Free;
  end;
end;

{----------------------------- CopyData ------------------------------------}

procedure CopyData(const TableName: string;
                   ParadoxDB: TDatabase;
                   FBConn: TFDConnection;
                   Log: TMemo;
                   var Report: TTableReport);
var
  PX: TTable;
  FBQuery: TFDQuery;
  I: Integer;
  paramName: string;
begin
  PX := TTable.Create(nil);
  FBQuery := TFDQuery.Create(nil);
  try
    PX.DatabaseName := ParadoxDB.DatabaseName;
    PX.TableName := TableName;
    try
      PX.Open;
    except
      on E: Exception do
      begin
        Report.Errors.Add('Errore apertura tabella per copia ' + TableName + ': ' + E.Message);
        Exit;
      end;
    end;

    FBQuery.Connection := FBConn;
    FBQuery.SQL.Text := 'INSERT INTO ' + FBIdent(TableName) + ' VALUES (' + MakeParamList(PX.FieldCount) + ')';
    FBQuery.Prepare;

    while not PX.Eof do
    begin
      try
        // assegna parametri per nome :p1, :p2, ...
        for I := 0 to PX.FieldCount - 1 do
        begin
          paramName := 'p' + IntToStr(I + 1);
          FBQuery.ParamByName(paramName).Value := PX.Fields[I].Value;
        end;

        FBQuery.ExecSQL;
      except
        on E: Exception do
          Report.Errors.Add('Errore inserimento in ' + TableName + ': ' + E.Message);
      end;

      PX.Next;
    end;

    // RecordCount può essere costoso su alcune tabelle; usiamo il valore corrente
    try
      Report.RecordsCopied := PX.RecordCount;
    except
      Report.RecordsCopied := 0;
    end;

  finally
    PX.Free;
    FBQuery.Free;
  end;
end;

{----------------------------- Foreign keys heuristic ----------------------}

procedure CreateForeignKeysHeuristic(const TableName: string;
                                     FBConn: TFDConnection;
                                     Log: TMemo;
                                     var Report: TTableReport);
var
  Q: TFDQuery;
  FieldName, RefTable: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FBConn;
    Q.SQL.Text := 'SELECT RDB$FIELD_NAME FROM RDB$RELATION_FIELDS WHERE RDB$RELATION_NAME = :T';
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

{----------------------------- SaveHTMLReport --------------------------------}

procedure SaveHTMLReport(const FileName: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="UTF-8">');
    SL.Add('<style>body{font-family:Segoe UI;margin:20px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px}th{background:#eee}.error{color:red}</style>');
    SL.Add('</head><body>');
    SL.Add('<h1>Report Migrazione Paradox → Firebird</h1>');
    SL.Add('<p>Generato il ' + DateTimeToStr(Now) + '</p>');
    SL.Add('</body></html>');
    SL.SaveToFile(FileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

{----------------------------- RunMigrationSelective ------------------------}

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

