unit mcptools.projects;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TListProjectsTool - Scan directories for .lpi/.lpr files }

  TListProjectsTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TListProjectsTool }

constructor TListProjectsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('directory_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('recursive',
    TJSONObject.Create(['type', 'boolean', 'description', 'Search subdirectories recursively (default true)']), False);
end;

procedure TListProjectsTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
begin
  raise EMCPException.Create('Not yet implemented - Phase 3');
end;

end.
