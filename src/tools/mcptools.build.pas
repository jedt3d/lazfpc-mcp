unit mcptools.build;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.tools;

type
  { TBuildProjectTool - Build a Lazarus .lpi project using lazbuild }

  TBuildProjectTool = class(TMCPTool)
  private
    FLazBuildPath: string;
    FFPCPath: string;
    FWorkspaceRoot: string;
    function BuildProject(const AProjectPath: string;
      ATargetOS, ATargetCPU: string; out AOutput: string): Boolean;
    procedure ResolveEnvironment;
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  mcputils.pathconfig, mcputils.build, mcputils.errorparser;

{ TBuildProjectTool }

constructor TBuildProjectTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('project_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('target_os',
    TJSONObject.Create(['type', 'string',
      'enum', TJSONArray.Create(['darwin', 'win64', 'linux'])]), False);
  InputSchema.AddArgument('target_cpu',
    TJSONObject.Create(['type', 'string',
      'enum', TJSONArray.Create(['aarch64', 'x86_64'])]), False);
end;

procedure TBuildProjectTool.ResolveEnvironment;
begin
  FWorkspaceRoot := GetWorkspaceRoot;
  FLazBuildPath := GetLazBuildPath;
  FFPCPath := GetFPCPath;
end;

procedure TBuildProjectTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lProjectPath, lTargetOS, lTargetCPU, lOutput: string;
  lSuccess: Boolean;
begin
  ResolveEnvironment;

  lProjectPath := aInput.Get('project_path', '');
  lTargetOS := aInput.Get('target_os', '');
  lTargetCPU := aInput.Get('target_cpu', '');

  if lProjectPath = '' then
    raise EMCPException.Create('project_path is required');

  lSuccess := BuildProject(lProjectPath, lTargetOS, lTargetCPU, lOutput);

  aResult.Add('success', lSuccess);
  aResult.Add('project_path', lProjectPath);
  if lTargetOS <> '' then
    aResult.Add('target_os', lTargetOS);
  if lTargetCPU <> '' then
    aResult.Add('target_cpu', lTargetCPU);
  aResult.Add('output', lOutput);
end;

end.
