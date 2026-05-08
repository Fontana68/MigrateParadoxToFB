unit uFBMigrationGUI;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Dialogs,
  Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.DApt, uFBMigration, uFBMigrationReport, Vcl.Controls;

type
  TfrmFBMigration = class(TForm)
    btnRun: TButton;
    btnOpenHTML: TButton;
    btnOpenJSON: TButton;
    MemoLog: TMemo;
    ProgressBar: TProgressBar;
    lblStatus: TLabel;
    procedure btnRunClick(Sender: TObject);
    procedure btnOpenHTMLClick(Sender: TObject);
    procedure btnOpenJSONClick(Sender: TObject);
  private
    Conn: TFDConnection;
    Log: TStringList;
    JSON: TJSONObject;
    procedure RunMigration;
    procedure UpdateProgress(const Step, Total: Integer; const Msg: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmFBMigration: TfrmFBMigration;

implementation

{$R *.dfm}

constructor TfrmFBMigration.Create(AOwner: TComponent);
begin
  inherited;

  Conn := TFDConnection.Create(nil);
  Conn.DriverName := 'FB';
  Conn.Params.UserName := 'sysdba';
  Conn.Params.Password := 'masterkey';

  Log := TStringList.Create;
  JSON := TJSONObject.Create;

  ProgressBar.Min := 0;
  ProgressBar.Max := 100;
end;

destructor TfrmFBMigration.Destroy;
begin
  Conn.Free;
  Log.Free;
  JSON.Free;
  inherited;
end;

procedure TfrmFBMigration.UpdateProgress(const Step, Total: Integer; const Msg: string);
begin
  ProgressBar.Position := Round((Step / Total) * 100);
  lblStatus.Caption := Msg;
  MemoLog.Lines.Add(Msg);
  Application.ProcessMessages;
end;

procedure TfrmFBMigration.btnRunClick(Sender: TObject);
begin
  RunMigration;
end;

procedure TfrmFBMigration.RunMigration;
var
  OD: TOpenDialog;
  DBPath: string;
  Table: TFDTable;
begin
  MemoLog.Clear;
  Log.Clear;

  JSON.Free;
  JSON := TJSONObject.Create;

  // --- DIALOGO FILE CORRETTO ---
  OD := TOpenDialog.Create(nil);
  try
    OD.Filter := 'Firebird Database (*.fdb)|*.fdb';
    OD.Title := 'Seleziona database Firebird';

    if not OD.Execute then
      Exit;

    DBPath := OD.FileName;
  finally
    OD.Free;
  end;

  // --- CONNESSIONE ---
  Conn.Params.Database := DBPath;
  Conn.Connected := True;

  UpdateProgress(1, 10, 'Connessione al database...');

  Table := TFDTable.Create(nil);
  try
    Table.Connection := Conn;
    Table.TableName := 'CLIENT';
    Table.Open;

    UpdateProgress(2, 10, 'Migrazione trigger CLIENT...');

    CreateTriggersForTable(
      Conn,
      'CLIENT',
      'ID_CLIENT',
      'GEN_CLIENT_ID_CLIENT',
      Table.Fields,
      Log,
      JSON);

    UpdateProgress(10, 10, 'Migrazione completata.');

    SaveHTMLReport(Log, 'migration_log.html');
    SaveJSONReport(JSON, 'migration_report.json');

    ShowMessage('Migrazione completata con successo.');

  finally
    Table.Free;
  end;
end;

procedure TfrmFBMigration.btnOpenHTMLClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar('migration_log.html'), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmFBMigration.btnOpenJSONClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar('migration_report.json'), nil, nil, SW_SHOWNORMAL);
end;

end.

