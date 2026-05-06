unit MigrateMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.FB,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait,
  MigrateEngine, FormWizardSelectTables, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.Phys.Intf, FireDAC.Stan.Pool, Data.DB,
  Vcl.Controls, FireDAC.Phys.FBDef, Bde.DBTables, FireDAC.Phys.IBBase;

type
  TFormMain = class(TForm)
    BtnStart: TButton;
    MemoLog: TMemo;
    ProgressBar: TProgressBar;
    FDConnFB: TFDConnection;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;

    procedure FormCreate(Sender: TObject);
    procedure BtnStartClick(Sender: TObject);

  private
    FParadoxDB: TDatabase;            // BDE nativo
    procedure Log(const S: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

{------------------------------------------------------------------------------}
{  CONFIGURAZIONE INIZIALE }
{------------------------------------------------------------------------------}

procedure TFormMain.FormCreate(Sender: TObject);
var
  Root, PXPath: string;
  //uPath: string;

begin
  // Percorso base EXE
  // Root := ExtractFilePath(ExcludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)));
  Root := ExtractFilePath(Application.ExeName);
  PXPath := Root + 'Paradox';


  // -----------------------------
  // 1) BDE NATIVO PER PARADOX
  // -----------------------------
  FParadoxDB := TDatabase.Create(Self);
  FParadoxDB.DatabaseName := 'PXDB';
  FParadoxDB.DriverName := 'STANDARD';
  FParadoxDB.LoginPrompt := False;

  FParadoxDB.Params.Clear;
  FParadoxDB.Params.Add('PATH=' + PXPath);
  FParadoxDB.Params.Add('DEFAULT DRIVER=PARADOX');
  FParadoxDB.Params.Add('ENABLE BCD=FALSE');

  try
    FParadoxDB.Connected := True;
  except
    on E: Exception do
      raise Exception.Create('Errore apertura BDE Paradox: ' + E.Message);
  end;

  // -----------------------------
  // 2) FIREBIRD VIA FIREDAC
  // -----------------------------

  // --- Driver Link ---
  FDPhysFBDriverLink1.VendorHome  := ExtractFilePath(ParamStr(0)) + 'FB';
  FDPhysFBDriverLink1.VendorLib   := 'fbclient.dll';
  //FDPhysFBDriverLink1.VendorLib   := ExtractFilePath(ParamStr(0)) + 'FB\fbclient.dll';
  FDPhysFBDriverLink1.Embedded    := True;  // Modalità embedded!

  FDConnFB.Params.Clear;
  FDConnFB.Params.Add('DriverID=FB');
  FDConnFB.Params.Add('Database=' + Root + 'FB\MOT.fdb');
  FDConnFB.Params.Add('CharacterSet=UTF8');
  FDConnFB.Params.Add('User_Name=sysdba');
  FDConnFB.Params.Add('Password=');
  FDConnFB.Params.Add('Server=');       // -> emit exception database unavailable
  FDConnFB.Params.Add('Protocol=Local');
  FDConnFB.Params.Add('PageSize=8192');

  FDConnFB.DriverName := 'FB';
  FDConnFB.LoginPrompt := False;

  try
    FDConnFB.Connected := True;
  except
    on E: Exception do
      raise Exception.Create('Errore apertura FireBird: ' + E.Message);
  end;
end;

{------------------------------------------------------------------------------}
{  AVVIO MIGRAZIONE }
{------------------------------------------------------------------------------}

procedure TFormMain.BtnStartClick(Sender: TObject);
var
  Wizard: TFormSelectTables;
begin
  Wizard := TFormSelectTables.Create(Self, FParadoxDB); // FDConnParadox
  try
    if Wizard.ShowModal = mrOk then
    begin
      Log('Tabelle selezionate:');
      Log(Wizard.SelectedTables.Text);

     RunMigrationSelective(
            FParadoxDB,     // BDE nativo
            FDConnFB,       // FireDAC Firebird
            Wizard.SelectedTables,
            ProgressBar,
            MemoLog
          );

      Log('Migrazione completata.');
    end;
  finally
    Wizard.Free;
  end;
end;

{------------------------------------------------------------------------------}
{  LOG }
{------------------------------------------------------------------------------}
procedure TFormMain.Log(const S: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
end;

end.
