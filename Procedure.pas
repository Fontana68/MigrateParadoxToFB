    TDataSource *dsClient;
    TFDTable *tbClient;
    TFDTable *tbVehicle;
    TIntegerField *tbVehicleID_VEHICLE;
    TStringField *tbVehiclePLATE;
    TStringField *tbVehicleMAKE;
    TStringField *tbVehicleMODEL;
    TIntegerField *tbVehicleCAPACITY;
    TSmallintField *tbVehicleTEMP;
    TSmallintField *tbVehicleF_MINRPM;
    TSmallintField *tbVehicleF_MAXRPM;
    TFloatField *tbVehicleF_CO;
    TSmallintField *tbVehicleF_HC;
    TFloatField *tbVehicleF_MINLAMBDA;
    TFloatField *tbVehicleF_MAXLAMBDA;
    TSmallintField *tbVehicleI_MINRPM;
    TSmallintField *tbVehicleI_MAXRPM;
    TFloatField *tbVehicleI_CO;
    TIntegerField *tbClientID_CLIENT;
    TStringField *tbClientNAME;
    TStringField *tbClientADDRESS;
    TStringField *tbClientADDR1;
    TStringField *tbClientADDR2;
    TStringField *tbClientADDR3;
    TStringField *tbClientPOSTCODE;
    TStringField *tbClientTELEPHONE;
    TDataSource *dsVehicle;
    TFDTable *tbRevision;
    TFDAutoIncField *tbRevisionID_REVISION;
    TIntegerField *tbRevisionID_VEHICLE;
    TIntegerField *tbRevisionID_BETCAT;
    TIntegerField *tbRevisionID_NCATVIS;
    TIntegerField *tbRevisionID_CLIENT;
    TIntegerField *tbRevisionKM;
    TDataSource *dsRevision;
    TFDQuery *qryVehicle;
    TFDTable *tbRisBET;
    TFDTable *tbRisNCAT;
    TIntegerField *tbRisBETID_BETCAT;
    TBooleanField *tbRisBETTYPE;
    TBooleanField *tbRisBETENG_TEMP;
    TSmallintField *tbRisBETENG_TEMPFAN;
    TBooleanField *tbRisBETSPEED;
    TSmallintField *tbRisBETVTEMP;
    TBooleanField *tbRisBETFASTIDLE1;
    TSmallintField *tbRisBETF1_VRPM;
    TBooleanField *tbRisBETF1_RPM;
    TFloatField *tbRisBETF1_VCO;
    TBooleanField *tbRisBETF1_CO;
    TSmallintField *tbRisBETF1_VHC;
    TBooleanField *tbRisBETF1_HC;
    TFloatField *tbRisBETF1_VLAMBDA;
    TBooleanField *tbRisBETF1_LAMBDA;
    TBooleanField *tbRisBETFASTIDLE2;
    TSmallintField *tbRisBETF2_VRPM;
    TBooleanField *tbRisBETF2_RPM;
    TFloatField *tbRisBETF2_VCO;
    TBooleanField *tbRisBETF2_CO;
    TSmallintField *tbRisBETF2_VHC;
    TBooleanField *tbRisBETF2_HC;
    TFloatField *tbRisBETF2_VLAMBDA;
    TBooleanField *tbRisBETF2_LAMBDA;
    TBooleanField *tbRisBETIDLE;
    TSmallintField *tbRisBETI_VRPM;
    TBooleanField *tbRisBETI_RPM;
    TFloatField *tbRisBETI_VCO;
    TBooleanField *tbRisBETI_CO;
    TBooleanField *tbRisBETRESULT;
    TDateTimeField *tbRisBETTEST_START;
    TDateTimeField *tbRisBETTEST_END;
    TIntegerField *tbRisBETID_OPERATOR;
    TIntegerField *tbRisNCATID_NCATVIS;
    TBooleanField *tbRisNCATTYPE;
    TSmallintField *tbRisNCATFUELTYPE;
    TFloatField *tbRisNCATVCO;
    TSmallintField *tbRisNCATVHC;
    TBooleanField *tbRisNCATIDLESPEED;
    TBooleanField *tbRisNCATSMOKELEVEL;
    TBooleanField *tbRisNCATRESULT;
    TDateTimeField *tbRisNCATTEST_START;
    TDateTimeField *tbRisNCATTEST_END;
    TIntegerField *tbRisNCATID_OPERATOR;
    TDateTimeField *tbRevisionBEGCAT;
    TBooleanField *tbRevisionTYPECAT;
    TDateTimeField *tbRevisionBEGNCAT;
    TDateTimeField *tbRevisionSTART;
    TFDQuery *qryClient;
    TDateTimeField *tbRevisionEND;
    TFDTable *tbOperator;
    TDateTimeField *tbRevisionENDCAT;
    TDateTimeField *tbRevisionENDNCAT;
    TStringField *tbRisBETNAME_OPERATOR;
    TIntegerField *tbOperatorID_OPERATOR;
    TStringField *tbOperatorOPERATOR;
    TStringField *tbRisNCATNAME_OPERATOR;
    TStringField *tbRevisionCAT_OPER;
    TStringField *tbRevisionNCAT_OPER;
    TStringField *tbRevisionOPERATOR;
    TFDQuery *qryRisBET;
    TFDQuery *qryRisNCAT;
    TIntegerField *qryRisBETID_BETCAT;
    TBooleanField *qryRisBETTYPE;
    TBooleanField *qryRisBETENG_TEMP;
    TSmallintField *qryRisBETENG_TEMPFAN;
    TBooleanField *qryRisBETSPEED;
    TSmallintField *qryRisBETVTEMP;
    TBooleanField *qryRisBETFASTIDLE1;
    TSmallintField *qryRisBETF1_VRPM;
    TBooleanField *qryRisBETF1_RPM;
    TFloatField *qryRisBETF1_VCO;
    TBooleanField *qryRisBETF1_CO;
    TSmallintField *qryRisBETF1_VHC;
    TBooleanField *qryRisBETF1_HC;
    TFloatField *qryRisBETF1_VLAMBDA;
    TBooleanField *qryRisBETF1_LAMBDA;
    TBooleanField *qryRisBETFASTIDLE2;
    TSmallintField *qryRisBETF2_VRPM;
    TBooleanField *qryRisBETF2_RPM;
    TFloatField *qryRisBETF2_VCO;
    TBooleanField *qryRisBETF2_CO;
    TSmallintField *qryRisBETF2_VHC;
    TBooleanField *qryRisBETF2_HC;
    TFloatField *qryRisBETF2_VLAMBDA;
    TBooleanField *qryRisBETF2_LAMBDA;
    TBooleanField *qryRisBETIDLE;
    TSmallintField *qryRisBETI_VRPM;
    TBooleanField *qryRisBETI_RPM;
    TFloatField *qryRisBETI_VCO;
    TBooleanField *qryRisBETI_CO;
    TBooleanField *qryRisBETRESULT;
    TDateTimeField *qryRisBETTEST_START;
    TDateTimeField *qryRisBETTEST_END;
    TIntegerField *qryRisBETID_OPERATOR;
    TIntegerField *qryRisNCATID_NCATVIS;
    TBooleanField *qryRisNCATTYPE;
    TSmallintField *qryRisNCATFUELTYPE;
    TFloatField *qryRisNCATVCO;
    TSmallintField *qryRisNCATVHC;
    TBooleanField *qryRisNCATIDLESPEED;
    TBooleanField *qryRisNCATSMOKELEVEL;
    TBooleanField *qryRisNCATRESULT;
    TDateTimeField *qryRisNCATTEST_START;
    TDateTimeField *qryRisNCATTEST_END;
    TIntegerField *qryRisNCATID_OPERATOR;
    TBooleanField *tbRisNCATCO;
    TBooleanField *tbRisNCATHC;
    TBooleanField *qryRisNCATCO;
    TBooleanField *qryRisNCATHC;
    TDataSource *dsOperator;
    TFloatField *tbVehicleNCAT_CO;
    TFDConnection *dbCustomer;
    TBooleanField *tbRisBETDATABASE;
    TBooleanField *qryRisBETDATABASE;
    TFDTable *tbRevLimits;
    TIntegerField *tbRevLimitsID_REVISION;
    TFDQuery *qryRevLimits;
    TSmallintField *tbRevLimitsF_MINRPM;
    TSmallintField *tbRevLimitsF_MAXRPM;
    TFloatField *tbRevLimitsF_CO;
    TSmallintField *tbRevLimitsF_HC;
    TFloatField *tbRevLimitsF_MINLAMBDA;
    TFloatField *tbRevLimitsF_MAXLAMBDA;
    TSmallintField *tbRevLimitsI_MINRPM;
    TSmallintField *tbRevLimitsI_MAXRPM;
    TFloatField *tbRevLimitsI_CO;
    TSmallintField *qryRevLimitsF_MINRPM;
    TSmallintField *qryRevLimitsF_MAXRPM;
    TFloatField *qryRevLimitsF_CO;
    TSmallintField *qryRevLimitsF_HC;
    TFloatField *qryRevLimitsF_MINLAMBDA;
    TFloatField *qryRevLimitsF_MAXLAMBDA;
    TSmallintField *qryRevLimitsI_MINRPM;
    TSmallintField *qryRevLimitsI_MAXRPM;
    TFloatField *qryRevLimitsI_CO;
    TFloatField *tbRevLimitsNCAT_CO;
    TFloatField *qryRevLimitsNCAT_CO;
    TSmallintField *tbRevLimitsTEMP;
    TSmallintField *qryRevLimitsTEMP;
    TFDPhysFBDriverLink *FDPhysFBDriverLink1;


