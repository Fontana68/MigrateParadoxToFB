unit uFBMigrationReport;

interface
uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils
  ;

procedure SaveHTMLReport(const Log: TStrings; const FileName: string);
procedure SaveJSONReport(const JSON: TJSONObject; const FileName: string);

implementation

procedure SaveHTMLReport(const Log: TStrings; const FileName: string);
var HTML: TStringList;
begin
  HTML := TStringList.Create;
  try
    HTML.Add('<html><head><meta charset="UTF-8">');
    HTML.Add('<style>body{font-family:Arial;} li{margin:4px 0;}</style>');
    HTML.Add('</head><body>');
    HTML.AddStrings(Log);
    HTML.Add('</body></html>');
    HTML.SaveToFile(FileName);
  finally
    HTML.Free;
  end;
end;

procedure SaveJSONReport(const JSON: TJSONObject; const FileName: string);
begin
  TFile.WriteAllText(FileName, JSON.ToJSON);
end;

end.
