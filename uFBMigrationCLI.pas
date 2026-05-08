unit uFBMigrationCLI;

interface
uses
  System.SysUtils, System.Classes, System.JSON,
  FireDAC.Comp.Client, uFBMigration;

procedure RunMigrationCLI;

implementation

procedure RunMigrationCLI;
var
  Conn: TFDConnection;
  Log: TStringList;
  JSON: TJSONObject;
begin
  Conn := TFDConnection.Create(nil);
  Log := TStringList.Create;
  JSON := TJSONObject.Create;

  try
    Conn.DriverName := 'FB';
    Conn.Params.Database := ParamStr(1);
    Conn.Params.UserName := 'sysdba';
    Conn.Params.Password := 'masterkey';
    Conn.Connected := True;

    Log.Add('<h1>Migrazione Firebird</h1>');
    Log.Add('<p>Database: ' + ParamStr(1) + '</p>');

    // Esempio: migrazione trigger tabella CLIENT
    CreateTriggersForTable(
      Conn,
      'CLIENT',
      'ID_CLIENT',
      'GEN_CLIENT_ID_CLIENT',
      Conn.GetTable('CLIENT').Fields,
      Log,
      JSON);

    // Output
    Log.SaveToFile('migration_log.html');
    TFile.WriteAllText('migration_report.json', JSON.ToJSON);

    Writeln('Migrazione completata.');
    Halt(0);

  except
    on E: Exception do
    begin
      Writeln('Errore: ', E.Message);
      Halt(1);
    end;
  end;

  Conn.Free;
  Log.Free;
  JSON.Free;
end;

end.
