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
  Vcl.Controls, FireDAC.Phys.FBDef, Bde.DBTables;

type
  TFormMain = class(TForm)
    BtnStart: TButton;
    MemoLog: TMemo;
    ProgressBar: TProgressBar;
    FDConnFB: TFDConnection;

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
  //uPath := Root + 'Dati\Customer';

  //dbCustomer.Params.Clear;
  //dbCustomer.Params.Add('PATH=' + uPath);
  //dbCustomer.Params.Add('DEFAULT DRIVER=PARADOX');
  //dbCustomer.Params.Add('ENABLE BCD=FALSE');

  //FDPhysFBDriverLink1.VendorLib := ExtractFilePath(ParamStr(0)) + 'fbembed.dll';
  // oppure fbclient.dll, in base al package embedded che distribuisci

  //FDConnection1.Params.Clear;
  //FDConnection1.Params.Add('DriverID=FB');
  //FDConnection1.Params.Add('Database=' + ExtractFilePath(ParamStr(0)) + 'data\myapp.fdb');
  //FDConnection1.Params.Add('User_Name=sysdba');
  //FDConnection1.Params.Add('Password=masterkey');
  //FDConnection1.Params.Add('CharacterSet=UTF8');
  //FDConnection1.Connected := True;

  // uPath := '.\Paradox';

  //TDatabase *bdeDb = form->dbOld;   // tuo TDatabase BDE
  //TFDConnection *fbDb = form>dbCustomer;

  // FDConnParadox.Params.Clear;
  // FDConnParadox.Params.Add('DriverID=MSAcc');
  // FDConnParadox.Params.Add('Database=C:\SW\BuilderC\Progetti\SW800\PumpBDE\MigrateParadoxToFB\Paradox');

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
  FDConnFB.Params.Clear;
  FDConnFB.Params.Add('DriverID=FB');
  FDConnFB.Params.Add('Database=' + Root + 'FB\MOT.fdb');
  // FDConnFB.Params.Add('Database=C:\SW\BuilderC\Progetti\SW800\PumpBDE\MigrateParadoxToFB\FB\MOT.fdb');
  FDConnFB.Params.Add('User_Name=sysdba');
  FDConnFB.Params.Add('Password=');
  FDConnFB.Params.Add('Server=Embedded');
  FDConnFB.Params.Add('Protocol=Local');
  FDConnFB.LoginPrompt := False;
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
