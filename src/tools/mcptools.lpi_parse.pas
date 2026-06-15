unit mcptools.lpi_parse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TParseLPITool - Parse .lpi project files and return project metadata }

  TParseLPITool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TParseLPITool }

constructor TParseLPITool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('lpi_path',
    TJSONObject.Create(['type', 'string']), True);
end;

procedure TParseLPITool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lLpiPath: string;
  lXML: TJSONObject;
begin
  lLpiPath := aInput.Get('lpi_path', '');

  if lLpiPath = '' then
    raise EMCPException.Create('lpi_path is required');

  if not FileExists(lLpiPath) then
    raise EMCPException.CreateFmt('File not found: %s', [lLpiPath]);

  lXML := TJSONObject.Create;
  try
    lXML.Add('path', lLpiPath);
    aResult.Add('project', lXML);
  finally
    lXML.Free;
  end;
end;

end.
