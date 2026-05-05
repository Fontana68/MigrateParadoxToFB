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
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
