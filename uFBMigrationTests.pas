unit uFBMigrationTests;

interface
uses
  DUnitX.TestFramework, System.JSON, System.Classes,
  FireDAC.Comp.Client, uFBMigration;

type
  [TestFixture]
  TFBMigrationTests = class
  private
    Conn: TFDConnection;
    Log: TStringList;
    JSON: TJSONObject;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test] procedure Test_FieldExists;
    [Test] procedure Test_TriggerExists;
    [Test] procedure Test_GeneratorExists;
    [Test] procedure Test_TriggerGeneration;
    [Test] procedure Test_JSONReport;
  end;

implementation

procedure TFBMigrationTests.Setup;
begin
  Conn := TFDConnection.Create(nil);
  Conn.DriverName := 'FB';
  Conn.Params.Database := 'test.fdb';
  Conn.Params.UserName := 'sysdba';
  Conn.Params.Password := 'masterkey';
  Conn.Connected := True;

  Log := TStringList.Create;
  JSON := TJSONObject.Create;
end;

procedure TFBMigrationTests.TearDown;
begin
  Conn.Free;
  Log.Free;
  JSON.Free;
end;

procedure TFBMigrationTests.Test_FieldExists;
var F: TFields;
begin
  F := TFields.Create(nil);
  try
    Assert.IsFalse(FieldExists(F, 'ID'));
  finally
    F.Free;
  end;
end;

procedure TFBMigrationTests.Test_TriggerExists;
begin
  Assert.IsFalse(TriggerExists(Conn, 'NO_TRIGGER'));
end;

procedure TFBMigrationTests.Test_GeneratorExists;
begin
  Assert.IsFalse(GeneratorExists(Conn, 'NO_GEN'));
end;

procedure TFBMigrationTests.Test_TriggerGeneration;
var SQL: string;
begin
  SQL := GenerateTriggerBeforeInsertID('CLIENT', 'ID_CLIENT', 'GEN_CLIENT_ID_CLIENT');
  Assert.IsTrue(SQL.Contains('CREATE TRIGGER'));
end;

procedure TFBMigrationTests.Test_JSONReport;
begin
  AddItemToJSON('TEST', 'created', JSON);
  Assert.IsTrue(JSON.ToJSON.Contains('TEST'));
end;

end.
