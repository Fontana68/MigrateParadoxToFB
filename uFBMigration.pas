unit uFBMigration;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.RegularExpressions,
  System.IOUtils,

  FireDAC.Comp.Client, FireDAC.Stan.Param, Data.DB;


function FieldExists(const Fields: TFields; const FieldName: string): Boolean;
function TriggerExists(const Conn: TFDConnection; const TriggerName: string): Boolean;
function ProcedureExists(const Conn: TFDConnection; const ProcName: string): Boolean;
function ViewExists(const Conn: TFDConnection; const ViewName: string): Boolean;
function IndexExists(const Conn: TFDConnection; const IndexName: string): Boolean;
function ConstraintExists(const Conn: TFDConnection; const ConstraintName: string): Boolean;
function GeneratorExists(const Conn: TFDConnection; const GenName: string): Boolean;

procedure AddItemToJSON(const Name, Status: string; const JSON: TJSONObject);

procedure CreateTriggersForTable(
  const Conn: TFDConnection;
  const TableName, PKField, GeneratorName: string;
  const Fields: TFields;
  const Log: TStrings;
  const JSON: TJSONObject);


implementation

const
  // elenco minimale di keyword SQL/Firebird; estendi se necessario
  SQL_KEYWORDS: array[0..28] of string = (
    'DATE','TIME','TIMESTAMP','USER','PASSWORD','ORDER','GROUP','SELECT',
    'INSERT','UPDATE','DELETE','TABLE','INDEX','CONSTRAINT','PRIMARY',
    'KEY','TRIGGER','GENERATOR','SEQUENCE','VALUES','FROM','WHERE','AND',
    'OR','NOT','NULL','LIKE','IN','BETWEEN'
  );


{------------------------------------------------------------------------------}
function FieldExists(const Fields: TFields; const FieldName: string): Boolean;
begin
  Result := Fields.FindField(FieldName) <> nil;
end;

