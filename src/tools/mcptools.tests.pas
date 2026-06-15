unit mcptools.tests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TRunTestsTool - Build and run FPCUnit test projects }

  TRunTestsTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TRunTestsTool }

constructor TRunTestsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('test_project_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('suite_filter',
    TJSONObject.Create(['type', 'string', 'description', 'Only run tests matching this name pattern']), False);
end;

procedure TRunTestsTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
begin
  raise EMCPException.Create('Not yet implemented - Phase 2');
end;

end.
