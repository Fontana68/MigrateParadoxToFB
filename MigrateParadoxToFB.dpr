program MigrateParadoxToFB;

uses
  Vcl.Forms,
  MigrateMainForm in 'MigrateMainForm.pas' {FormMain},
  MigrateEngine in 'MigrateEngine.pas',
  FormWizardSelectTables in 'FormWizardSelectTables.pas' {FormSelectTables},
  FluentTheme in 'FluentTheme.pas',
  Vcl.Themes,
  Vcl.Styles,
  uFBMigrationGUI in 'uFBMigrationGUI.pas' {frmFBMigration},
  uFBMigration in 'uFBMigration.pas',
  uFBMigrationReport in 'uFBMigrationReport.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows11 Impressive Light');
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