procedure CreateFBTableFromParadox(Paradox: TFDTable; FBConn: TFDConnection);
var
  Cmd: TFDCommand;
begin
  Cmd := TFDCommand.Create(nil);
  Cmd.Connection := FBConn;

  Cmd.CommandText.Text :=
    'CREATE TABLE CLIENTI (' +
    ' ID INTEGER NOT NULL PRIMARY KEY,' +
    ' NOME VARCHAR(80),' +
    ' INDIRIZZO VARCHAR(120),' +
    ' NOTE BLOB SUB_TYPE TEXT' +
    ')';

  Cmd.Execute;
end;

procedure CopyParadoxToFirebird(const TableName: string);
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
    // Sorgente Paradox
    Src.Connection := FDConnectionParadox;
    Src.TableName := TableName;

    // Destinazione Firebird
    Dst.Connection := FDConnectionFB;
    Dst.SQL.Text := 'SELECT * FROM ' + TableName;

    // BatchMove
    Reader.DataSet := Src;
    Writer.DataSet := Dst;

    Move.Reader := Reader;
    Move.Writer := Writer;
    Move.Options := [poClearDest, poIdentityInsert];
    Move.Execute;

  finally
    Src.Free;
    Dst.Free;
    Move.Free;
    Reader.Free;
    Writer.Free;
  end;
