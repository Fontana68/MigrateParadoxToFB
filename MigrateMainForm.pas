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
  Vcl.Controls;

type
  TFormMain = class(TForm)
    BtnStart: TButton;
    MemoLog: TMemo;
    ProgressBar: TProgressBar;
    FDConnParadox: TFDConnection;
    FDConnFB: TFDConnection;
    procedure FormCreate(Sender: TObject);
    procedure BtnStartClick(Sender: TObject);
  private
    procedure Log(const S: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FDConnParadox.Params.Clear;
  FDConnParadox.Params.Add('DriverID=BDE');
  FDConnParadox.Params.Add('Database=.\Paradox');

  FDConnFB.Params.Clear;
  FDConnFB.Params.Add('DriverID=FB');
  FDConnFB.Params.Add('Database=.\FB\MOT.fdb');
  FDConnFB.Params.Add('User_Name=sysdba');
  FDConnFB.Params.Add('Password=masterkey');
  FDConnFB.Params.Add('Server=Embedded');
  FDConnFB.Params.Add('Protocol=Local');
end;

procedure TFormMain.BtnStartClick(Sender: TObject);
var
  Wizard: TFormSelectTables;
begin
  Wizard := TFormSelectTables.Create(Self, FDConnParadox);
  try
    if Wizard.ShowModal = mrOk then
    begin
      Log('Tabelle selezionate:');
      Log(Wizard.SelectedTables.Text);

      RunMigrationSelective(FDConnParadox, FDConnFB,
                            Wizard.SelectedTables,
                            ProgressBar, MemoLog);

      Log('Migrazione completata.');
    end;
  finally
    Wizard.Free;
  end;
end;

procedure TFormMain.Log(const S: string);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
end;

end.
