unit FormWizardSelectTables;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.CheckLst,
  BDE,
  BDE.DBTables, Vcl.Controls,
  FireDAC.Stan.Param;

type
  TFormSelectTables = class(TForm)
    Label1: TLabel;
    CheckListTables: TCheckListBox;
    BtnSelectAll: TButton;
    BtnUnselectAll: TButton;
    BtnOK: TButton;
    BtnCancel: TButton;
    procedure BtnSelectAllClick(Sender: TObject);
    procedure BtnUnselectAllClick(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
  private
    FSelectedTables: TStringList;
  public
    constructor Create(AOwner: TComponent; ParadoxDB: TDatabase); reintroduce;
    destructor Destroy; override;
    property SelectedTables: TStringList read FSelectedTables;
  end;

implementation

{$R *.dfm}

constructor TFormSelectTables.Create(AOwner: TComponent; ParadoxDB: TDatabase);
var
  Tables: TStringList;
  T: string;
begin
  inherited Create(AOwner);

  FSelectedTables := TStringList.Create;
  Tables := TStringList.Create;
  try
    // RAD Studio 12.3 — firma corretta:
    // procedure GetTableNames(List: TStrings; SystemTables: Boolean = False);
    ParadoxDB.GetTableNames(Tables, False);

    // Filtra solo file Paradox .DB
    for T in Tables do
      begin
        //if SameText(ExtractFileExt(T), '.DB') then
          CheckListTables.Items.Add(T);
      end;

  finally
    Tables.Free;
  end;
end;

destructor TFormSelectTables.Destroy;
begin
  FSelectedTables.Free;
  inherited;
end;

procedure TFormSelectTables.BtnSelectAllClick(Sender: TObject);
var I: Integer;
begin
  for I := 0 to CheckListTables.Count - 1 do
    CheckListTables.Checked[I] := True;
end;

procedure TFormSelectTables.BtnUnselectAllClick(Sender: TObject);
var I: Integer;
begin
  for I := 0 to CheckListTables.Count - 1 do
    CheckListTables.Checked[I] := False;
end;

procedure TFormSelectTables.BtnOKClick(Sender: TObject);
var I: Integer;
begin
  FSelectedTables.Clear;
  for I := 0 to CheckListTables.Count - 1 do
    if CheckListTables.Checked[I] then
      FSelectedTables.Add(CheckListTables.Items[I]);

  ModalResult := mrOk;
end;

end.