end;


CopyParadoxToFirebird('CLIENTI');
CopyParadoxToFirebird('ORDINI');
CopyParadoxToFirebird('RIGHE');

Paradox,Firebird
Alpha,VARCHAR
Number,INTEGER / DOUBLE
Currency,"NUMERIC(18,4)"
Date,DATE
Time,TIME
Timestamp,TIMESTAMP
Memo,BLOB SUB_TYPE TEXT
Binary,BLOB

->indice
autoincrement Paradox vanno convertiti in:
CREATE SEQUENCE GEN_CLIENTI_ID;
->trigger
CREATE TRIGGER BI_CLIENTI_ID FOR CLIENTI
ACTIVE BEFORE INSERT POSITION 0
AS
BEGIN
  IF (NEW.ID IS NULL) THEN
    NEW.ID = NEXT VALUE FOR GEN_CLIENTI_ID;
END

Connessione Firebird embedded
Per Firebird Embedded con FireDAC devi usare DriverID=FB e puntare il database a un file locale .FDB; la doc mostra anche che per embedded è necessario il driver link TFDPhysFBDriverLink con VendorLib valorizzata alla DLL Firebird embedded, oppure una driver definition equivalente. La libreria client/embedded può stare nella cartella dell’EXE oppure in un percorso configurato in FDDrivers.ini.

