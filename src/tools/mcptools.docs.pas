unit mcptools.docs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TSearchFPCHelpTool - Search FPC RTL/FCL documentation }

  TSearchFPCHelpTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TSearchFPCHelpTool }

constructor TSearchFPCHelpTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('query',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('max_results',
    TJSONObject.Create(['type', 'integer', 'description', 'Maximum number of results to return (default 10)']), False);
end;

procedure TSearchFPCHelpTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
begin
  raise EMCPException.Create('Not yet implemented - Phase 3');
end;

end.