{------------------------------------------------------------------------------}
function TriggerExists(const Conn: TFDConnection; const TriggerName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$TRIGGER_NAME FROM RDB$TRIGGERS ' +
      'WHERE RDB$TRIGGER_NAME = :N';
    Q.ParamByName('N').AsString := UpperCase(TriggerName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
function ProcedureExists(const Conn: TFDConnection; const ProcName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$PROCEDURE_NAME FROM RDB$PROCEDURES ' +
      'WHERE RDB$PROCEDURE_NAME = :N';
    Q.ParamByName('N').AsString := UpperCase(ProcName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
function ViewExists(const Conn: TFDConnection; const ViewName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$RELATION_NAME FROM RDB$RELATIONS ' +
      'WHERE RDB$RELATION_NAME = :N AND RDB$VIEW_SOURCE IS NOT NULL';
    Q.ParamByName('N').AsString := UpperCase(ViewName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
function IndexExists(const Conn: TFDConnection; const IndexName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$INDEX_NAME FROM RDB$INDICES ' +
      'WHERE RDB$INDEX_NAME = :N';
    Q.ParamByName('N').AsString := UpperCase(IndexName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
function ConstraintExists(const Conn: TFDConnection; const ConstraintName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$CONSTRAINT_NAME FROM RDB$RELATION_CONSTRAINTS ' +
      'WHERE RDB$CONSTRAINT_NAME = :N';
    Q.ParamByName('N').AsString := UpperCase(ConstraintName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
function GeneratorExists(const Conn: TFDConnection; const GenName: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$GENERATOR_NAME FROM RDB$GENERATORS ' +
      'WHERE RDB$GENERATOR_NAME = :N';
    Q.ParamByName('N').AsString := UpperCase(GenName);
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

{------------------------------------------------------------------------------}
procedure AddItemToJSON(const Name, Status: string; const JSON: TJSONObject);
var Item: TJSONObject;
begin
  Item := TJSONObject.Create;
  Item.AddPair('name', Name);
  Item.AddPair('status', Status);
  JSON.AddPair(Name, Item);
end;

{------------------------------------------------------------------------------}
(*
esempio di uso->

var
  JSON: TJSONObject;
begin
  JSON := TJSONObject.Create;
  AddTriggerToJSON('CLIENT_BI', 'created', JSON);
  AddTriggerToJSON('CLIENT_BU_UPDATED', 'exists', JSON);
  Log.Add(JSON.ToJSON);
end;
*)

procedure AddTriggerToJSON(
  const TriggerName, Status: string;
  const JSON: TJSONObject);
var
  Item: TJSONObject;
begin
  Item := TJSONObject.Create;
  Item.AddPair('name', TriggerName);
  Item.AddPair('status', Status);
  JSON.AddPair(TriggerName, Item);
end;

{----------------------------------------------------------------------------}
function IsSqlKeyword(const S: string): Boolean;
var
  i: Integer;
begin
  for i := Low(SQL_KEYWORDS) to High(SQL_KEYWORDS) do
    if SameText(S, SQL_KEYWORDS[i]) then
      Exit(True);
  Result := False;
end;

{-----------------------------------------------------------------}
function NeedsQuoting(const S: string): Boolean;
begin
  // vuoto -> quotare
  if S = '' then
    Exit(True);

  // se non è composto solo da lettere, numeri o underscore -> quotare
  if not TRegEx.IsMatch(S, '^[A-Za-z0-9_]+$') then
    Exit(True);

  // se inizia con numero -> quotare (per sicurezza)
  if CharInSet(S[1], ['0'..'9']) then
    Exit(True);

  // se è keyword SQL -> quotare
  if IsSqlKeyword(S) then
    Exit(True);

  Result := False;
end;

{-----------------------------------------------------------------}
function Ident(const S: string): string;
var
  tmp: string;
begin
  tmp := Trim(S);
  if NeedsQuoting(tmp) then
  begin
    // raddoppia eventuali doppi apici interni
    tmp := StringReplace(tmp, '"', '""', [rfReplaceAll]);
    Result := '"' + tmp + '"';
  end
  else
    Result := tmp;
end;


{------------------------------------------------------------------------------}
function GenerateTriggerBeforeInsertID(const TableName, PKField, GeneratorName: string): string;
begin
  Result :=
    'CREATE TRIGGER ' + Ident(TableName + '_BI') + ' FOR ' + Ident(TableName) + sLineBreak +
    'ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  IF (NEW.' + Ident(PKField) + ' IS NULL) THEN' + sLineBreak +
    '    NEW.' + Ident(PKField) + ' = NEXT VALUE FOR ' + Ident(GeneratorName) + ';' + sLineBreak +
    'END';
end;

{------------------------------------------------------------------------------}
function GenerateTriggerProtectID(const TableName, PKField: string): string;
begin
  Result :=
    'CREATE TRIGGER ' + Ident(TableName + '_BU_PROTECT_ID') + ' FOR ' + Ident(TableName) + sLineBreak +
    'ACTIVE BEFORE UPDATE POSITION 0' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  IF (NEW.' + Ident(PKField) + ' <> OLD.' + Ident(PKField) + ') THEN' + sLineBreak +
    '    NEW.' + Ident(PKField) + ' = OLD.' + Ident(PKField) + ';' + sLineBreak +
    'END';
end;

{------------------------------------------------------------------------------}
function GenerateTriggerCreatedAt(const TableName: string): string;
begin
  Result :=
    'CREATE TRIGGER ' + Ident(TableName + '_BI_CREATED') + ' FOR ' + Ident(TableName) + sLineBreak +
    'ACTIVE BEFORE INSERT POSITION 1' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  IF (NEW."CREATED_AT" IS NULL) THEN' + sLineBreak +
    '    NEW."CREATED_AT" = CURRENT_TIMESTAMP;' + sLineBreak +
    'END';
end;

{------------------------------------------------------------------------------}
function GenerateTriggerUpdatedAt(const TableName: string): string;
begin
  Result :=
    'CREATE TRIGGER ' + Ident(TableName + '_BU_UPDATED') + ' FOR ' + Ident(TableName) + sLineBreak +
    'ACTIVE BEFORE UPDATE POSITION 1' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  NEW."UPDATED_AT" = CURRENT_TIMESTAMP;' + sLineBreak +
    'END';
end;

{------------------------------------------------------------------------------}
function GenerateTriggerSoftDelete(const TableName: string): string;
begin
  Result :=
    'CREATE TRIGGER ' + Ident(TableName + '_BU_SOFTDELETE') + ' FOR ' + Ident(TableName) + sLineBreak +
    'ACTIVE BEFORE UPDATE POSITION 2' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  IF (NEW."DELETED" = 1 AND OLD."DELETED" = 0) THEN' + sLineBreak +
    '    NEW."DELETED_AT" = CURRENT_TIMESTAMP;' + sLineBreak +
    'END';
end;


{------------------------------------------------------------------------------}
procedure DropTrigger(const Conn: TFDConnection; const TriggerName: string; Log: TStrings);
var
  SQL: string;
begin
  if TriggerExists(Conn, TriggerName) then
  begin
    SQL := 'DROP TRIGGER ' + Ident(TriggerName);
    Conn.ExecSQL(SQL);
    Log.Add('<li>Eliminato trigger: ' + TriggerName + '</li>');
  end
  else
    Log.Add('<li>Trigger non esistente: ' + TriggerName + '</li>');
end;

{------------------------------------------------------------------------------}
procedure DropAndRecreateTrigger(
  const Conn: TFDConnection;
  const TriggerName, SQLCreate: string;
  Log: TStrings);
begin
  Conn.StartTransaction;
  try
    if TriggerExists(Conn, TriggerName) then
    begin
      Conn.ExecSQL('DROP TRIGGER ' + Ident(TriggerName));
      Log.Add('<li>Drop: ' + TriggerName + '</li>');
    end;

    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Create: ' + TriggerName + '</li>');

    Conn.Commit;
  except
    on E: Exception do
    begin
      Conn.Rollback;
      Log.Add('<li style="color:red;">Errore Drop+Recreate ' + TriggerName + ': ' + E.Message + '</li>');
      raise;
    end;
  end;
end;

{------------------------------------------------------------------------------}
procedure EnsureTrigger(
  const Conn: TFDConnection;
  const TriggerName, SQLCreate: string;
  Log: TStrings);
begin
  if not TriggerExists(Conn, TriggerName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Creato: ' + TriggerName + '</li>');
  end
  else
    Log.Add('<li>Esiste già: ' + TriggerName + '</li>');
end;

{------------------------------------------------------------------------------}
procedure EnsureProcedure(
  const Conn: TFDConnection;
  const ProcName, SQLCreate: string;
  Log: TStrings;
  JSON: TJSONObject);
begin
  if not ProcedureExists(Conn, ProcName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Procedura creata: ' + ProcName + '</li>');
    AddTriggerToJSON(ProcName, 'created', JSON);
  end
  else
  begin
    Log.Add('<li>Procedura esistente: ' + ProcName + '</li>');
    AddTriggerToJSON(ProcName, 'exists', JSON);
  end;
end;


{------------------------------------------------------------------------------}
procedure EnsureView(
  const Conn: TFDConnection;
  const ViewName, SQLCreate: string;
  Log: TStrings;
  JSON: TJSONObject);
begin
  if not ViewExists(Conn, ViewName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Vista creata: ' + ViewName + '</li>');
    AddTriggerToJSON(ViewName, 'created', JSON);
  end
  else
  begin
    Log.Add('<li>Vista esistente: ' + ViewName + '</li>');
    AddTriggerToJSON(ViewName, 'exists', JSON);
  end;
end;


{------------------------------------------------------------------------------}
procedure EnsureIndex(
  const Conn: TFDConnection;
  const IndexName, SQLCreate: string;
  Log: TStrings;
  JSON: TJSONObject);
begin
  if not IndexExists(Conn, IndexName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Indice creato: ' + IndexName + '</li>');
    AddTriggerToJSON(IndexName, 'created', JSON);
  end
  else
  begin
    Log.Add('<li>Indice esistente: ' + IndexName + '</li>');
    AddTriggerToJSON(IndexName, 'exists', JSON);
  end;
end;


{------------------------------------------------------------------------------}
procedure EnsureConstraint(
  const Conn: TFDConnection;
  const ConstraintName, SQLCreate: string;
  Log: TStrings;
  JSON: TJSONObject);
begin
  if not ConstraintExists(Conn, ConstraintName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Constraint creato: ' + ConstraintName + '</li>');
    AddTriggerToJSON(ConstraintName, 'created', JSON);
  end
  else
  begin
    Log.Add('<li>Constraint esistente: ' + ConstraintName + '</li>');
    AddTriggerToJSON(ConstraintName, 'exists', JSON);
  end;
end;


{------------------------------------------------------------------------------}
procedure EnsureGenerator(
  const Conn: TFDConnection;
  const GenName, SQLCreate: string;
  Log: TStrings;
  JSON: TJSONObject);
begin
  if not GeneratorExists(Conn, GenName) then
  begin
    Conn.ExecSQL(SQLCreate);
    Log.Add('<li>Generatore creato: ' + GenName + '</li>');
    AddTriggerToJSON(GenName, 'created', JSON);
  end
  else
  begin
    Log.Add('<li>Generatore esistente: ' + GenName + '</li>');
    AddTriggerToJSON(GenName, 'exists', JSON);
  end;
end;

{------------------------------------------------------------------------------}
procedure CreateTriggersForTable(
  const Conn: TFDConnection;
  const TableName, PKField, GeneratorName: string;
  const Fields: TFields;
  const Log: TStrings;
  const JSON: TJSONObject);
var
  SQL, TriggerName: string;
begin
  Conn.StartTransaction;
  try
    Log.Add('<h3>Trigger per tabella ' + TableName + '</h3>');
    Log.Add('<ul>');

    // BEFORE INSERT ID
    if (PKField <> '') and (GeneratorName <> '') then
    begin
      TriggerName := TableName + '_BI';
      SQL := GenerateTriggerBeforeInsertID(TableName, PKField, GeneratorName);
      if not TriggerExists(Conn, TriggerName) then
      begin
        Conn.ExecSQL(SQL);
        Log.Add('<li>Creato: ' + TriggerName + '</li>');
        AddItemToJSON(TriggerName, 'created', JSON);
      end;
    end;

    // PROTECT ID
    TriggerName := TableName + '_BU_PROTECT_ID';
    SQL := GenerateTriggerProtectID(TableName, PKField);
    if not TriggerExists(Conn, TriggerName) then
    begin
      Conn.ExecSQL(SQL);
      Log.Add('<li>Creato: ' + TriggerName + '</li>');
      AddItemToJSON(TriggerName, 'created', JSON);
    end;

    // CREATED_AT
    if FieldExists(Fields, 'CREATED_AT') then
    begin
      TriggerName := TableName + '_BI_CREATED';
      SQL := GenerateTriggerCreatedAt(TableName);
      if not TriggerExists(Conn, TriggerName) then
      begin
        Conn.ExecSQL(SQL);
        Log.Add('<li>Creato: ' + TriggerName + '</li>');
        AddItemToJSON(TriggerName, 'created', JSON);
      end;
    end;

    // UPDATED_AT
    if FieldExists(Fields, 'UPDATED_AT') then
    begin
      TriggerName := TableName + '_BU_UPDATED';
      SQL := GenerateTriggerUpdatedAt(TableName);
      if not TriggerExists(Conn, TriggerName) then
      begin
        Conn.ExecSQL(SQL);
        Log.Add('<li>Creato: ' + TriggerName + '</li>');
        AddItemToJSON(TriggerName, 'created', JSON);
      end;
    end;

    // SOFT DELETE
    if FieldExists(Fields, 'DELETED') and FieldExists(Fields, 'DELETED_AT') then
    begin
      TriggerName := TableName + '_BU_SOFTDELETE';
      SQL := GenerateTriggerSoftDelete(TableName);
      if not TriggerExists(Conn, TriggerName) then
      begin
        Conn.ExecSQL(SQL);
        Log.Add('<li>Creato: ' + TriggerName + '</li>');
        AddItemToJSON(TriggerName, 'created', JSON);
      end;
    end;

    Log.Add('</ul>');
    Conn.Commit;
  except
    on E: Exception do
    begin
      Conn.Rollback;
      Log.Add('<p style="color:red;"><b>Errore trigger ' + TableName + ':</b> ' + E.Message + '</p>');
      AddItemToJSON(TableName, 'error: ' + E.Message, JSON);
      raise;
    end;
  end;
end;

{------------------------------------------------------------------------------}
procedure CreateTriggersForTable2(
  const Conn: TFDConnection;
  const TableName, PKField, GeneratorName: string;
  const Fields: TFields;
  const Log: TStrings;
  const JSON: TJSONObject);
var
  SQL, TriggerName: string;
begin
  Conn.StartTransaction;
  try
    Log.Add('<h3>Trigger per tabella ' + TableName + '</h3>');
    Log.Add('<ul>');

    // BEFORE INSERT ID
    if (PKField <> '') and (GeneratorName <> '') then
    begin
      TriggerName := TableName + '_BI';
      SQL := GenerateTriggerBeforeInsertID(TableName, PKField, GeneratorName);
      EnsureTrigger(Conn, TriggerName, SQL, Log);
      AddTriggerToJSON(TriggerName, 'processed', JSON);
    end;

    // PROTECT ID
    if PKField <> '' then
    begin
      TriggerName := TableName + '_BU_PROTECT_ID';
      SQL := GenerateTriggerProtectID(TableName, PKField);
      EnsureTrigger(Conn, TriggerName, SQL, Log);
      AddTriggerToJSON(TriggerName, 'processed', JSON);
    end;

    // CREATED_AT
    if FieldExists(Fields, 'CREATED_AT') then
    begin
      TriggerName := TableName + '_BI_CREATED';
      SQL := GenerateTriggerCreatedAt(TableName);
      EnsureTrigger(Conn, TriggerName, SQL, Log);
      AddTriggerToJSON(TriggerName, 'processed', JSON);
    end;

    // UPDATED_AT
    if FieldExists(Fields, 'UPDATED_AT') then
    begin
      TriggerName := TableName + '_BU_UPDATED';
      SQL := GenerateTriggerUpdatedAt(TableName);
      EnsureTrigger(Conn, TriggerName, SQL, Log);
      AddTriggerToJSON(TriggerName, 'processed', JSON);
    end;

    // SOFT DELETE
    if FieldExists(Fields, 'DELETED') and FieldExists(Fields, 'DELETED_AT') then
    begin
      TriggerName := TableName + '_BU_SOFTDELETE';
      SQL := GenerateTriggerSoftDelete(TableName);
      EnsureTrigger(Conn, TriggerName, SQL, Log);
      AddTriggerToJSON(TriggerName, 'processed', JSON);
    end;

    Log.Add('</ul>');
    Conn.Commit;
  except
    on E: Exception do
    begin
      Conn.Rollback;
      Log.Add('<p style="color:red;"><b>Errore trigger ' + TableName + ':</b> ' + E.Message + '</p>');
      AddTriggerToJSON(TableName, 'error: ' + E.Message, JSON);
      raise;
    end;
  end;
end;


end.
