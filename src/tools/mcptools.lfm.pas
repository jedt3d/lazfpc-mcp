unit mcptools.lfm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TParseLFMTool - Parse .lfm form files and return component tree }

  TParseLFMTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TParseLFMTool }

constructor TParseLFMTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('lfm_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('max_depth',
    TJSONObject.Create(['type', 'integer', 'description', 'Max depth for component tree (0 = unlimited)']), False);
end;

procedure TParseLFMTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lLfmPath, lLine: string;
  lList: TStringList;
  lCount: Integer;
  lObj: TJSONObject;
begin
  lLfmPath := aInput.Get('lfm_path', '');

  if lLfmPath = '' then
    raise EMCPException.Create('lfm_path is required');

  if not FileExists(lLfmPath) then
    raise EMCPException.CreateFmt('File not found: %s', [lLfmPath]);

  lList := TStringList.Create;
  try
    lList.LoadFromFile(lLfmPath);

    aResult.Add('lfm_path', lLfmPath);
    aResult.Add('total_lines', lList.Count);

    lObj := TJSONObject.Create;
    aResult.Add('summary', lObj);
    lObj.Add('lines', lList.Count);
  finally
    lList.Free;
  end;
end;

end.