FDQuery1.Connection := FDConnection1;
FDQuery1.SQL.Text := 'select ID, NAME from CUSTOMER where ID = :ID';
FDQuery1.ParamByName('ID').AsInteger := 10;
FDQuery1.Open;


procedure TForm1.FDBatchMove1Translate(Sender: TObject; ASourceData, ADestData: TFieldData; var AAccept: Boolean);
var
  SrcStr: string;
begin
  SrcStr := ASourceData.AsString;
  if Pos('Nome', ASourceData.Field.FieldName) > 0 then begin
    ADestData.Data := UTF8Encode(Trim(UpperCase(SrcStr)));  // Es. trim + upper + UTF8
    AAccept := True;
  end else
    AAccept := True;  // Accetta default
end;

unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.DBGrids, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait;

type
  TForm1 = class(TForm)
    FDConnection1: TFDConnection;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    FDQuery1: TFDQuery;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    BtnInit: TButton;
    BtnAdd: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BtnInitClick(Sender: TObject);
    procedure BtnAddClick(Sender: TObject);
  private
    FDBFile: string;
    procedure ConfigureFirebirdEmbedded;
    procedure CreateDatabaseIfNeeded;
    procedure CreateSchemaIfNeeded;
    procedure OpenData;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  DataSource1.DataSet := FDQuery1;
  DBGrid1.DataSource := DataSource1;

  FDBFile := TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'data'), 'demo.fdb');

  ConfigureFirebirdEmbedded;
  CreateDatabaseIfNeeded;
  CreateSchemaIfNeeded;
  OpenData;
end;

procedure TForm1.ConfigureFirebirdEmbedded;
var
  AppPath: string;
begin
  AppPath := ExtractFilePath(ParamStr(0));
  ForceDirectories(TPath.GetDirectoryName(FDBFile));

  // Per Firebird embedded, FireDAC usa la libreria specificata in VendorLib
  // secondo la documentazione ufficiale.
  FDPhysFBDriverLink1.VendorLib := TPath.Combine(AppPath, 'fbembed.dll');
  // Se usi Firebird 3/4/5 embedded package che espone fbclient.dll,
  // sostituisci con:
  // FDPhysFBDriverLink1.VendorLib := TPath.Combine(AppPath, 'fbclient.dll');

  FDConnection1.LoginPrompt := False;
  FDConnection1.Params.Clear;
  FDConnection1.Params.Add('DriverID=FB');
  FDConnection1.Params.Add('Database=' + FDBFile);
  FDConnection1.Params.Add('User_Name=sysdba');
  FDConnection1.Params.Add('Password=masterkey');
  FDConnection1.Params.Add('CharacterSet=UTF8');
  FDConnection1.Params.Add('OpenMode=OpenOrCreate');
end;

procedure TForm1.CreateDatabaseIfNeeded;
begin
  if not TFile.Exists(FDBFile) then
  begin
    FDConnection1.Params.Values['CreateDatabase'] := 'Yes';
    FDConnection1.Params.Values['PageSize'] := '8192';
    FDConnection1.Connected := True;
    FDConnection1.Close;
    FDConnection1.Params.Values['CreateDatabase'] := 'No';
  end;
end;

