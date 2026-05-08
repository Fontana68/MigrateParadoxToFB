unit uFBMigrationGUI;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Dialogs,
  Vcl.CheckLst, Vcl.Controls, Vcl.Graphics,
  Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.DApt, uFBMigration, uFBMigrationReport;

type
  TfrmFBMigration = class(TForm)
    lblStatus: TLabel;
    lblTables: TLabel;
    ProgressBarTotal: TProgressBar;
    ProgressBarTable: TProgressBar;
    clbTables: TCheckListBox;
    reLog: TRichEdit;
    btnRun: TButton;
    btnOpenHTML: TButton;
    btnOpenJSON: TButton;
    procedure btnRunClick(Sender: TObject);
    procedure btnOpenHTMLClick(Sender: TObject);
    procedure btnOpenJSONClick(Sender: TObject);
  private
    Conn: TFDConnection;
    Log: TStringList;
    JSON: TJSONObject;

    procedure LoadTablesFromDB;
    procedure ApplyLightMode;
    procedure ApplyDarkMode;
    procedure RunMigration;

    procedure UpdateProgressTotal(const Step, Total: Integer; const Msg: string);
    procedure UpdateProgressTable(const Step, Total: Integer; const Msg: string);

    procedure LogInfo(const Msg: string);
    procedure LogError(const Msg: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetTheme(const Dark: Boolean);
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

  ProgressBarTotal.Position := 0;
  ProgressBarTable.Position := 0;

  // Default: Light Mode
  SetTheme(False);
end;

destructor TfrmFBMigration.Destroy;
begin
  Conn.Free;
  Log.Free;
  JSON.Free;
  inherited;
end;

procedure TfrmFBMigration.SetTheme(const Dark: Boolean);
begin
  if Dark then
    ApplyDarkMode
  else
    ApplyLightMode;
end;

procedure TfrmFBMigration.ApplyLightMode;
begin
  Color := clBtnFace;
  reLog.Color := clWhite;
  reLog.Font.Color := clBlack;
  clbTables.Color := clWhite;
  clbTables.Font.Color := clBlack;
end;

procedure TfrmFBMigration.ApplyDarkMode;
begin
  Color := $202020;
  reLog.Color := $1A1A1A;
  reLog.Font.Color := clWhite;
  clbTables.Color := $1A1A1A;
  clbTables.Font.Color := clWhite;
end;

procedure TfrmFBMigration.LoadTablesFromDB;
var
  Q: TFDQuery;
begin
  clbTables.Items.Clear;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text :=
      'SELECT RDB$RELATION_NAME ' +
      'FROM RDB$RELATIONS ' +
      'WHERE RDB$SYSTEM_FLAG = 0 ' +
      'AND RDB$VIEW_SOURCE IS NULL ' +
      'ORDER BY RDB$RELATION_NAME';

    Q.Open;

    while not Q.Eof do
    begin
      clbTables.Items.Add(Trim(Q.Fields[0].AsString));
      Q.Next;
    end;

    // Seleziona tutte le tabelle
    for var i := 0 to clbTables.Items.Count - 1 do
      clbTables.Checked[i] := True;

  finally
    Q.Free;
  end;
end;

procedure TfrmFBMigration.UpdateProgressTotal(const Step, Total: Integer; const Msg: string);
begin
  ProgressBarTotal.Position := Round((Step / Total) * 100);
  lblStatus.Caption := Msg;
  LogInfo(Msg);
  Application.ProcessMessages;
end;

procedure TfrmFBMigration.UpdateProgressTable(const Step, Total: Integer; const Msg: string);
begin
  ProgressBarTable.Position := Round((Step / Total) * 100);
  LogInfo('  ' + Msg);
  Application.ProcessMessages;
end;

procedure TfrmFBMigration.LogInfo(const Msg: string);
begin
  reLog.SelAttributes.Color := clLime;
  reLog.Lines.Add(Msg);
end;

procedure TfrmFBMigration.LogError(const Msg: string);
begin
  reLog.SelAttributes.Color := clRed;
  reLog.Lines.Add(Msg);
end;

procedure TfrmFBMigration.btnRunClick(Sender: TObject);
begin
  RunMigration;
end;

procedure TfrmFBMigration.RunMigration;
var
  OD: TOpenDialog;
  DBPath: string;
  TableName: string;
  Table: TFDTable;
  i, TotalTables: Integer;
begin
  reLog.Clear;
  Log.Clear;

  JSON.Free;
  JSON := TJSONObject.Create;

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

  Conn.Params.Database := DBPath;
  Conn.Connected := True;

  // Auto-scan tabelle
  LoadTablesFromDB;

  TotalTables := clbTables.Items.Count;

  UpdateProgressTotal(0, TotalTables, 'Inizio migrazione...');

  for i := 0 to clbTables.Items.Count - 1 do
  begin
    if not clbTables.Checked[i] then
      Continue;

    TableName := clbTables.Items[i];

    UpdateProgressTotal(i + 1, TotalTables, 'Tabella: ' + TableName);

    Table := TFDTable.Create(nil);
    try
      Table.Connection := Conn;
      Table.TableName := TableName;
      Table.Open;

      UpdateProgressTable(0, 3, 'Analisi struttura...');

      CreateTriggersForTable(
        Conn,
        TableName,
        'ID_' + TableName,
        'GEN_' + TableName + '_ID',
        Table.Fields,
        Log,
        JSON);

      UpdateProgressTable(3, 3, 'Trigger completati.');

    except
      on E: Exception do
      begin
        LogError('Errore tabella ' + TableName + ': ' + E.Message);
      end;
    end;

    Table.Free;
  end;

  SaveHTMLReport(Log, 'migration_log.html');
  SaveJSONReport(JSON, 'migration_report.json');

  UpdateProgressTotal(TotalTables, TotalTables, 'Migrazione completata.');
  ShowMessage('Migrazione completata.');
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

