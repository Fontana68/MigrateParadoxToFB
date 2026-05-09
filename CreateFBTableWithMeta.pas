unit MigrateEngine;

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Types,
  Data.DB,
  DBTables,            // per TTable (Paradox)
  FireDAC.Comp.Client; // per TFDConnection, TFDQuery

type
  // Adatta questo record/oggetto al tuo progetto reale
  TTableReport = record
    Logs: TStringList;
    Errors: TStringList;
  end;

procedure CreateFBTableWithMeta(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);

procedure CopyData(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);

procedure CreateForeignKeysHeuristic(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);

procedure SaveHTMLReport(const FileName: string; const Report: TTableReport);

implementation

uses
  System.Character, // CharInSet compatibility
  System.Math;

{ Utility: ExecSQL ----------------------------------------------------------- }
procedure ExecSQL(const Conn: TFDConnection; const SQL: string);
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text := SQL;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

{ Utility: Ident (safe quoting) --------------------------------------------- }
function IsSimpleIdentifier(const S: string): Boolean;
var
  i: Integer;
begin
  if S = '' then
    Exit(False);
  // must start with letter or underscore, rest letters/digits/underscore
  if not (TCharacter.IsLetter(S[1]) or (S[1] = '_')) then
    Exit(False);
  for i := 2 to Length(S) do
    if not (TCharacter.IsLetterOrDigit(S[i]) or (S[i] = '_')) then
      Exit(False);
  Result := True;
end;

function Ident(const S: string): string;
var
  tmp: string;
begin
  tmp := Trim(S);
  if IsSimpleIdentifier(tmp) then
    Result := tmp
  else
  begin
    tmp := StringReplace(tmp, '"', '""', [rfReplaceAll]);
    Result := '"' + tmp + '"';
  end;
end;

{ FindGenerator / FindTrigger ------------------------------------------------ }
function FindGenerator(const Conn: TFDConnection; const Name: string): string;
var
  Q: TFDQuery;
begin
  Result := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text := 'SELECT TRIM(RDB$GENERATOR_NAME) FROM RDB$GENERATORS WHERE RDB$GENERATOR_NAME = :N';
    Q.ParamByName('N').AsString := Name;
    Q.Open;
    if not Q.Eof then
      Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

function FindTrigger(const Conn: TFDConnection; const Name: string): string;
var
  Q: TFDQuery;
begin
  Result := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text := 'SELECT TRIM(RDB$TRIGGER_NAME) FROM RDB$TRIGGERS WHERE RDB$TRIGGER_NAME = :N';
    Q.ParamByName('N').AsString := Name;
    Q.Open;
    if not Q.Eof then
      Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ CreateSequence ------------------------------------------------------------ }
procedure CreateSequence(const Conn: TFDConnection; const Name: string);
begin
  ExecSQL(Conn, 'CREATE SEQUENCE ' + Ident(Name));
end;

{ Helpers to sanitize DDL (no regex dependency) ----------------------------- }
function PosWordCaseInsensitive(const Sub, S: string; StartPos: Integer = 1): Integer;
var
  U, US: string;
begin
  U := UpperCase(Sub);
  US := UpperCase(S);
  Result := PosEx(U, US, StartPos);
end;

function FindLastWordEnd(const S: string): Integer;
var
  U: string;
  p, L: Integer;
  beforeOk, afterOk: Boolean;
begin
  Result := 0;
  U := UpperCase(S);
  L := Length(U);
  p := Pos('END', U);
  while p > 0 do
  begin
    if p = 1 then
      beforeOk := True
    else
      beforeOk := not CharInSet(U[p-1], ['A'..'Z','0'..'9','_']);
    if (p + 3) > L then
      afterOk := True
    else
      afterOk := not CharInSet(U[p+3], ['A'..'Z','0'..'9','_']);
    if beforeOk and afterOk then
      Result := p;
    p := PosEx('END', U, p + 1);
  end;
end;