procedure TForm1.CreateSchemaIfNeeded;
begin
  FDConnection1.Connected := True;
  try
    FDConnection1.ExecSQL(
      'recreate table CUSTOMER (' +
      '  ID integer not null,' +
      '  NAME varchar(100) not null,' +
      '  CREATED_AT timestamp default current_timestamp,' +
      '  constraint PK_CUSTOMER primary key (ID)' +
      ')'
    );
  except
    // Se non vuoi ricreare sempre la tabella, sostituisci RECREATE con
    // controlli su metadata o CREATE ... gestendo l'eccezione "table exists".
  end;
end;

procedure TForm1.OpenData;
begin
  FDQuery1.Close;
  FDQuery1.Connection := FDConnection1;
  FDQuery1.SQL.Text := 'select ID, NAME, CREATED_AT from CUSTOMER order by ID';
  FDQuery1.Open;
end;

procedure TForm1.BtnInitClick(Sender: TObject);
begin
  CreateSchemaIfNeeded;
  OpenData;
end;

procedure TForm1.BtnAddClick(Sender: TObject);
var
  NextID: Integer;
begin
  FDConnection1.ExecSQLScalar('select coalesce(max(ID), 0) + 1 from CUSTOMER', [], NextID);

  FDConnection1.ExecSQL(
    'insert into CUSTOMER (ID, NAME) values (:ID, :NAME)',
    [NextID, 'Test ' + IntToStr(NextID)]
  );

  OpenData;
end;

end.


-----------------------------

uses FireDAC.Comp.BatchMove;

procedure CopyBulkParadoxToFirebird(ParadoxFolder, FbFile: string);
var
  SrcConn, DstConn: TFDConnection;
  Reader, Writer: TFDBatchMoveDataSetReader;
  BatchMove: TFDBatchMove;
  FBLink: TFDPhysFBDriverLink;
begin
  FBLink := TFDPhysFBDriverLink.Create(nil);
  SrcConn := TFDConnection.Create(nil);
  DstConn := TFDConnection.Create(nil);
  Reader := TFDBatchMoveDataSetReader.Create(nil);
  Writer := TFDBatchMoveDataSetWriter.Create(nil);
  BatchMove := TFDBatchMove.Create(nil);
  try
    FBLink.VendorLib := ExtractFilePath(ParamStr(0)) + 'fbembed.dll';

    SrcConn.Params.Clear; SrcConn.Params.Add('DriverID=ODBC'); SrcConn.Params.Add('Database=' + ParadoxFolder); SrcConn.Params.Add('ODBCDriver=Microsoft Paradox Driver (*.db )'); SrcConn.Connected := True;
    DstConn.Params.Clear; DstConn.Params.Add('DriverID=FB'); DstConn.Params.Add('Database=' + FbFile); DstConn.Params.Add('User_Name=sysdba'); DstConn.Params.Add('Password=masterkey'); DstConn.Params.Add('CharacterSet=UTF8'); DstConn.Connected := True;

    // Configura Reader/Writer
    Reader.Dataset := TFDBatchMoveQuery.Create(nil); // o FDTable
    Reader.Dataset.Connection := SrcConn;
    Reader.Dataset.SQL.Text := 'SELECT * FROM CLIENTI';
    Writer.Dataset := TFDBatchMoveQuery.Create(nil);
    Writer.Dataset.Connection := DstConn;
    Writer.Dataset.SQL.Text := 'SELECT * FROM CLIENTI';

    BatchMove.Reader := Reader;
    BatchMove.Writer := Writer;
    BatchMove.CommitCount := 1000; // commit ogni 1000 righe
    BatchMove.Execute;
  finally
    BatchMove.Free;
    Writer.Free;
    Reader.Free;
    DstConn.Free;
    SrcConn.Free;
    FBLink.Free;
  end;
end;

unit DataModuleMigra;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Comp.Client,
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.Comp.DataSet;

