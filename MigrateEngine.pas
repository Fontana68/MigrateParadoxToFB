unit MigrateEngine;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.StrUtils,
  System.RegularExpressions,
  System.IOUtils,
  Vcl.ComCtrls, Vcl.StdCtrls,
  Data.DB, Bde.DBTables,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Intf, FireDAC.DApt, FireDAC.Stan.Param;

type
  TTableReport = record
    TableName: string;
    RecordsCopied: Integer;
    PrimaryKey: string;
    Indices: TStringList;
    ForeignKeys: TStringList;
    AutoIncFields: TStringList;
    Errors: TStringList;
    Logs: TStringList; // nuova lista per messaggi diagnostici / info
  end;

procedure RunMigrationSelective(ParadoxDB: TDatabase;
                                FBConn: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar;
                                Log: TMemo;
                                CopiaDati: Boolean);

implementation

uses
  Variants, DateUtils;

const
  // elenco minimale di keyword SQL/Firebird; estendi se necessario
  SQL_KEYWORDS: array[0..28] of string = (
    'DATE','TIME','TIMESTAMP','USER','PASSWORD','ORDER','GROUP','SELECT',
    'INSERT','UPDATE','DELETE','TABLE','INDEX','CONSTRAINT','PRIMARY',
    'KEY','TRIGGER','GENERATOR','SEQUENCE','VALUES','FROM','WHERE','AND',
    'OR','NOT','NULL','LIKE','IN','BETWEEN'
  );

var
  ReportList: array of TTableReport;

{-----------------------------------------------------------------}
function FindLastWordEnd(const S: string): Integer;
var
  U: string;
  p: Integer;
  L: Integer;
  beforeOk, afterOk: Boolean;
begin
  Result := 0;
  U := UpperCase(S);
  L := Length(U);
  p := Pos('END', U);
  while p > 0 do
  begin
    // controlla boundary: carattere precedente non alfanumerico/underscore
    if p = 1 then
      beforeOk := True
    else
      beforeOk := not CharInSet(U[p-1], ['A'..'Z','0'..'9','_']);

    // controlla carattere dopo 'END'
    if (p + 3) > L then
      afterOk := True
    else
      afterOk := not CharInSet(U[p+3], ['A'..'Z','0'..'9','_']);

    if beforeOk and afterOk then
      Result := p; // aggiorna ultima occorrenza valida

    p := PosEx('END', U, p + 1);
  end;
end;

{----------------------------------------------------------------------------}
function CleanDDL(const RawSQL: string; out Trimmed: Boolean): string;
var
  s: string;
  lastPos, endPos, j: Integer;
