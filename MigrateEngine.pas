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
  UseQuotedIdentifiers: Boolean;

  // helper locale per identificatori (con o senza doppi apici)
  function Ident(const S: string): string;
  begin
    if UseQuotedIdentifiers then
      Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
    else
      Result := S; // Firebird converte non-quoted in MAIUSCOLO
  end;

begin
  UseQuotedIdentifiers := False; // metti True se vuoi forzare "Client","ID_CLIENT" ecc.

  PX := TTable.Create(nil);
  SQL := TStringList.Create;
  try
    // Imposta TTable per la tabella Paradox
    PX.DatabaseName := ParadoxDB.DatabaseName;
    PX.TableName := TableName;

    // Aggiorna metadati e apri la tabella; se fallisce, logga e esci
    try
      PX.IndexDefs.Update;
      PX.FieldDefs.Update;
      PX.Open;
    except
      on E: Exception do
      begin
        Report.Errors.Add('Errore apertura tabella Paradox ' + TableName + ': ' + E.ClassName + ' - ' + E.Message);
        Exit;
      end;
    end;

    // Costruzione CREATE TABLE
    SQL.Clear;
    SQL.Add('CREATE TABLE ' + Ident(TableName) + ' (');

    PKFields := '';

    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];

      // registra campi autoinc trovati
      if Field.DataType = ftAutoInc then
        Report.AutoIncFields.Add(Field.FieldName);

      // aggiungi definizione campo
      SQL.Add('  ' + Ident(Field.FieldName) + ' ' + MapFieldTypeToFB(Field) +
              IfThen(I < PX.FieldCount - 1, ',', ''));

      // verifica se il campo è parte della PK (usando la funzione robusta FieldIsPrimary)
      if FieldIsPrimary(PX, Field.FieldName, Log) then
      begin
        if PKFields <> '' then PKFields := PKFields + ',';
        PKFields := PKFields + Ident(Field.FieldName);
      end;
    end;

    // aggiungi constraint PK se presente
    if PKFields <> '' then
      SQL.Add(', CONSTRAINT ' + Ident('PK_' + TableName) + ' PRIMARY KEY (' + PKFields + ')');

    SQL.Add(');');

    // --- diagnostica prima di eseguire ---
    Report.Errors.Add('DEBUG: Preparazione CREATE TABLE per ' + TableName);
    Report.Errors.Add('DEBUG: SQL = ' + sLineBreak + SQL.Text);

    // Verifica FBConn
    if not Assigned(FBConn) then
    begin
      Report.Errors.Add('FBConn non assegnata per CREATE TABLE ' + TableName);
      Exit;
    end;

    Report.Errors.Add('DEBUG: FBConn.Connected=' + BoolToStr(FBConn.Connected, True));
    Report.Errors.Add('DEBUG: FBConn.Params.Database=' + FBConn.Params.Values['Database']);

    // prova ad aprire la connessione se chiusa
    if not FBConn.Connected then
    begin
      try
        FBConn.Connected := True;
      except
        on E: Exception do
        begin
          Report.Errors.Add('Impossibile connettersi a Firebird: ' + E.ClassName + ' - ' + E.Message);
          Exit;
        end;
      end;
    end;

    // Opzionale: se vuoi eliminare la tabella esistente prima di creare, decommenta
    try
      ExecSQL(FBConn, 'DROP TABLE ' + Ident(TableName) + ';');
    except
      // ignora errori di DROP (es. tabella non esiste)
    end;

    // Esegui DDL in transazione con logging dettagliato
    try
      if not FBConn.InTransaction then
        FBConn.StartTransaction;
      ExecSQL(FBConn, SQL.Text);
      FBConn.Commit;
    except
      on E: Exception do
      begin
        try
          if FBConn.InTransaction then
            FBConn.Rollback;
        except
          // ignora errori rollback
        end;
        Report.Errors.Add(Format('Errore CREATE TABLE %s: %s - %s', [TableName, E.ClassName, E.Message]));
        Report.Errors.Add('DEBUG: SQL che ha fallito: ' + sLineBreak + SQL.Text);
        Exit;
      end;
    end;

    // --- crea indici secondari (non primari) ---
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      if (ixPrimary in PX.IndexDefs[I].Options) then Continue;
      if PX.IndexDefs[I].Fields = '' then Continue;

      SQL.Clear;
      SQL.Add('CREATE INDEX ' + Ident('IX_' + TableName + '_' + PX.IndexDefs[I].Name) +
              ' ON ' + Ident(TableName) + ' (' +
              StringReplace(PX.IndexDefs[I].Fields, ';', ',', [rfReplaceAll]) + ');');

      try
        ExecSQL(FBConn, SQL.Text);
        Report.Indices.Add(PX.IndexDefs[I].Name + ' (' + PX.IndexDefs[I].Fields + ')');
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE INDEX ' + PX.IndexDefs[I].Name + ': ' + E.ClassName + ' - ' + E.Message);
      end;
    end;

    // --- crea SEQUENCE e TRIGGER per campi autoinc trovati ---
    for I := 0 to Report.AutoIncFields.Count - 1 do
    begin
      SQL.Clear;
      SQL.Add('CREATE SEQUENCE ' + Ident('GEN_' + TableName + '_' + Report.AutoIncFields[I]) + ';');
      try
        ExecSQL(FBConn, SQL.Text);
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE SEQUENCE: ' + E.ClassName + ' - ' + E.Message);
      end;

      SQL.Clear;
      SQL.Add('CREATE TRIGGER ' + Ident('BI_' + TableName + '_' + Report.AutoIncFields[I]));
      SQL.Add('FOR ' + Ident(TableName));
      SQL.Add('ACTIVE BEFORE INSERT POSITION 0');
      SQL.Add('AS');
      SQL.Add('BEGIN');
      SQL.Add('  IF (NEW.' + Ident(Report.AutoIncFields[I]) + ' IS NULL) THEN');
      SQL.Add('    NEW.' + Ident(Report.AutoIncFields[I]) + ' = NEXT VALUE FOR ' +
              Ident('GEN_' + TableName + '_' + Report.AutoIncFields[I]) + ';');
      SQL.Add('END;');

      try
        ExecSQL(FBConn, SQL.Text);
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE TRIGGER: ' + E.ClassName + ' - ' + E.Message);
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