type
  TDmMigra = class(TDataModule)
    SrcConn: TFDConnection;
    DstConn: TFDPhysFBDriverLink;
    SrcQ: TFDQuery;
    DstQ: TFDQuery;
    procedure DataModuleCreate(Sender: TObject);
    procedure MigraClick(Sender: TObject);
  private
    procedure ConfiguraConnessioni(const ParadoxFolder, FbFile: string);
  public
  end;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDmMigra.DataModuleCreate(Sender: TObject);
begin
  ConfiguraConnessioni('.\paradox', '.\data\MOT.fdb');
end;

procedure TDmMigra.ConfiguraConnessioni(const ParadoxFolder, FbFile: string);
begin
  DstConn.VendorLib := ExtractFilePath(ParamStr(0)) + 'fbembed.dll';

  SrcConn.Params.Clear;
  SrcConn.Params.Add('DriverID=ODBC');
  SrcConn.Params.Add('Database=' + ParadoxFolder);
  SrcConn.Params.Add('ODBCDriver=Microsoft Paradox Driver (*.db )');
  SrcConn.Connected := True;

  DstConn.Params.Clear;
  DstConn.Params.Add('DriverID=FB');
  DstConn.Params.Add('Database=' + FbFile);
  DstConn.Params.Add('User_Name=sysdba');
  DstConn.Params.Add('Password=masterkey');
  DstConn.Params.Add('CharacterSet=UTF8');
  DstConn.Connected := True;
end;

procedure TDmMigra.MigraClick(Sender: TObject);
begin
  SrcQ.SQL.Text := 'SELECT * FROM CLIENTI';
  SrcQ.Open;

  DstConn.StartTransaction;
  try
    DstQ.SQL.Text := 'INSERT INTO CLIENTI (ID, NOME, CITTA) VALUES (:ID, :NOME, :CITTA)';
    while not SrcQ.Eof do
    begin
      DstQ.ParamByName('ID').AsInteger := SrcQ.FieldByName('ID').AsInteger;
      DstQ.ParamByName('NOME').AsString := SrcQ.FieldByName('NOME').AsString;
      DstQ.ParamByName('CITTA').AsString := SrcQ.FieldByName('CITTA').AsString;
      DstQ.ExecSQL;
      SrcQ.Next;
    end;
    DstConn.Commit;
  except
    DstConn.Rollback;
    raise;
  end;
end;

end.


-------------------------------------
uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.VCLUI.Wait;

procedure TDataModule1.SetupFirebirdEmbedded;
var
  dbPath: string;
begin
  dbPath := ExtractFilePath(ParamStr(0)) + 'MOT.fdb';

  // --- Driver Link ---
  FDPhysFBDriverLink1.VendorHome := ExtractFilePath(ParamStr(0)) + 'Firebird_Embedded';
  FDPhysFBDriverLink1.VendorLib  := 'fbclient.dll';
  FDPhysFBDriverLink1.Embedded   := True;  // Modalità embedded!

  // --- Connessione ---
  FDConnection1.DriverName := 'FB';
  FDConnection1.Params.Values['Protocol'] := 'Local';
  FDConnection1.Params.Values['Server']   := '';        // VUOTO per embedded
  FDConnection1.Params.Values['Database'] := dbPath;
  FDConnection1.Params.Values['User_Name']:= 'SYSDBA';
  FDConnection1.Params.Values['Password'] := 'masterkey';
  FDConnection1.Params.Values['CharacterSet'] := 'UTF8';

  FDConnection1.LoginPrompt := False;
end;

procedure TDataModule1.CreateDBIfNotExists;
var
  dbPath: string;
begin
  dbPath := FDConnection1.Params.Values['Database'];

  if not FileExists(dbPath) then
  begin
    FDConnection1.ExecSQL(
      'CREATE DATABASE ''' + dbPath + ''' ' +
      'USER ''SYSDBA'' PASSWORD ''masterkey'' ' +
      'PAGE_SIZE 8192 DEFAULT CHARACTER SET UTF8'
    );
  end;
end;