begin
  Trimmed := False;
  s := RawSQL;

  // Normalizza newline
  s := StringReplace(s, #13#10, #10, [rfReplaceAll]);
  s := StringReplace(s, #13, #10, [rfReplaceAll]);

  // trova l'ultima occorrenza della parola END (word boundary)
  lastPos := FindLastWordEnd(s);
  if lastPos = 0 then
  begin
    Result := RawSQL;
    Exit;
  end;

  // calcola posizione subito dopo 'END'
  endPos := lastPos + Length('END');

  // consenti spazi/newline e un eventuale ';' subito dopo END
  j := endPos + 1;
  while (j <= Length(s)) and CharInSet(s[j], [' ', #9, #10, #13, ';']) do
    Inc(j);

  if j <= Length(s) then
  begin
    // c'era contenuto extra dopo END: taglia fino a j-1
    Result := TrimRight(Copy(s, 1, j - 1));
    Trimmed := True;
  end
  else
  begin
    Result := TrimRight(s);
    Trimmed := False;
  end;

  // ripristina CRLF Windows
  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
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

{-----------------------------------------------------------------}
function IsParadoxInvalidDateStr(const S: string): Boolean;
var
  t: string;
begin
  t := Trim(S);
  if t = '' then
    Exit(True);
  // controlli comuni
  if (t = '00/00/0000') or (t = '0000-00-00') or (t = '00-00-0000') or (t = '00.00.0000') then
    Exit(True);
  // altri formati non convertibili saranno gestiti dal TryStrToDate
  Result := False;
end;

{-----------------------------------------------------------------}
// Ritorna Variant: Null se invalida, altrimenti TDateTime
function ParadoxFieldToDateTimeVariant(Field: TField): Variant;
var
  s: string;
  dt: TDateTime;
  FS: TFormatSettings;
begin
  Result := Null;
  if Field = nil then Exit;
  if Field.IsNull then Exit;

  // leggi come stringa per essere permissivi
  s := Trim(Field.AsString);
  if IsParadoxInvalidDateStr(s) then
    Exit; // Null

  // prova parsing con formati locali (adatta se Paradox usa dd/mm/yyyy)
  FS := TFormatSettings.Create;
  FS.DateSeparator := '/';
  FS.ShortDateFormat := 'dd/MM/yyyy';

  // prova parsing diretto
  if TryStrToDateTime(s, dt, FS) then
  begin
    Result := dt;
    Exit;
  end;

  // prova altri formati comuni
  FS.DateSeparator := '-';
  FS.ShortDateFormat := 'yyyy-MM-dd';
  if TryStrToDateTime(s, dt, FS) then
  begin
    Result := dt;
    Exit;
  end;

  // fallback: prova conversione numerica (alcuni Paradox memorizzano date come numeri)
  try
    dt := Field.AsDateTime;
    Result := dt;
  except
    Result := Null;
  end;
end;

{-----------------------------------------------------------------}
procedure PreScanInvalidDates(const TableName: string; ParadoxDB: TDatabase; Log: TMemo; var Report: TTableReport);
var
  PX: TTable;
  I: Integer;
  s: string;
begin
  PX := TTable.Create(nil);
  try
    PX.DatabaseName := ParadoxDB.DatabaseName;
    PX.TableName := TableName;
    PX.Open;
    while not PX.Eof do
    begin
      for I := 0 to PX.FieldCount - 1 do
      begin
        if PX.Fields[I].DataType in [ftDate, ftDateTime, ftTimeStamp] then
        begin
          s := Trim(PX.Fields[I].AsString);
          if IsParadoxInvalidDateStr(s) then
            Report.Logs.Add(Format('Invalid date in %s.%s: "%s" (RecNo=%d)', [TableName, PX.Fields[I].FieldName, s, PX.RecNo]));
        end;
      end;
      PX.Next;
    end;
  finally
    PX.Free;
  end;
end;

{-----------------------------------------------------------------}
procedure ExecSQL(const Conn: TFDConnection; const SQL: string);
begin
  Conn.ExecSQL(SQL);
end;

{-----------------------------------------------------------------}
function FBIdent(const S: string): string;
begin
  Result := StringReplace(S, ' ', '_', [rfReplaceAll]);
end;

{-----------------------------------------------------------------}
function MapFieldTypeToFB(Field: TField): string;
begin
  case Field.DataType of
    ftString, ftWideString: Result := 'VARCHAR(' + IntToStr(Field.Size) + ')';
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

{-----------------------------------------------------------------}
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

{-----------------------------------------------------------------}
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

{-----------------------------------------------------------------}
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

// controlla esistenza generator provando varianti
function GeneratorExists(Q: TFDQuery; const Name: string): Boolean;
begin
  Q.SQL.Text := 'SELECT COUNT(*) FROM RDB$GENERATORS WHERE RDB$GENERATOR_NAME = :G';
  Q.ParamByName('G').AsString := Name;
  Q.Open; Result := Q.Fields[0].AsInteger > 0; Q.Close;
end;

// usa GeneratorExists(Q, SeqName) e GeneratorExists(Q, '"' + SeqName + '"') per coprire i casi


{----------------------------- EnsureSequenceAndTrigger ---------------------}
procedure EnsureSequenceAndTrigger(FBConn: TFDConnection;
  const TableName, FieldName: string; Log: TMemo; var Report: TTableReport);
var
  SeqBase, TrgBase: string;
  SeqName, TrgName: string;
  Q: TFDQuery;
  existsSeq, existsTrg: Boolean;
  foundSeqName, foundTrgName: string;

  function UpperName(const S: string): string;
  begin
    Result := UpperCase(S);
  end;

  // generator/trigger canonical names (policy: UPPERCASE non quoted)
  function CanonicalSeqName(const T, F: string): string;
  begin
    Result := 'GEN_' + UpperName(T) + '_' + UpperName(F);
  end;

  function CanonicalTrgName(const T, F: string): string;
  begin
    Result := 'BI_' + UpperName(T) + '_' + UpperName(F);
  end;

  // cerca generator/trigger provando sia la forma non-quoted (UPPER) sia la forma quotata
  function FindGenerator(const Conn: TFDConnection; const Name: string): string;
  begin
    Result := '';
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text := 'SELECT TRIM(RDB$GENERATOR_NAME) FROM RDB$GENERATORS WHERE RDB$GENERATOR_NAME = :N OR RDB$GENERATOR_NAME = :QN';
      Q.ParamByName('N').AsString := Name;
      Q.ParamByName('QN').AsString := '"' + Name + '"';
      Q.Open;
      if not Q.Eof then
        Result := Q.Fields[0].AsString;
      Q.Close;
    finally
      Q.Free;
    end;
  end;

  function FindTrigger(const Conn: TFDConnection; const Name: string): string;
  begin
    Result := '';
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text := 'SELECT TRIM(RDB$TRIGGER_NAME) FROM RDB$TRIGGERS WHERE RDB$TRIGGER_NAME = :N OR RDB$TRIGGER_NAME = :QN';
      Q.ParamByName('N').AsString := Name;
      Q.ParamByName('QN').AsString := '"' + Name + '"';
      Q.Open;
      if not Q.Eof then
        Result := Q.Fields[0].AsString;
      Q.Close;
    finally
      Q.Free;
    end;
  end;

  procedure CreateSequence(const Conn: TFDConnection; const Name: string);
  begin
    try
      // NON aggiungere il punto e virgola finale quando si esegue via API
      ExecSQL(Conn, 'CREATE SEQUENCE ' + Name);
      Report.Logs.Add('CREATE SEQUENCE eseguito: ' + Name);
    except
      on E: Exception do
      begin
        Report.Errors.Add(Format('Errore CREATE SEQUENCE %s: %s - %s', [Name, E.ClassName, E.Message]));
        raise;
      end;
    end;
  end;

  procedure CreateTriggerBI(const Conn: TFDConnection; const Trg, Tbl, Fld, Seq: string);
  var
    s: string;
    wasTrimmed: Boolean;
    outFile: string;
  begin
    // Costruisci il corpo del trigger senza terminatore finale ';'
    // e senza terminatori superflui. Usa Ident per tabella/campo.
    s := 'CREATE TRIGGER ' + Trg + ' FOR ' + Ident(Tbl) + sLineBreak +
         'ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
         'AS' + sLineBreak +
         'BEGIN' + sLineBreak +
         '  IF (NEW.' + Ident(Fld) + ' IS NULL) THEN' + sLineBreak +
         '    NEW.' + Ident(Fld) + ' = NEXT VALUE FOR ' + Seq + ';' + sLineBreak +
         'END'; // NO semicolon finale

    // pulizia robusta
    s := CleanDDL(s, wasTrimmed);
    if wasTrimmed then
      Report.Logs.Add('CleanDDL ha rimosso contenuto extra dal DDL del trigger per ' + Tbl + '.' + Fld);

// log completo delimitato (molto utile)
  Report.Logs.Add('---BEGIN CREATE TRIGGER DDL---');
  Report.Logs.Add(s);
  Report.Logs.Add('---END CREATE TRIGGER DDL---');

    try
      ExecSQL(Conn, s);
      Report.Logs.Add('CREATE TRIGGER eseguito: ' + Trg + ' FOR ' + Tbl + '.' + Fld);
    except
      on E: Exception do
      begin
       Report.Errors.Add(Format('Errore CREATE TRIGGER %s: %s - %s', [Trg, E.ClassName, E.Message]));
      // salva DDL fallito su file per analisi
      outFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DDL_Failed_' + Trg + '.sql');
      try
        TFile.WriteAllText(outFile, s, TEncoding.UTF8);
        Report.Logs.Add('DDL fallito salvato in: ' + outFile);
      except
        Report.Logs.Add('Impossibile salvare DDL fallito su file: ' + outFile);
      end;
      raise; // rilancia per far emergere l'errore a livello superiore
      end;
    end;
  end;

begin
  if not Assigned(FBConn) then
  begin
    Report.Errors.Add('EnsureSequenceAndTrigger: FBConn non assegnata per ' + TableName);
    Exit;
  end;

  SeqBase := CanonicalSeqName(TableName, FieldName);
  TrgBase := CanonicalTrgName(TableName, FieldName);

  // verifica esistenza generator/trigger (restituisce nome esatto se trovato)
  foundSeqName := FindGenerator(FBConn, SeqBase);
  foundTrgName := FindTrigger(FBConn, TrgBase);

  existsSeq := (foundSeqName <> '');
  existsTrg := (foundTrgName <> '');

  // log diagnostico
  if existsSeq then
    Report.Logs.Add(Format('Generator trovato per %s.%s -> %s', [TableName, FieldName, foundSeqName]))
  else
    Report.Logs.Add(Format('Generator non trovato per %s.%s (atteso %s)', [TableName, FieldName, SeqBase]));

  if existsTrg then
    Report.Logs.Add(Format('Trigger trovato per %s.%s -> %s', [TableName, FieldName, foundTrgName]))
  else
    Report.Logs.Add(Format('Trigger non trovato per %s.%s (atteso %s)', [TableName, FieldName, TrgBase]));

  // se manca il generator, crealo con nome canonico (UPPERCASE non quoted)
  if not existsSeq then
  begin
    SeqName := SeqBase; // UPPER non quoted
    try
      CreateSequence(FBConn, SeqName);
      // dopo creazione, aggiorna foundSeqName
      foundSeqName := FindGenerator(FBConn, SeqName);
      existsSeq := (foundSeqName <> '');
    except
      // errore già loggato in CreateSequence
    end;
  end;

    // Assicura che SeqName contenga il nome reale della sequence
  if existsSeq then
    SeqName := foundSeqName
  else
    SeqName := SeqBase;

  // se manca il trigger, crealo con nome canonico (UPPERCASE non quoted)
  if not existsTrg then
  begin
    TrgName := TrgBase; // UPPER non quoted
    try
      // per il trigger usiamo Ident(TableName) e Ident(FieldName) per referenziare correttamente
      CreateTriggerBI(FBConn, TrgName, TableName, FieldName, SeqName);
      foundTrgName := FindTrigger(FBConn, TrgName);
      existsTrg := (foundTrgName <> '');
    except
      // errore già loggato in CreateTriggerBI
    end;
  end;

  // final logging e aggiornamento report
  if existsSeq then
    Report.Logs.Add(Format('Generator confermato per %s.%s -> %s', [TableName, FieldName, foundSeqName]))
  else
    Report.Errors.Add(Format('Generator mancante dopo tentativo di creazione per %s.%s (atteso %s)', [TableName, FieldName, SeqBase]));

  if existsTrg then
    Report.Logs.Add(Format('Trigger confermato per %s.%s -> %s', [TableName, FieldName, foundTrgName]))
  else
    Report.Errors.Add(Format('Trigger mancante dopo tentativo di creazione per %s.%s (atteso %s)', [TableName, FieldName, TrgBase]));
end;


{-----------------------------------------------------------------}
// uso ->SQL := GenerateBeforeInsertTrigger('CLIENT', 'ID_CLIENT', 'GEN_CLIENT_ID_CLIENT');
(*
CREATE TRIGGER CLIENT_BI FOR CLIENT
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW."ID_CLIENT" IS NULL) THEN
    NEW."ID_CLIENT" = NEXT VALUE FOR "GEN_CLIENT_ID_CLIENT";
END
*)
function GenerateTriggerBeforeInsertID(
  const TableName, PKField, GeneratorName: string): string;
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

{-----------------------------------------------------------------}
(*
CREATE TRIGGER CLIENT_BU_PROTECT_ID FOR CLIENT
ACTIVE BEFORE UPDATE POSITION 0
AS
BEGIN
  IF (NEW."ID_CLIENT" <> OLD."ID_CLIENT") THEN
    NEW."ID_CLIENT" = OLD."ID_CLIENT";
END
*)
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

{-----------------------------------------------------------------}
(*
CREATE TRIGGER CLIENT_BI_CREATED FOR CLIENT
ACTIVE BEFORE INSERT POSITION 1
AS
BEGIN
  IF (NEW."CREATED_AT" IS NULL) THEN
    NEW."CREATED_AT" = CURRENT_TIMESTAMP;
END
*)
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

{-----------------------------------------------------------------}
(*
CREATE TRIGGER CLIENT_BU_UPDATED FOR CLIENT
ACTIVE BEFORE UPDATE POSITION 1
AS
BEGIN
  NEW."UPDATED_AT" = CURRENT_TIMESTAMP;
END
*)
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

{-----------------------------------------------------------------}
(*
CREATE TRIGGER CLIENT_BU_SOFTDELETE FOR CLIENT
ACTIVE BEFORE UPDATE POSITION 2
AS
BEGIN
  IF (NEW."DELETED" = 1 AND OLD."DELETED" = 0) THEN
    NEW."DELETED_AT" = CURRENT_TIMESTAMP;
END
*)
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

{-----------------------------------------------------------------}
function FieldExists(const Fields: TFields; const FieldName: string): Boolean;
begin
  Result := Fields.FindField(FieldName) <> nil;
end;
{-----------------------------------------------------------------}
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

{-----------------------------------------------------------------}
procedure CreateTriggersForTable(
  const Conn: TFDConnection;
  const TableName, PKField, GeneratorName: string;
  const Fields: TFields;
  const Log: TStrings);
var
  SQL: string;
begin
  // Trigger ID autoincrementale
  if (PKField <> '') and (GeneratorName <> '') then
  begin
    if not TriggerExists(Conn, TableName + '_BI') then
    begin
      SQL := GenerateTriggerBeforeInsertID(TableName, PKField, GeneratorName);
      Conn.ExecSQL(SQL);
      Log.Add('Trigger created: ' + TableName + '_BI');
    end;
  end;

  // Protezione ID
  if PKField <> '' then
  begin
    if not TriggerExists(Conn, TableName + '_BU_PROTECT_ID') then
    begin
      SQL := GenerateTriggerProtectID(TableName, PKField);
      Conn.ExecSQL(SQL);
      Log.Add('Trigger created: ' + TableName + '_BU_PROTECT_ID');
    end;
  end;

  // CREATED_AT
  if FieldExists(Fields, 'CREATED_AT') then
  begin
    if not TriggerExists(Conn, TableName + '_BI_CREATED') then
    begin
      SQL := GenerateTriggerCreatedAt(TableName);
      Conn.ExecSQL(SQL);
      Log.Add('Trigger created: ' + TableName + '_BI_CREATED');
    end;
  end;

  // UPDATED_AT
  if FieldExists(Fields, 'UPDATED_AT') then
  begin
    if not TriggerExists(Conn, TableName + '_BU_UPDATED') then
    begin
      SQL := GenerateTriggerUpdatedAt(TableName);
      Conn.ExecSQL(SQL);
      Log.Add('Trigger created: ' + TableName + '_BU_UPDATED');
    end;
  end;

  // SOFT DELETE
  if FieldExists(Fields, 'DELETED') and FieldExists(Fields, 'DELETED_AT') then
  begin
    if not TriggerExists(Conn, TableName + '_BU_SOFTDELETE') then
    begin
      SQL := GenerateTriggerSoftDelete(TableName);
      Conn.ExecSQL(SQL);
      Log.Add('Trigger created: ' + TableName + '_BU_SOFTDELETE');
    end;
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

  sSQL: string;
begin

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
///
// --- Se non ci sono ftAutoInc, considera i PK interi come AutoInc candidates ---
if (Report.AutoIncFields.Count = 0) and (PKFields <> '') then
begin
  // PKFields contiene Ident(...) separati da virgola; rimuoviamo eventuali quote e spazi
  var pkList: TStringList := TStringList.Create;
  try
    pkList.CommaText := StringReplace(PKFields, ' ', '', [rfReplaceAll]);
    for var j := 0 to pkList.Count - 1 do
    begin
      // rimuovi eventuali doppi apici
      var fldName := pkList[j];
      fldName := StringReplace(fldName, '"', '', [rfReplaceAll]);

      // trova il TField corrispondente in PX (case-insensitive)
      var f: TField := PX.FindField(fldName);
      if f = nil then
      begin
        // prova con uppercase/lowercase
        f := PX.FindField(UpperCase(fldName));
        if f = nil then
          f := PX.FindField(LowerCase(fldName));
      end;

      if Assigned(f) then
      begin
        // considera autoinc solo se tipo intero
        if f.DataType in [ftInteger, ftSmallint, ftLargeint] then
        begin
          // evita duplicati
          if Report.AutoIncFields.IndexOf(f.FieldName) = -1 then
            Report.AutoIncFields.Add(f.FieldName);
          // registra PrimaryKey nel report se non già impostato
          if Report.PrimaryKey = '' then
            Report.PrimaryKey := f.FieldName
          else if not AnsiContainsText(Report.PrimaryKey, f.FieldName) then
            Report.PrimaryKey := Report.PrimaryKey + ',' + f.FieldName;
        end;
      end
      else
      begin
        // logga se non trovi il campo (utile per debug)
        Report.Logs.Add(Format('PK field not found in PX.Fields: %s (table %s)', [fldName, TableName]));
      end;
    end;
  finally
    pkList.Free;
  end;
end;
/////

    // aggiungi constraint PK se presente
    if PKFields <> '' then
      SQL.Add(', CONSTRAINT ' + Ident('PK_' + TableName) + ' PRIMARY KEY (' + PKFields + ')');

    SQL.Add(');');

    // diagnostica
    Report.Logs.Add('Preparazione CREATE TABLE per ' + TableName);
    Report.Logs.Add('SQL = ' + sLineBreak + SQL.Text);

    // Verifica FBConn
    if not Assigned(FBConn) then
    begin
      Report.Errors.Add('FBConn non assegnata per CREATE TABLE ' + TableName);
      Exit;
    end;

    Report.Logs.Add('FBConn.Connected=' + BoolToStr(FBConn.Connected, True));
    Report.Logs.Add('FBConn.Params.Database=' + FBConn.Params.Values['Database']);

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

      sSQL := SQL.Text;
      // rimuove eventuale ",\s*\)" (virgola prima della parentesi di chiusura)
      sSQL := TRegEx.Replace(sSQL, ',\s*\)', ')', [roIgnoreCase]);
      // ora esegui
      ExecSQL(FBConn, sSQL);
      // ExecSQL(FBConn, SQL.Text);

      FBConn.Commit;
      Report.Logs.Add('CREATE TABLE eseguito per ' + TableName);
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
        Report.Logs.Add('SQL che ha fallito: ' + sLineBreak + SQL.Text);
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
        Report.Logs.Add('CREATE INDEX eseguito: ' + PX.IndexDefs[I].Name);
      except
        on E: Exception do
          Report.Errors.Add('Errore CREATE INDEX ' + PX.IndexDefs[I].Name + ': ' + E.ClassName + ' - ' + E.Message);
      end;
    end;
(*
CreateTriggersForTable(
  FBConn,
  TableName,
  PKField,
  GeneratorName,
  Table.Fields,
  Log);
*)

    // --- crea SEQUENCE e TRIGGER per campi autoinc trovati (controllo esistenza) ---
    for I := 0 to Report.AutoIncFields.Count - 1 do
    begin
      EnsureSequenceAndTrigger(FBConn, TableName, Report.AutoIncFields[I], Log, Report);
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
  v: Variant;

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
      for I := 0 to PX.FieldCount - 1 do
      begin
        paramName := 'p' + IntToStr(I + 1);
        try
          case PX.Fields[I].DataType of
            ftDate, ftDateTime, ftTimeStamp:
              begin
                // converte e restituisce Null se invalida
                v := ParadoxFieldToDateTimeVariant(PX.Fields[I]);
                if VarIsNull(v) then
                  FBQuery.ParamByName(paramName).Clear
                else
                  FBQuery.ParamByName(paramName).AsDateTime := v;
              end;
            else
              FBQuery.ParamByName(paramName).Value := PX.Fields[I].Value;
          end;
        except
          on E: Exception do
          begin
            // logga l'errore e la riga problematica
            Report.Errors.Add(Format('Errore assegnazione campo %s in tabella %s: %s', [PX.Fields[I].FieldName, TableName, E.Message]));
            Report.Logs.Add('Riga problematica: ' + PX.Fields[I].AsString);
            FBQuery.ParamByName(paramName).Clear; // evita crash successivi
          end;
        end;
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
function TableExists(FBConn: TFDConnection; const TableName: string): Boolean;
begin
  Result :=
    FBConn.ExecSQLScalar(
      'SELECT COUNT(*) FROM RDB$RELATIONS ' +
      'WHERE RDB$RELATION_NAME = :T AND RDB$SYSTEM_FLAG = 0',
      [UpperCase(TableName)]
    ) > 0;
end;

function ColumnExists(FBConn: TFDConnection; const TableName, ColumnName: string): Boolean;
begin
  Result :=
    FBConn.ExecSQLScalar(
      'SELECT COUNT(*) FROM RDB$RELATION_FIELDS ' +
      'WHERE RDB$RELATION_NAME = :T AND RDB$FIELD_NAME = :C',
      [UpperCase(TableName), UpperCase(ColumnName)]
    ) > 0;
end;

function ForeignKeyExists(FBConn: TFDConnection; const TableName, FieldName: string): Boolean;
begin
  Result :=
    FBConn.ExecSQLScalar(
      'SELECT COUNT(*) ' +
      'FROM RDB$RELATION_CONSTRAINTS RC ' +
      'JOIN RDB$INDEX_SEGMENTS ISG ON RC.RDB$INDEX_NAME = ISG.RDB$INDEX_NAME ' +
      'WHERE RC.RDB$RELATION_NAME = :T ' +
      '  AND RC.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY'' ' +
      '  AND ISG.RDB$FIELD_NAME = :F',
      [UpperCase(TableName), UpperCase(FieldName)]
    ) > 0;
end;

function GetPrimaryKeyColumn(FBConn: TFDConnection; const TableName: string): string;
begin
  Result := FBConn.ExecSQLScalar(
    'SELECT TRIM(ISG.RDB$FIELD_NAME) ' +
    'FROM RDB$RELATION_CONSTRAINTS RC ' +
    'JOIN RDB$INDEX_SEGMENTS ISG ON RC.RDB$INDEX_NAME = ISG.RDB$INDEX_NAME ' +
    'WHERE RC.RDB$RELATION_NAME = :T ' +
    '  AND RC.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY'' ' +
    'ORDER BY ISG.RDB$FIELD_POSITION',
    [UpperCase(TableName)]
  );
end;

function ResolveReferenceTable(FBConn: TFDConnection; const BaseName: string): string;
var
  Candidates: array of string;
  C: string;
begin
  Result := '';

  SetLength(Candidates, 6);
  Candidates[0] := UpperCase(BaseName);                     // BRAKE
  Candidates[1] := 'RIS' + UpperCase(BaseName);             // RISBRAKE
  Candidates[2] := UpperCase(BaseName) + 'S';               // BRAKES
  Candidates[3] := 'RIS_' + UpperCase(BaseName);            // RIS_BRAKE
  Candidates[4] := 'RIS' + UpperCase(BaseName) + 'S';       // RISBRAKES
  Candidates[5] := 'RIS' + Copy(BaseName,1,1) + LowerCase(Copy(BaseName,2)); // RisBrake

  for C in Candidates do
    if TableExists(FBConn, C) then
      Exit(C);
end;

procedure CreateForeignKeysHeuristic(const TableName: string;
                                     FBConn: TFDConnection;
                                     Log: TMemo;
                                     var Report: TTableReport);
var
  Q: TFDQuery;
  FieldName, BaseRef, RefTable, RefColumn: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FBConn;
    Q.SQL.Text :=
      'SELECT TRIM(RDB$FIELD_NAME) ' +
      'FROM RDB$RELATION_FIELDS ' +
      'WHERE RDB$RELATION_NAME = :T';
    Q.ParamByName('T').AsString := UpperCase(TableName);
    Q.Open;

    while not Q.Eof do
    begin
      FieldName := Trim(Q.Fields[0].AsString);
      BaseRef := '';

      // ---------------------------
      // Pattern 1: ID_<TABLE>
      // ---------------------------
      if FieldName.StartsWith('ID_') then
        BaseRef := Copy(FieldName, 4, Length(FieldName));

      // ---------------------------
      // Pattern 2: <TABLE>_ID
      // ---------------------------
      if (BaseRef = '') and FieldName.EndsWith('_ID') then
        BaseRef := Copy(FieldName, 1, Length(FieldName) - 3);

      // ---------------------------
      // Pattern 3: <TABLE>ID
      // ---------------------------
      if (BaseRef = '') and FieldName.ToUpper.EndsWith('ID') then
        BaseRef := Copy(FieldName, 1, Length(FieldName) - 2);

      // Nessun match → passa oltre
      if BaseRef = '' then
      begin
        Q.Next;
        Continue;
      end;

      // Risolvi tabella referenziata
      RefTable := ResolveReferenceTable(FBConn, BaseRef);

      if RefTable = '' then
      begin
        Report.Errors.Add('Tabella referenziata non trovata: ' + BaseRef);
        Q.Next;
        Continue;
      end;

      // Recupera PK reale
      RefColumn := GetPrimaryKeyColumn(FBConn, RefTable);

      if RefColumn = '' then
      begin
        Report.Errors.Add('PK non trovata in ' + RefTable);
        Q.Next;
        Continue;
      end;

      // Evita FK duplicate
      if ForeignKeyExists(FBConn, TableName, FieldName) then
      begin
        Report.Logs.Add('FK già esistente: ' + FieldName + ' → ' + RefTable);
        Q.Next;
        Continue;
      end;

      // ---------------------------
      // Crea FK
      // ---------------------------
      try
        FBConn.ExecSQL(
          'ALTER TABLE ' + FBIdent(TableName) +
          ' ADD CONSTRAINT FK_' + FBIdent(TableName) + '_' + FBIdent(FieldName) +
          ' FOREIGN KEY (' + FBIdent(FieldName) + ') REFERENCES ' +
          FBIdent(RefTable) + '(' + RefColumn + ');'
        );

        Report.ForeignKeys.Add(FieldName + ' → ' + RefTable + '(' + RefColumn + ')');
        Report.Logs.Add('FK creata: ' + FieldName + ' → ' + RefTable + '(' + RefColumn + ')');
      except
        Report.Errors.Add('FK fallita: ' + FieldName + ' → ' + RefTable);
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
  i, totalTables, totalErrors, totalLogs: Integer;
  rep: TTableReport;

  function HtmlEncode(const S: string): string;
  var
    j: Integer;
  begin
    Result := '';
    for j := 1 to Length(S) do
      case S[j] of
        '&': Result := Result + '&amp;';
        '<': Result := Result + '&lt;';
        '>': Result := Result + '&gt;';
        '"': Result := Result + '&quot;';
        '''': Result := Result + '&#39;';
      else
        Result := Result + S[j];
      end;
  end;

  function SafeId(const Index: Integer; const Name: string): string;
  var
    tmp: string;
    k: Integer;
    ch: Char;
  begin
    tmp := Trim(Name);
    // sostituisci caratteri non alfanumerici con underscore usando CharInSet per evitare W1050
    for k := 1 to Length(tmp) do
    begin
      ch := tmp[k];
      if not CharInSet(ch, ['0'..'9','A'..'Z','a'..'z']) then
        tmp[k] := '_';
    end;
    Result := 'table_' + IntToStr(Index) + '_' + tmp;
  end;

  procedure AddTableSection(const R: TTableReport; const Id: string);
  var
    k: Integer;
  begin
    SL.Add('<section id="' + HtmlEncode(Id) + '">');
    SL.Add('<h2>' + HtmlEncode(R.TableName) + '</h2>');
    SL.Add('<table>');
    SL.Add('<tr><th style="width:220px">Voce</th><th>Valore</th></tr>');

    SL.Add('<tr><td><b>Records copiati</b></td><td>' + IntToStr(R.RecordsCopied) + '</td></tr>');
    SL.Add('<tr><td><b>Primary Key</b></td><td>' + HtmlEncode(R.PrimaryKey) + '</td></tr>');

    // Indici
    SL.Add('<tr><td valign="top"><b>Indici</b></td><td>');
    if (R.Indices <> nil) and (R.Indices.Count > 0) then
    begin
      SL.Add('<ul>');
      for k := 0 to R.Indices.Count - 1 do
        SL.Add('<li>' + HtmlEncode(R.Indices[k]) + '</li>');
      SL.Add('</ul>');
    end
    else
      SL.Add('Nessun indice');
    SL.Add('</td></tr>');

    // Foreign keys
    SL.Add('<tr><td valign="top"><b>Foreign Keys</b></td><td>');
    if (R.ForeignKeys <> nil) and (R.ForeignKeys.Count > 0) then
    begin
      SL.Add('<ul>');
      for k := 0 to R.ForeignKeys.Count - 1 do
        SL.Add('<li>' + HtmlEncode(R.ForeignKeys[k]) + '</li>');
      SL.Add('</ul>');
    end
    else
      SL.Add('Nessuna foreign key');
    SL.Add('</td></tr>');

    // AutoInc fields
    SL.Add('<tr><td valign="top"><b>AutoInc Fields</b></td><td>');
    if (R.AutoIncFields <> nil) and (R.AutoIncFields.Count > 0) then
    begin
      SL.Add('<ul>');
      for k := 0 to R.AutoIncFields.Count - 1 do
        SL.Add('<li>' + HtmlEncode(R.AutoIncFields[k]) + '</li>');
      SL.Add('</ul>');
    end
    else
      SL.Add('Nessun campo autoinc');
    SL.Add('</td></tr>');

    // Logs
    SL.Add('<tr><td valign="top"><b>Logs</b></td><td>');
    if (R.Logs <> nil) and (R.Logs.Count > 0) then
    begin
      SL.Add('<pre style="white-space:pre-wrap;margin:0;padding:8px;background:#f8f8f8;border:1px solid #eee;">');
      for k := 0 to R.Logs.Count - 1 do
        SL.Add(HtmlEncode(R.Logs[k]) + sLineBreak);
      SL.Add('</pre>');
    end
    else
      SL.Add('Nessun log');
    SL.Add('</td></tr>');

    // Errors
    SL.Add('<tr><td valign="top"><b>Errors</b></td><td>');
    if (R.Errors <> nil) and (R.Errors.Count > 0) then
    begin
      SL.Add('<pre class="error" style="white-space:pre-wrap;margin:0;padding:8px;background:#fff6f6;border:1px solid #f2c2c2;color:#900;">');
      for k := 0 to R.Errors.Count - 1 do
        SL.Add(HtmlEncode(R.Errors[k]) + sLineBreak);
      SL.Add('</pre>');
    end
    else
      SL.Add('Nessun errore');
    SL.Add('</td></tr>');

    SL.Add('</table>');
    SL.Add('<p><a href="#top">Torna all''indice</a></p>');
    SL.Add('<hr/>');
    SL.Add('</section>');
  end;

begin
  SL := TStringList.Create;
  try
    // calcola aggregati
    totalTables := Length(ReportList);
    totalErrors := 0;
    totalLogs := 0;
    for i := 0 to totalTables - 1 do
    begin
      Inc(totalErrors, ReportList[i].Errors.Count);
      Inc(totalLogs, ReportList[i].Logs.Count);
    end;

    SL.Add('<!doctype html>');
    SL.Add('<html><head><meta charset="utf-8">');
    SL.Add('<title>Migration Report</title>');
    SL.Add('<style>');
    SL.Add('body{font-family:Segoe UI,Arial,Helvetica,sans-serif;margin:20px;color:#222}');
    SL.Add('h1{font-size:20px}');
    SL.Add('table{width:100%;border-collapse:collapse;margin-bottom:12px}');
    SL.Add('th,td{border:1px solid #ddd;padding:8px;vertical-align:top}');
    SL.Add('th{background:#f0f0f0;text-align:left}');
    SL.Add('.error{color:#900;font-weight:normal}');
    SL.Add('pre{font-family:Consolas,monospace;font-size:12px;padding:8px}');
    SL.Add('nav.toc{background:#fafafa;border:1px solid #eee;padding:12px;margin-bottom:16px}');
    SL.Add('nav.toc ul{margin:0;padding-left:18px}');
    SL.Add('</style>');
    SL.Add('</head><body>');
    SL.Add('<a id="top"></a>');
    SL.Add('<h1>Report Migrazione Paradox → Firebird</h1>');
    SL.Add('<p>Generato il ' + DateTimeToStr(Now) + '</p>');

    // sommario aggregato
    SL.Add('<h2>Sommario aggregato</h2>');
    SL.Add('<table>');
    SL.Add('<tr><th style="width:220px">Voce</th><th>Valore</th></tr>');
    SL.Add('<tr><td><b>Numero tabelle</b></td><td>' + IntToStr(totalTables) + '</td></tr>');
    SL.Add('<tr><td><b>Totale errori</b></td><td>' + IntToStr(totalErrors) + '</td></tr>');
    SL.Add('<tr><td><b>Totale log</b></td><td>' + IntToStr(totalLogs) + '</td></tr>');
    SL.Add('</table>');

    // indice ancorato
    SL.Add('<h2>Indice tabelle</h2>');
    SL.Add('<nav class="toc">');
    SL.Add('<ul>');
    for i := 0 to totalTables - 1 do
      SL.Add('<li><a href="#' + HtmlEncode(SafeId(i, ReportList[i].TableName)) + '">' +
             HtmlEncode(ReportList[i].TableName) + '</a> - Records: ' + IntToStr(ReportList[i].RecordsCopied) +
             ' - Errors: ' + IntToStr(ReportList[i].Errors.Count) + ' - Logs: ' + IntToStr(ReportList[i].Logs.Count) + '</li>');
    SL.Add('</ul>');
    SL.Add('</nav>');
    SL.Add('<hr/>');

    // dettagli per tabella con ancore
    for i := 0 to totalTables - 1 do
    begin
      rep := ReportList[i];
      AddTableSection(rep, SafeId(i, rep.TableName));
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
                                Log: TMemo;
                                CopiaDati: Boolean);
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
    ReportList[I].Logs := TStringList.Create; // inizializza Logs

    // controlla date invalide
    PreScanInvalidDates(T, ParadoxDB, Log, ReportList[I]);

    Log.Lines.Add('Creazione schema: ' + T);
    CreateFBTableWithMeta(T, ParadoxDB, FBConn, Log, ReportList[I]);

    if CopiaDati = true then
    begin
      Log.Lines.Add('Copia dati: ' + T);
      CopyData(T, ParadoxDB, FBConn, Log, ReportList[I]);
    end;

    Log.Lines.Add('Foreign key (euristica): ' + T);
    CreateForeignKeysHeuristic(T, FBConn, Log, ReportList[I]);

    Progress.Position := Progress.Position + 1;
  end;

  ForceDirectories('.\Report');
  SaveHTMLReport('.\Report\MigrationReport.html');

  ShellExecute(0, 'open', PChar('.\Report\MigrationReport.html'), nil, nil, SW_SHOWNORMAL);
end;

end.

