# build_package.ps1
# Crea la struttura del progetto, genera immagini e crea MigrateParadoxToFB.zip
# Versione corretta: garantisce che le directory esistano prima di salvare immagini

# Root working folder (cartella corrente + MigrateParadoxToFB)
$root = Join-Path (Get-Location) 'MigrateParadoxToFB'
$src = Join-Path $root 'Source'
$assets = Join-Path $root 'Assets'
$icons = Join-Path $assets 'Icons'
$inno = Join-Path $assets 'InnoSetup'
$fb = Join-Path $root 'FB'
$paradox = Join-Path $root 'Paradox'
$report = Join-Path $root 'Report'

# Crea cartelle (ricorsivamente)
$dirs = @($src, $assets, $icons, $inno, $fb, $paradox, $report)
foreach ($d in $dirs) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Funzione helper per scrivere file testo UTF8
function Write-TextFile($path, $content) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $content | Out-File -FilePath $path -Encoding UTF8 -Force
}

# Assicurati di avere System.Drawing caricato (per generare PNG/BMP)
Add-Type -AssemblyName System.Drawing

# Ensure directory exists for a given file path
function Ensure-DirExists($path) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

# Salva PNG garantendo che la directory esista
function Save-Png($bmp, $path) {
  Ensure-DirExists $path
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# Salva BMP con testo (per Inno Setup) garantendo directory
function Save-BmpWithText($width, $height, $bgColor, $text, $path, $fontSize=18) {
  Ensure-DirExists $path
  $bmp = New-Object System.Drawing.Bitmap $width, $height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear($bgColor)
  $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = New-Object System.Drawing.RectangleF(0,0,$width,$height)
  $g.DrawString($text, $font, $brush, $rect, $sf)
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
  $bmp.Dispose()
}

# -------------------------
# 1) Source\MigrateParadoxToFB.dpr
# -------------------------
$dpr = @'
program MigrateParadoxToFB;

uses
  Vcl.Forms,
  MigrateMainForm in 'MigrateMainForm.pas' {FormMain},
  MigrateEngine in 'MigrateEngine.pas',
  FormWizardSelectTables in 'FormWizardSelectTables.pas' {FormSelectTables},
  FluentTheme in 'FluentTheme.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Migrate Paradox → Firebird';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
'@
Write-TextFile (Join-Path $src 'MigrateParadoxToFB.dpr') $dpr

# -------------------------
# 2) Source\MigrateParadoxToFB.dproj
# -------------------------
$dproj = @'
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <PropertyGroup>
        <ProjectGuid>{A1B2C3D4-E5F6-47A8-9123-ABCDEF123456}</ProjectGuid>
        <ProjectVersion>19.0</ProjectVersion>
        <FrameworkType>VCL</FrameworkType>
        <Base>True</Base>
        <Config Condition="'$(Config)'==''">Debug</Config>
        <Platform Condition="'$(Platform)'==''">Win32</Platform>
        <MainSource>MigrateParadoxToFB.dpr</MainSource>
        <AppType>Application</AppType>
        <DCC_DcuOutput>.\dcu\$(Platform)\$(Config)</DCC_DcuOutput>
        <DCC_ExeOutput>.\bin\$(Platform)\$(Config)</DCC_ExeOutput>
        <DCC_UnitSearchPath>$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
        <DCC_UsePackage>FireDAC;FireDACCommon;FireDACCommonDriver;FireDACPhys;FireDACPhysFB;FireDACPhysBDE;FireDACVCLUI</DCC_UsePackage>
        <Manifest_File>$(BDS)\bin\default_app.manifest</Manifest_File>
        <Icon_MainIcon>$(BDS)\bin\delphi_PROJECTICON.ico</Icon_MainIcon>
        <DpiAware>true</DpiAware>
    </PropertyGroup>

    <PropertyGroup Condition="'$(Config)'=='Debug'">
        <DCC_DebugInfo>True</DCC_DebugInfo>
        <DCC_Optimize>False</DCC_Optimize>
        <DCC_GenerateStackFrames>True</DCC_GenerateStackFrames>
    </PropertyGroup>

    <PropertyGroup Condition="'$(Config)'=='Release'">
        <DCC_DebugInfo>False</DCC_DebugInfo>
        <DCC_Optimize>True</DCC_Optimize>
        <DCC_GenerateStackFrames>False</DCC_GenerateStackFrames>
    </PropertyGroup>

    <ItemGroup>
        <DelphiCompile Include="$(MainSource)">
            <MainSource>MainSource</MainSource>
        </DelphiCompile>

        <DCCReference Include="MigrateMainForm.pas"/>
        <DCCReference Include="MigrateEngine.pas"/>

        <None Include="MigrateMainForm.dfm"/>
    </ItemGroup>

    <ItemGroup>
        <BuildConfiguration Include="Debug">
            <Key>Cfg_1</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
        <BuildConfiguration Include="Release">
            <Key>Cfg_2</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
    </ItemGroup>

    <ProjectExtensions>
        <Borland.Personality>Delphi.Personality.12</Borland.Personality>
        <Borland.ProjectType>Application</Borland.ProjectType>
        <BorlandProject>
            <Delphi.Personality>
                <Source>
                    <Source Name="MainSource">MigrateParadoxToFB.dpr</Source>
                </Source>
                <Excluded_Packages>
                    <Excluded_Packages Name="$(BDSBIN)\dcloffice2k280.bpl">Microsoft Office 2000 Sample Automation Server Wrapper Components</Excluded_Packages>
                </Excluded_Packages>
            </Delphi.Personality>
        </BorlandProject>
    </ProjectExtensions>
</Project>
'@
Write-TextFile (Join-Path $src 'MigrateParadoxToFB.dproj') $dproj

# -------------------------
# 3) Source\MigrateMainForm.pas
# -------------------------
$migrateMainPas = @'
unit MigrateMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.BDE,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait,
  MigrateEngine, FormWizardSelectTables;

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
'@
Write-TextFile (Join-Path $src 'MigrateMainForm.pas') $migrateMainPas

# -------------------------
# 4) Source\MigrateMainForm.dfm
# -------------------------
$migrateMainDfm = @'
object FormMain: TFormMain
  Caption = ''Paradox → Firebird Migration Tool''
  ClientHeight = 420
  ClientWidth = 680
  Font.Name = ''Segoe UI''
  OnCreate = FormCreate

  object BtnStart: TButton
    Left = 16
    Top = 16
    Width = 150
    Height = 32
    Caption = ''Avvia Migrazione''
    OnClick = BtnStartClick
  end

  object ProgressBar: TProgressBar
    Left = 16
    Top = 64
    Width = 648
    Height = 24
  end

  object MemoLog: TMemo
    Left = 16
    Top = 104
    Width = 648
    Height = 300
    ScrollBars = ssVertical
  end

  object FDConnParadox: TFDConnection
    LoginPrompt = False
  end

  object FDConnFB: TFDConnection
    LoginPrompt = False
  end
end
'@
Write-TextFile (Join-Path $src 'MigrateMainForm.dfm') $migrateMainDfm

# -------------------------
# 5) Source\MigrateEngine.pas
# -------------------------
$migrateEngine = @'
unit MigrateEngine;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils,
  Vcl.ComCtrls, Vcl.StdCtrls,
  Data.DB,
  Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client,
  FireDAC.Comp.BatchMove, FireDAC.Comp.BatchMove.DataSet,
  FireDAC.Stan.Intf, FireDAC.Stan.Option;

type
  TTableReport = record
    TableName: string;
    RecordsCopied: Integer;
    PrimaryKey: string;
    Indices: TStringList;
    ForeignKeys: TStringList;
    AutoIncFields: TStringList;
    Errors: TStringList;
  end;

procedure RunMigrationSelective(ConnPX, ConnFB: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar; Log: TMemo);

implementation

var
  ReportList: array of TTableReport;

procedure ExecSQL(const Conn: TFDConnection; const SQL: string);
begin
  Conn.ExecSQL(SQL);
end;

function FBIdent(const S: string): string;
begin
  Result := StringReplace(S, '' '', '_' , [rfReplaceAll]);
end;

function MapFieldTypeToFB(Field: TField): string;
begin
  case Field.DataType of
    ftString, ftWideString:
      Result := ''VARCHAR('' + Field.Size.ToString + '')'';
    ftInteger:   Result := ''INTEGER'';
    ftSmallint:  Result := ''SMALLINT'';
    ftLargeint:  Result := ''BIGINT'';
    ftFloat:     Result := ''DOUBLE PRECISION'';
    ftCurrency:  Result := ''NUMERIC(18,4)'';
    ftBCD, ftFMTBcd:
      Result := ''NUMERIC(18,4)'';
    ftDate:      Result := ''DATE'';
    ftTime:      Result := ''TIME'';
    ftDateTime,
    ftTimeStamp: Result := ''TIMESTAMP'';
    ftMemo, ftWideMemo:
      Result := ''BLOB SUB_TYPE TEXT'';
    ftBlob:      Result := ''BLOB'';
    ftAutoInc:   Result := ''INTEGER'';
  else
    Result := ''VARCHAR(100)'';
  end;
end;

procedure CreateFBTableWithMeta(const TableName: string; ConnPX, ConnFB: TFDConnection;
                                Log: TMemo; Report: TTableReport);
var
  PX: TFDTable;
  SQL: TStringList;
  I: Integer;
  Field: TField;
  PKFields: string;
begin
  PX := TFDTable.Create(nil);
  SQL := TStringList.Create;
  try
    PX.Connection := ConnPX;
    PX.TableName := TableName;
    PX.IndexDefs.Update;
    PX.FieldDefs.Update;
    PX.Open;

    SQL.Add(''CREATE TABLE '' + FBIdent(TableName) + '' ('');

    PKFields := '''';
    for I := 0 to PX.FieldCount - 1 do
    begin
      Field := PX.Fields[I];

      if Field.DataType = ftAutoInc then
        Report.AutoIncFields.Add(Field.FieldName);

      SQL.Add(''  '' + FBIdent(Field.FieldName) + '' '' + MapFieldTypeToFB(Field) +
              IfThen(I < PX.FieldCount - 1, '','', ''''));

      if (ixPrimary in PX.IndexDefs.GetIndexForFields(Field.FieldName, False).Options) then
      begin
        if PKFields <> '' then
          PKFields := PKFields + ',';
        PKFields := PKFields + FBIdent(Field.FieldName);
      end;
    end;

    Report.PrimaryKey := PKFields;

    if PKFields <> '' then
    begin
      SQL.Add('' ,CONSTRAINT PK_'' + FBIdent(TableName) +
              '' PRIMARY KEY ('' + PKFields + '')'');
    end;

    SQL.Add('');'');');

    ExecSQL(ConnFB, SQL.Text);

    for I := 0 to PX.IndexDefs.Count - 1 do
    begin
      if (ixPrimary in PX.IndexDefs[I].Options) then
        Continue;

      if PX.IndexDefs[I].Fields = '' then
        Continue;

      SQL.Clear;
      SQL.Add(''CREATE INDEX IX_'' + FBIdent(TableName) + ''_'' +
              FBIdent(PX.IndexDefs[I].Name) + '' ON '' + FBIdent(TableName) +
              '' ('' + StringReplace(PX.IndexDefs[I].Fields, ';', ',', [rfReplaceAll]) + '');'');

      ExecSQL(ConnFB, SQL.Text);
      Report.Indices.Add(PX.IndexDefs[I].Name + '' ('' + PX.IndexDefs[I].Fields + '')'');
    end;

    for I := 0 to Report.AutoIncFields.Count - 1 do
    begin
      SQL.Clear;
      SQL.Add(''CREATE SEQUENCE GEN_'' + FBIdent(TableName) + ''_'' + FBIdent(Report.AutoIncFields[I]) + '';'');
      ExecSQL(ConnFB, SQL.Text);

      SQL.Clear;
      SQL.Add(''CREATE TRIGGER BI_'' + FBIdent(TableName) + ''_'' + FBIdent(Report.AutoIncFields[I]));
      SQL.Add(''FOR '' + FBIdent(TableName));
      SQL.Add(''ACTIVE BEFORE INSERT POSITION 0'');
      SQL.Add(''AS'');
      SQL.Add(''BEGIN'');
      SQL.Add(''  IF (NEW.'' + FBIdent(Report.AutoIncFields[I]) + '' IS NULL) THEN'');
      SQL.Add(''    NEW.'' + FBIdent(Report.AutoIncFields[I]) + '' = NEXT VALUE FOR GEN_'' +
              FBIdent(TableName) + ''_'' + FBIdent(Report.AutoIncFields[I]) + '';''');
      SQL.Add(''END;'');
      ExecSQL(ConnFB, SQL.Text);
    end;

  except
    on E: Exception do
      Report.Errors.Add(E.Message);
  end;

  PX.Free;
  SQL.Free;
end;

procedure CreateForeignKeysHeuristic(const TableName: string; ConnFB: TFDConnection;
                                     Log: TMemo; Report: TTableReport);
var
  Q: TFDQuery;
  FieldName, RefTable: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := ConnFB;
    Q.SQL.Text := 'SELECT RDB$FIELD_NAME FROM RDB$RELATION_FIELDS ' +
                  'WHERE RDB$RELATION_NAME = :T';
    Q.ParamByName('T').AsString := UpperCase(TableName);
    Q.Open;

    while not Q.Eof do
    begin
      FieldName := Trim(Q.Fields[0].AsString);

      if FieldName.EndsWith('_ID') then
      begin
        RefTable := Copy(FieldName, 1, Length(FieldName) - 3);

        try
          ConnFB.ExecSQL(
            'ALTER TABLE ' + FBIdent(TableName) +
            ' ADD CONSTRAINT FK_' + FBIdent(TableName) + '_' + FBIdent(FieldName) +
            ' FOREIGN KEY (' + FBIdent(FieldName) + ') REFERENCES ' + FBIdent(RefTable) + '(ID);'
          );

          Report.ForeignKeys.Add(FieldName + ' → ' + RefTable);

        except
          Report.Errors.Add(''FK fallita: '' + FieldName + ' → ' + RefTable);
        end;
      end;

      Q.Next;
    end;

  finally
    Q.Free;
  end;
end;

procedure CopyData(const TableName: string; ConnPX, ConnFB: TFDConnection;
                   Log: TMemo; Report: TTableReport);
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
    Src.Connection := ConnPX;
    Src.TableName := TableName;

    Dst.Connection := ConnFB;
    Dst.SQL.Text := 'SELECT * FROM ' + FBIdent(TableName);

    Reader.DataSet := Src;
    Writer.DataSet := Dst;

    Move.Reader := Reader;
    Move.Writer := Writer;
    Move.Options := [poClearDest, poIdentityInsert];
    Move.Execute;

    Report.RecordsCopied := Src.RecordCount;

  except
    on E: Exception do
      Report.Errors.Add(E.Message);
  end;

  Src.Free;
  Dst.Free;
  Move.Free;
  Reader.Free;
  Writer.Free;
end;

procedure SaveHTMLReport(const FileName: string);
var
  SL: TStringList;
  I, J: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="UTF-8">');
    SL.Add('<style>');
    SL.Add('body { font-family: Segoe UI; margin: 20px; }');
    SL.Add('table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }');
    SL.Add('th, td { border: 1px solid #ccc; padding: 8px; }');
    SL.Add('th { background: #eee; }');
    SL.Add('.error { color: red; }');
    SL.Add('</style></head><body>');

    SL.Add('<h1>Report Migrazione Paradox → Firebird</h1>');
    SL.Add('<p>Generato il ' + DateTimeToStr(Now) + '</p>');

    for I := 0 to High(ReportList) do
    begin
      SL.Add('<h2>Tabella: ' + ReportList[I].TableName + '</h2>');
      SL.Add('<table>');
      SL.Add('<tr><th>Campo</th><th>Valore</th></tr>');

      SL.Add('<tr><td>Record copiati</td><td>' + ReportList[I].RecordsCopied.ToString + '</td></tr>');
      SL.Add('<tr><td>Primary Key</td><td>' + ReportList[I].PrimaryKey + '</td></tr>');

      SL.Add('<tr><td>Indici</td><td><ul>');
      for J := 0 to ReportList[I].Indices.Count - 1 do
        SL.Add('<li>' + ReportList[I].Indices[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Foreign Keys</td><td><ul>');
      for J := 0 to ReportList[I].ForeignKeys.Count - 1 do
        SL.Add('<li>' + ReportList[I].ForeignKeys[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Autoincrement</td><td><ul>');
      for J := 0 to ReportList[I].AutoIncFields.Count - 1 do
        SL.Add('<li>' + ReportList[I].AutoIncFields[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('<tr><td>Errori</td><td><ul>');
      for J := 0 to ReportList[I].Errors.Count - 1 do
        SL.Add('<li class="error">' + ReportList[I].Errors[J] + '</li>');
      SL.Add('</ul></td></tr>');

      SL.Add('</table>');
    end;

    SL.Add('</body></html>');
    SL.SaveToFile(FileName, TEncoding.UTF8);

  finally
    SL.Free;
  end;
end;

procedure RunMigrationSelective(ConnPX, ConnFB: TFDConnection;
                                Tables: TStringList;
                                Progress: TProgressBar; Log: TMemo);
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

    Log.Lines.Add('Creazione schema: ' + T);
    CreateFBTableWithMeta(T, ConnPX, ConnFB, Log, ReportList[I]);

    Log.Lines.Add('Copia dati: ' + T);
    CopyData(T, ConnPX, ConnFB, Log, ReportList[I]);

    Log.Lines.Add('Foreign key (euristica): ' + T);
    CreateForeignKeysHeuristic(T, ConnFB, Log, ReportList[I]);

    Progress.Position := Progress.Position + 1;
  end;

  ForceDirectories('.\Report');
  SaveHTMLReport('.\Report\MigrationReport.html');

  ShellExecute(0, 'open', PChar('.\Report\MigrationReport.html'), nil, nil, SW_SHOWNORMAL);
end;

end.
'@
Write-TextFile (Join-Path $src 'MigrateEngine.pas') $migrateEngine

# -------------------------
# 6) Source\FormWizardSelectTables.pas
# -------------------------
$formWizardPas = @'
unit FormWizardSelectTables;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.CheckLst,
  FireDAC.Comp.Client;

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
    constructor Create(AOwner: TComponent; ConnPX: TFDConnection); reintroduce;
    destructor Destroy; override;
    property SelectedTables: TStringList read FSelectedTables;
  end;

implementation

{$R *.dfm}

constructor TFormSelectTables.Create(AOwner: TComponent; ConnPX: TFDConnection);
var
  Tables: TStringList;
  T: string;
begin
  inherited Create(AOwner);

  FSelectedTables := TStringList.Create;
  Tables := TStringList.Create;
  try
    ConnPX.GetTableNames('', '', '', Tables);
    for T in Tables do
      CheckListTables.Items.Add(T);
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
'@
Write-TextFile (Join-Path $src 'FormWizardSelectTables.pas') $formWizardPas

# -------------------------
# 7) Source\FormWizardSelectTables.dfm
# -------------------------
$formWizardDfm = @'
object FormSelectTables: TFormSelectTables
  Caption = ''Seleziona tabelle da migrare''
  ClientHeight = 420
  ClientWidth = 420
  Position = poScreenCenter

  object Label1: TLabel
    Left = 16
    Top = 16
    Caption = ''Seleziona le tabelle Paradox da migrare:''
  end

  object CheckListTables: TCheckListBox
    Left = 16
    Top = 40
    Width = 388
    Height = 300
  end

  object BtnSelectAll: TButton
    Left = 16
    Top = 350
    Width = 100
    Caption = ''Seleziona tutto''
    OnClick = BtnSelectAllClick
  end

  object BtnUnselectAll: TButton
    Left = 130
    Top = 350
    Width = 100
    Caption = ''Deseleziona tutto''
    OnClick = BtnUnselectAllClick
  end

  object BtnOK: TButton
    Left = 260
    Top = 350
    Width = 60
    Caption = ''OK''
    ModalResult = 1
    OnClick = BtnOKClick
  end

  object BtnCancel: TButton
    Left = 340
    Top = 350
    Width = 60
    Caption = ''Annulla''
    ModalResult = 2
  end
end
'@
Write-TextFile (Join-Path $src 'FormWizardSelectTables.dfm') $formWizardDfm

# -------------------------
# 8) Source\FluentTheme.pas
# -------------------------
$fluent = @'
unit FluentTheme;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.DwmApi,
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.Imaging.pngimage;

type
  TFluentThemeMode = (ftLight, ftDark);

procedure ApplyFluentTheme(Form: TForm; Mode: TFluentThemeMode);
procedure ApplyMica(Form: TForm);
procedure StyleFluentButton(B: TButton; Mode: TFluentThemeMode);
procedure StyleNavButton(B: TButton; Mode: TFluentThemeMode);
procedure FadeIn(Form: TForm; DurationMs: Integer = 250);
procedure SlideIn(Control: TControl; Offset: Integer = 40; DurationMs: Integer = 200);
procedure EnableRevealHighlight(B: TButton; Mode: TFluentThemeMode);

implementation

const
  COLOR_BG_LIGHT      = $00FFFFFF;
  COLOR_PANEL_LIGHT   = $00F3F3F3;
  COLOR_TEXT_DARK     = $00202020;

  COLOR_BG_DARK       = $00202020;
  COLOR_PANEL_DARK    = $00282828;
  COLOR_TEXT_LIGHT    = $00FFFFFF;

  COLOR_ACCENT        = $00D77800; // Fluent Orange

// ------------------------------------------------------------
//  MICA EFFECT (Windows 11)
// ------------------------------------------------------------
procedure ApplyMica(Form: TForm);
var
  attr, val: Integer;
begin
  attr := 1029; // DWMWA_SYSTEMBACKDROP_TYPE
  val := 2;     // Mica Alt
  DwmSetWindowAttribute(Form.Handle, attr, @val, SizeOf(val));
end;

// ------------------------------------------------------------
//  THEME APPLICATION
// ------------------------------------------------------------
procedure ApplyFluentTheme(Form: TForm; Mode: TFluentThemeMode);
var
  I: Integer;
begin
  if Mode = ftDark then
  begin
    Form.Color := COLOR_BG_DARK;
    Form.Font.Color := COLOR_TEXT_LIGHT;
  end
  else
  begin
    Form.Color := COLOR_BG_LIGHT;
    Form.Font.Color := COLOR_TEXT_DARK;
  end;

  // Apply theme to all panels
  for I := 0 to Form.ComponentCount - 1 do
    if Form.Components[I] is TPanel then
      if Mode = ftDark then
        (Form.Components[I] as TPanel).Color := COLOR_PANEL_DARK
      else
        (Form.Components[I] as TPanel).Color := COLOR_PANEL_LIGHT;
end;

// ------------------------------------------------------------
//  BUTTON STYLE (WinUI)
// ------------------------------------------------------------
procedure StyleFluentButton(B: TButton; Mode: TFluentThemeMode);
begin
  B.Flat := True;
  B.ParentBackground := False;
  B.Font.Name := 'Segoe UI Semibold';
  B.Font.Height := -15;

  if Mode = ftDark then
  begin
    B.Color := COLOR_PANEL_DARK;
    B.Font.Color := COLOR_TEXT_LIGHT;
  end
  else
  begin
    B.Color := COLOR_PANEL_LIGHT;
    B.Font.Color := COLOR_TEXT_DARK;
  end;
end;

// ------------------------------------------------------------
//  NAVIGATION BUTTON STYLE
// ------------------------------------------------------------
procedure StyleNavButton(B: TButton; Mode: TFluentThemeMode);
begin
  StyleFluentButton(B, Mode);
  B.Align := alTop;
  B.Height := 40;
  B.Margins.SetBounds(0, 0, 0, 0);
end;

// ------------------------------------------------------------
//  ANIMATIONS
// ------------------------------------------------------------
procedure FadeIn(Form: TForm; DurationMs: Integer);
var
  i: Integer;
  Step: Integer;
begin
  Form.AlphaBlend := True;
  Form.AlphaBlendValue := 0;
  Step := 255 div (DurationMs div 5);

  for i := 0 to 255 do
  begin
    Form.AlphaBlendValue := i;
    Sleep(5);
    Application.ProcessMessages;
  end;
end;

procedure SlideIn(Control: TControl; Offset: Integer; DurationMs: Integer);
var
  StartLeft, TargetLeft, Step: Integer;
begin
  StartLeft := Control.Left + Offset;
  TargetLeft := Control.Left;
  Control.Left := StartLeft;

  Step := Offset div (DurationMs div 5);

  while Control.Left > TargetLeft do
  begin
    Control.Left := Control.Left - Step;
    Sleep(5);
    Application.ProcessMessages;
  end;

  Control.Left := TargetLeft;
end;

// ------------------------------------------------------------
//  REVEAL HIGHLIGHT (Hover)
// ------------------------------------------------------------
procedure EnableRevealHighlight(B: TButton; Mode: TFluentThemeMode);
begin
  B.OnMouseEnter :=
    procedure(Sender: TObject)
    begin
      B.Color := COLOR_ACCENT;
    end;

  B.OnMouseLeave :=
    procedure(Sender: TObject)
    begin
      if Mode = ftDark then
        B.Color := COLOR_PANEL_DARK
      else
        B.Color := COLOR_PANEL_LIGHT;
    end;
end;

end.
'@
Write-TextFile (Join-Path $src 'FluentTheme.pas') $fluent

# -------------------------
# 9-11) SVG icons
# -------------------------
$playSvg = '<svg viewBox="0 0 24 24" fill="#ffffff" xmlns="http://www.w3.org/2000/svg">
  <path d="M8 5v14l11-7z"/>
</svg>'
$closeSvg = '<svg viewBox="0 0 24 24" fill="#ffffff" xmlns="http://www.w3.org/2000/svg">
  <path d="M18.3 5.71L12 12l6.3 6.29-1.41 1.41L12 13.41l-6.29 6.29-1.41-1.41L10.59 12 4.29 5.71 5.7 4.29 12 10.59l6.29-6.3z"/>
</svg>'
$dbSvg = '<svg viewBox="0 0 24 24" fill="#ffffff" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 2C7.03 2 3 3.79 3 6v12c0 2.21 4.03 4 9 4s9-1.79 9-4V6c0-2.21-4.03-4-9-4zm0 2c4.42 0 7 .99 7 2s-2.58 2-7 2-7-.99-7-2 2.58-2 7-2zm0 16c-4.42 0-7-.99-7-2v-2.5c1.66 1.03 4.34 1.5 7 1.5s5.34-.47 7-1.5V18c0 1.01-2.58 2-7 2zm0-6c-4.42 0-7-.99-7-2v-2.5c1.66 1.03 4.34 1.5 7 1.5s5.34-.47 7-1.5V12c0 1.01-2.58 2-7 2z"/>
</svg>'
Write-TextFile (Join-Path $icons 'play.svg') $playSvg
Write-TextFile (Join-Path $icons 'close.svg') $closeSvg
Write-TextFile (Join-Path $icons 'database.svg') $dbSvg

# -------------------------
# 12-14) Create simple 32x32 PNG placeholders programmatically
# -------------------------
# play.png: triangle on transparent
$bmp = New-Object System.Drawing.Bitmap 32,32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$points = [System.Drawing.Point[]]@( [System.Drawing.Point]::new(8,6), [System.Drawing.Point]::new(24,16), [System.Drawing.Point]::new(8,26) )
$g.FillPolygon($brush, $points)
$g.Dispose()
Save-Png $bmp (Join-Path $icons 'play.png')

# close.png: X
$bmp = New-Object System.Drawing.Bitmap 32,32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White,3)
$g.DrawLine($pen,4,4,28,28)
$g.DrawLine($pen,28,4,4,28)
$pen.Dispose()
$g.Dispose()
Save-Png $bmp (Join-Path $icons 'close.png')

# database.png: simple cylinder
$bmp = New-Object System.Drawing.Bitmap 32,32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White,2)
$g.DrawEllipse($pen,6,6,20,8)
$g.DrawEllipse($pen,6,12,20,8)
$g.DrawEllipse($pen,6,18,20,8)
$pen.Dispose()
$g.Dispose()
Save-Png $bmp (Join-Path $icons 'database.png')

# -------------------------
# 15-16) Generate BMPs for Inno Setup (banner 164x314 and icon 55x55)
# -------------------------
# banner: light gray background, title text
Save-BmpWithText -width 164 -height 314 -bgColor ([System.Drawing.Color]::FromArgb(243,243,243)) -text 'Migrate Paradox → Firebird' -path (Join-Path $inno 'wizard_banner.bmp') -fontSize 14

# icon: accent background, small DB text
Save-BmpWithText -width 55 -height 55 -bgColor ([System.Drawing.Color]::FromArgb(215,120,0)) -text 'DB' -path (Join-Path $inno 'wizard_icon.bmp') -fontSize 20

# -------------------------
# 17-19) FB placeholders
# -------------------------
# MOT.fdb (zero-byte placeholder)
$motPath = Join-Path $fb 'MOT.fdb'
if (-not (Test-Path $motPath)) { New-Item -Path $motPath -ItemType File -Force | Out-Null }

# placeholder DLL/text files
Write-TextFile (Join-Path $fb 'fbclient.dll') 'This is a placeholder for fbclient.dll. Replace with actual Firebird client DLL when packaging.'
Write-TextFile (Join-Path $fb 'icudt.dll') 'This is a placeholder for ICU data DLL. Replace with actual icudt*.dll when packaging.'
Write-TextFile (Join-Path $fb 'firebird.conf') '# Minimal Firebird Embedded config
DatabaseAccess = Restrict
RemoteBindAddress = 127.0.0.1
# Adjust as needed'

# -------------------------
# 21-22) Paradox placeholders
# -------------------------
Write-TextFile (Join-Path $paradox 'README.txt') 'Place your Paradox .DB files in this folder before running the migration.'
$sampleDb = Join-Path $paradox 'sample.DB'
if (-not (Test-Path $sampleDb)) { New-Item -Path $sampleDb -ItemType File -Force | Out-Null }

# -------------------------
# 23) Report placeholder
# -------------------------
$reportHtml = '<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Migration Report</title></head><body>
<p>Report will be generated here after migration.</p>
</body></html>'
Write-TextFile (Join-Path $report 'MigrationReport.html') $reportHtml

# -------------------------
# Create ZIP
# -------------------------
$zipPath = Join-Path (Get-Location) 'MigrateParadoxToFB.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $root '*') -DestinationPath $zipPath -Force

Write-Host "ZIP creato: $zipPath"
Write-Host "Contenuto incluso:"
Get-ChildItem -Recurse $root | ForEach-Object { Write-Host $_.FullName.Replace((Get-Location).Path + '\','') }