function CleanDDL(const RawSQL: string; out Trimmed: Boolean): string;
var
  s: string;
  lastPos, endPos, j: Integer;
begin
  Trimmed := False;
  s := RawSQL;
  s := StringReplace(s, #13#10, #10, [rfReplaceAll]);
  s := StringReplace(s, #13, #10, [rfReplaceAll]);

  lastPos := FindLastWordEnd(s);
  if lastPos = 0 then
  begin
    Result := RawSQL;
    Exit;
  end;

  endPos := lastPos + 3; // 'END'
  j := endPos + 1;
  while (j <= Length(s)) and CharInSet(s[j], [' ', #9, #10, #13, ';']) do
    Inc(j);

  if j <= Length(s) then
  begin
    Result := TrimRight(Copy(s, 1, j - 1));
    Trimmed := True;
  end
  else
  begin
    Result := TrimRight(s);
    Trimmed := False;
  end;

  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
end;

{ CreateTriggerBI ----------------------------------------------------------- }
procedure CreateTriggerBI(const Conn: TFDConnection; const Trg, Tbl, Fld, Seq: string;
  Log: TMemo; var Report: TTableReport);
var
  sDDL: string;
  wasTrimmed: Boolean;
  outFile: string;
begin
  // Seq deve essere già valorizzata dal chiamante
  sDDL :=
    'CREATE TRIGGER ' + Ident(Trg) + ' FOR ' + Ident(Tbl) + sLineBreak +
    'ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
    'AS' + sLineBreak +
    'BEGIN' + sLineBreak +
    '  IF (NEW.' + Ident(Fld) + ' IS NULL) THEN' + sLineBreak +
    '    NEW.' + Ident(Fld) + ' = NEXT VALUE FOR ' + Ident(Seq) + sLineBreak +
    'END';

  sDDL := CleanDDL(sDDL, wasTrimmed);
  if wasTrimmed then
    Report.Logs.Add('CleanDDL ha rimosso contenuto extra dal DDL del trigger per ' + Tbl + '.' + Fld);

  Report.Logs.Add('---BEGIN CREATE TRIGGER DDL---');
  Report.Logs.Add(sDDL);
  Report.Logs.Add('---END CREATE TRIGGER DDL---');

  try
    ExecSQL(Conn, sDDL);
    Report.Logs.Add('CREATE TRIGGER eseguito: ' + Trg);
  except
    on E: Exception do
    begin
      Report.Errors.Add('Errore CREATE TRIGGER ' + Trg + ': ' + E.Message);
      outFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DDL_Failed_' + Trg + '.sql');
      try
        TFile.WriteAllText(outFile, sDDL, TEncoding.UTF8);
        Report.Logs.Add('DDL fallito salvato in: ' + outFile);
      except
        Report.Logs.Add('Impossibile salvare DDL fallito su file: ' + outFile);
      end;
      raise;
    end;
  end;
end;

{ EnsureSequenceAndTrigger -------------------------------------------------- }
procedure EnsureSequenceAndTrigger(FBConn: TFDConnection;
  const TableName, FieldName: string; Log: TMemo; var Report: TTableReport);
var
  SeqBase, TrgBase: string;
  SeqName, TrgName: string;
  foundSeqName, foundTrgName: string;
  existsSeq, existsTrg: Boolean;
begin
  SeqBase := 'GEN_' + UpperCase(TableName) + '_' + UpperCase(FieldName);
  TrgBase := 'BI_'  + UpperCase(TableName) + '_' + UpperCase(FieldName);

  foundSeqName := FindGenerator(FBConn, SeqBase);
  foundTrgName := FindTrigger(FBConn, TrgBase);

  existsSeq := foundSeqName <> '';
  existsTrg := foundTrgName <> '';

  if existsSeq then
    SeqName := foundSeqName
  else
  begin
    SeqName := SeqBase;
    CreateSequence(FBConn, SeqName);
    Report.Logs.Add('Generator creato: ' + SeqName);
  end;

  if not existsTrg then
  begin
    TrgName := TrgBase;
    CreateTriggerBI(FBConn, TrgName, TableName, FieldName, SeqName, Log, Report);
    Report.Logs.Add('Trigger creato: ' + TrgName);
  end;
end;

{ FieldIsPrimary ------------------------------------------------------------ }
function FieldIsPrimary(PX: TTable; const FieldName: string; Log: TMemo): Boolean;
var
  I: Integer;
  idx: TIndexDef;
  fields: TStringList;
begin
  Result := False;
  fields := TStringList.Create;
  try
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      idx := PX.IndexDefs[I];
      if not (ixPrimary in idx.Options) then
        Continue;
      fields.CommaText := StringReplace(idx.Fields, ';', ',', [rfReplaceAll]);
      if fields.IndexOf(FieldName) <> -1 then
    begin
        Result := True;
        Exit;
      end;
    end;
  finally
    fields.Free;
  end;
end;

{ MapFieldTypeToFB --------------------------------------------------------- }
function MapFieldTypeToFB(Field: TField): string;
begin
  case Field.DataType of
    ftString:     Result := Format('VARCHAR(%d)', [Max(1, Field.Size)]);
    ftWideString: Result := Format('VARCHAR(%d)', [Max(1, Field.Size)]);
    ftSmallint:   Result := 'SMALLINT';
    ftInteger:    Result := 'INTEGER';
    ftLargeint:   Result := 'BIGINT';
    ftFloat:      Result := 'DOUBLE PRECISION';
    ftCurrency:   Result := 'DECIMAL(18,4)';
    ftBoolean:    Result := 'SMALLINT';
    ftDate:       Result := 'DATE';
    ftTime:       Result := 'TIME';
    ftDateTime:   Result := 'TIMESTAMP';
    ftMemo:       Result := 'BLOB SUB_TYPE TEXT';
    ftBlob:       Result := 'BLOB';
    ftAutoInc:    Result := 'INTEGER';
  else
    Result := 'VARCHAR(50)';
  end;
end;

{ CreateFBTableWithMeta ---------------------------------------------------- }
procedure CreateFBTableWithMeta(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  I: Integer;
  Field: TField;
  SQL: TStringList;
  PKFields: TStringList;
  IndexFields: TStringList;
  idx: TIndexDef;
  FBFieldType: string;
  AutoIncFields: TStringList;
  lastLine: string;
begin
  Report.Logs.Add('Preparazione CREATE TABLE per ' + TableName);

  SQL := TStringList.Create;
  PKFields := TStringList.Create;
  IndexFields := TStringList.Create;
  AutoIncFields := TStringList.Create;
  try
    SQL.Add('CREATE TABLE ' + Ident(TableName) + ' (');

    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      FBFieldType := MapFieldTypeToFB(Field);
      SQL.Add('  ' + Ident(Field.FieldName) + ' ' + FBFieldType + ',');
      if FieldIsPrimary(PX, Field.FieldName, Log) then
        PKFields.Add(Field.FieldName);
      if Field.DataType = ftAutoInc then
        AutoIncFields.Add(Field.FieldName);
    end;

    if PKFields.Count > 0 then
      SQL.Add('  CONSTRAINT PK_' + UpperCase(TableName) +
              ' PRIMARY KEY (' + StringReplace(PKFields.CommaText, ',', ', ', [rfReplaceAll]) + ')');

    // Rimuovi eventuale virgola finale
    lastLine := SQL[SQL.Count - 1];
    if lastLine.EndsWith(',') then
      SQL[SQL.Count - 1] := Copy(lastLine, 1, Length(lastLine) - 1);

    SQL.Add(');');

    Report.Logs.Add('');
    Report.Logs.Add('SQL = ');
    Report.Logs.Add(SQL.Text);

    // Esegui CREATE TABLE
    ExecSQL(FBConn, SQL.Text);
    Report.Logs.Add('CREATE TABLE eseguito per ' + TableName);

    // Indici secondari
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      idx := PX.IndexDefs[I];
      if (ixPrimary in idx.Options) then
        Continue;
      IndexFields.CommaText := StringReplace(idx.Fields, ';', ',', [rfReplaceAll]);
      ExecSQL(FBConn,
        'CREATE INDEX IDX_' + UpperCase(TableName) + '_' + IntToStr(I) +
        ' ON ' + Ident(TableName) +
        ' (' + StringReplace(IndexFields.CommaText, ',', ', ', [rfReplaceAll]) + ')');
      Report.Logs.Add('Indice creato: IDX_' + UpperCase(TableName) + '_' + IntToStr(I));
    end;

    // AutoInc: crea sequence + trigger
    for I := 0 to AutoIncFields.Count - 1 do
      EnsureSequenceAndTrigger(FBConn, TableName, AutoIncFields[I], Log, Report);

  finally
    SQL.Free;
    PKFields.Free;
    IndexFields.Free;
    AutoIncFields.Free;
  end;
end;

{ CopyData ------------------------------------------------------------------ }
procedure CopyData(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  Q: TFDQuery;
  I: Integer;
  Field: TField;
  InsertSQL: TStringList;
  ParamName: string;
  recCount: Integer;
begin
  Report.Logs.Add('Copia dati per ' + TableName);

  InsertSQL := TStringList.Create;
  Q := TFDQuery.Create(nil);
  try
    PX.Open;
    Q.Connection := FBConn;

    InsertSQL.Add('INSERT INTO ' + Ident(TableName) + ' (');
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      InsertSQL.Add('  ' + Ident(Field.FieldName) + ',');
    end;
    if InsertSQL[InsertSQL.Count - 1].EndsWith(',') then
      InsertSQL[InsertSQL.Count - 1] := Copy(InsertSQL[InsertSQL.Count - 1], 1, Length(InsertSQL[InsertSQL.Count - 1]) - 1);
    InsertSQL.Add(') VALUES (');
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      ParamName := ':' + Field.FieldName;
      InsertSQL.Add('  ' + ParamName + ',');
    end;
    if InsertSQL[InsertSQL.Count - 1].EndsWith(',') then
      InsertSQL[InsertSQL.Count - 1] := Copy(InsertSQL[InsertSQL.Count - 1], 1, Length(InsertSQL[InsertSQL.Count - 1]) - 1);
    InsertSQL.Add(')');

    Q.SQL.Text := InsertSQL.Text;

    PX.First;
    recCount := 0;
    while not PX.Eof do
    begin
      Q.Params.Clear;
      for I := 0 to PX.FieldCount - 1 do
      begin
        Field := PX.Fields[I];
        ParamName := Field.FieldName;
        if Field.IsNull then
          Q.ParamByName(ParamName).Clear
        else
        begin
          case Field.DataType of
            ftDate, ftTime, ftDateTime:
              Q.ParamByName(ParamName).AsDateTime := Field.AsDateTime;
          else
            Q.ParamByName(ParamName).Value := Field.Value;
          end;
        end;
      end;
      Q.ExecSQL;
      Inc(recCount);
      PX.Next;
    end;

    Report.Logs.Add('Records copiati per ' + TableName + ': ' + IntToStr(recCount));
  finally
    InsertSQL.Free;
    Q.Free;
    PX.Close;
  end;
end;

{ CreateForeignKeysHeuristic ------------------------------------------------ }
procedure CreateForeignKeysHeuristic(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  I: Integer;
  idx: TIndexDef;
  RefTable: string;
begin
  Report.Logs.Add('Heuristic FK per ' + TableName);

  for I := 0 to PX.IndexDefs.Count - 1 do
  begin
    idx := PX.IndexDefs[I];
    if (ixPrimary in idx.Options) or (ixUnique in idx.Options) then
      Continue;

    if SameText(Copy(idx.Name, 1, 3), 'FK_') then
    begin
      RefTable := Copy(idx.Name, 4, MaxInt);
      Report.Logs.Add('Possibile FK: ' + TableName + ' -> ' + RefTable);
      // Se vuoi creare FK automaticamente, costruisci qui l'ALTER TABLE ... ADD CONSTRAINT ...
    end;
  end;
end;

{ SaveHTMLReport ------------------------------------------------------------ }
procedure SaveHTMLReport(const FileName: string; const Report: TTableReport);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="utf-8"><title>Migration Report</title></head><body>');
    SL.Add('<h1>Report migrazione</h1>');

    SL.Add('<h2>Logs</h2><pre>');
    for I := 0 to Report.Logs.Count - 1 do
      SL.Add(Report.Logs[I]);
    SL.Add('</pre>');

    SL.Add('<h2>Errors</h2><pre>');
    for I := 0 to Report.Errors.Count - 1 do
      SL.Add(Report.Errors[I]);
    SL.Add('</pre>');

    SL.Add('</body></html>');

    SL.SaveToFile(FileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

end.



--KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK---

procedure CreateFBTableWithMeta(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  I: Integer;
  Field: TField;
  SQL: TStringList;
  PKFields: TStringList;
  IndexFields: TStringList;
  idx: TIndexDef;
  FBFieldType: string;
  AutoIncFields: TStringList;
begin
  Report.Logs.Add('Preparazione CREATE TABLE per ' + TableName);

  SQL := TStringList.Create;
  PKFields := TStringList.Create;
  IndexFields := TStringList.Create;
  AutoIncFields := TStringList.Create;

  try
    SQL.Add('CREATE TABLE ' + Ident(TableName) + ' (');

    // --- CAMPI ---
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      FBFieldType := MapFieldTypeToFB(Field);

      SQL.Add('  ' + Ident(Field.FieldName) + ' ' + FBFieldType + ',');

      if FieldIsPrimary(PX, Field.FieldName, Log) then
        PKFields.Add(Field.FieldName);

      if Field.DataType = ftAutoInc then
        AutoIncFields.Add(Field.FieldName);
    end;

    // --- PRIMARY KEY ---
    if PKFields.Count > 0 then
      SQL.Add('  CONSTRAINT PK_' + TableName +
              ' PRIMARY KEY (' + StringReplace(PKFields.CommaText, ',', ', ', [rfReplaceAll]) + ')');

    // Rimuovi eventuale virgola finale
    if SQL[SQL.Count - 1].EndsWith(',') then
      SQL[SQL.Count - 1] := Copy(SQL[SQL.Count - 1], 1, Length(SQL[SQL.Count - 1]) - 1);

    SQL.Add(');');

    // Log SQL
    Report.Logs.Add('');
    Report.Logs.Add('SQL = ');
    Report.Logs.Add(SQL.Text);

    // --- ESECUZIONE CREATE TABLE ---
    ExecSQL(FBConn, SQL.Text);
    Report.Logs.Add('CREATE TABLE eseguito per ' + TableName);

    // --- INDICI SECONDARI ---
    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      idx := PX.IndexDefs[I];

      if (ixPrimary in idx.Options) then
        Continue;

      IndexFields.CommaText := idx.Fields;

      ExecSQL(FBConn,
        'CREATE INDEX IDX_' + UpperCase(TableName) + '_' + IntToStr(I) +
        ' ON ' + Ident(TableName) +
        ' (' + StringReplace(IndexFields.CommaText, ',', ', ', [rfReplaceAll]) + ')');

      Report.Logs.Add('Indice creato: IDX_' + UpperCase(TableName) + '_' + IntToStr(I));
    end;

    // --- AUTOINC: SEQUENCE + TRIGGER ---
    for I := 0 to AutoIncFields.Count - 1 do
      EnsureSequenceAndTrigger(FBConn, TableName, AutoIncFields[I], Log, Report);

  finally
    SQL.Free;
    PKFields.Free;
    IndexFields.Free;
    AutoIncFields.Free;
  end;
end;

procedure CopyData(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  Q: TFDQuery;
  I: Integer;
  Field: TField;
  InsertSQL: TStringList;
  ParamName: string;
begin
  Report.Logs.Add('Copia dati per ' + TableName);

  InsertSQL := TStringList.Create;
  Q := TFDQuery.Create(nil);
  try
    PX.Open;
    Q.Connection := FBConn;

    // Costruisci INSERT
    InsertSQL.Add('INSERT INTO ' + Ident(TableName) + ' (');
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      InsertSQL.Add('  ' + Ident(Field.FieldName) + ',');
    end;
    if InsertSQL[InsertSQL.Count - 1].EndsWith(',') then
      InsertSQL[InsertSQL.Count - 1] :=
        Copy(InsertSQL[InsertSQL.Count - 1], 1, Length(InsertSQL[InsertSQL.Count - 1]) - 1);
    InsertSQL.Add(') VALUES (');
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];
      ParamName := ':' + Field.FieldName;
      InsertSQL.Add('  ' + ParamName + ',');
    end;
    if InsertSQL[InsertSQL.Count - 1].EndsWith(',') then
      InsertSQL[InsertSQL.Count - 1] :=
        Copy(InsertSQL[InsertSQL.Count - 1], 1, Length(InsertSQL[InsertSQL.Count - 1]) - 1);
    InsertSQL.Add(')');

    Q.SQL.Text := InsertSQL.Text;

    PX.First;
    while not PX.Eof do
    begin
      Q.Params.Clear;
      for I := 0 to PX.FieldCount - 1 do
      begin
        Field := PX.Fields[I];
        ParamName := Field.FieldName;

        if Field.IsNull then
          Q.ParamByName(ParamName).Clear
        else
        begin
          case Field.DataType of
            ftDate, ftTime, ftDateTime:
              Q.ParamByName(ParamName).AsDateTime := Field.AsDateTime;
          else
            Q.ParamByName(ParamName).Value := Field.Value;
          end;
        end;
      end;

      Q.ExecSQL;
      PX.Next;
    end;

    Report.Logs.Add('Records copiati per ' + TableName + ': ' + IntToStr(PX.RecordCount));
  finally
    InsertSQL.Free;
    Q.Free;
    PX.Close;
  end;
end;

procedure CreateForeignKeysHeuristic(const PX: TTable; FBConn: TFDConnection;
  const TableName: string; Log: TMemo; var Report: TTableReport);
var
  I: Integer;
  idx: TIndexDef;
  RefTable: string;
begin
  Report.Logs.Add('Heuristic FK per ' + TableName);

  for I := 0 to PX.IndexDefs.Count - 1 do
  begin
    idx := PX.IndexDefs[I];

    if (ixPrimary in idx.Options) or (ixUnique in idx.Options) then
      Continue;

    // euristica banalissima: se indice si chiama FK_<TAB>_<REF>
    if SameText(Copy(idx.Name, 1, 3), 'FK_') then
    begin
      RefTable := Copy(idx.Name, 4, MaxInt);
      // qui potresti fare parsing migliore, per ora solo log
      Report.Logs.Add('Possibile FK: ' + TableName + ' -> ' + RefTable);
      // se vuoi davvero creare FK, qui costruisci ALTER TABLE ... ADD CONSTRAINT ...
    end;
  end;
end;
procedure SaveHTMLReport(const FileName: string; const Report: TTableReport);
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="utf-8"><title>Migration Report</title></head><body>');
    SL.Add('<h1>Report migrazione</h1>');

    SL.Add('<h2>Logs</h2><pre>');
    for I := 0 to Report.Logs.Count - 1 do
      SL.Add(Report.Logs[I]);
    SL.Add('</pre>');

    SL.Add('<h2>Errors</h2><pre>');
    for I := 0 to Report.Errors.Count - 1 do
      SL.Add(Report.Errors[I]);
    SL.Add('</pre>');

    SL.Add('</body></html>');

    SL.SaveToFile(FileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;
