unit mcptools.build;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TBuildProjectTool = class(TMCPTool)
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

procedure TBuildProjectTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lProjectPath, lTargetOS, lTargetCPU: string;
  lOutput, lStdErr: string;
  lSuccess: Boolean;
  lErrors: TBuildErrorArray;
  lErrJSON: TJSONArray;
  lErrorCount, lWarnCount, lNoteCount: Integer;
  lErr: TBuildError;
  lCombinedOutput: string;
begin
  lProjectPath := aInput.Get('project_path', '');
  lTargetOS := aInput.Get('target_os', '');
  lTargetCPU := aInput.Get('target_cpu', '');

  if lProjectPath = '' then
    raise EMCPException.Create('project_path is required');

  if not FileExists(lProjectPath) then
    raise EMCPException.CreateFmt('Project file not found: %s', [lProjectPath]);

  lSuccess := RunLazBuild(GetLazBuildPath, GetFPCPath, GetFPCBinDir,
    lProjectPath, lTargetOS, lTargetCPU, lOutput, lStdErr);

  lCombinedOutput := lOutput;
  if lStdErr <> '' then
    lCombinedOutput := lCombinedOutput + LineEnding + lStdErr;

  // Parse compiler output for structured errors
  lErrors := ParseCompilerOutput(lCombinedOutput);

  // Count by severity
  lErrorCount := 0;
  lWarnCount := 0;
  lNoteCount := 0;
  for lErr in lErrors do
  begin
    if (lErr.Severity = 'error') then
      Inc(lErrorCount)
    else if lErr.Severity = 'warning' then
      Inc(lWarnCount)
    else if lErr.Severity = 'note' then
      Inc(lNoteCount);
  end;

  // Build result
  aResult.Add('success', lSuccess);
  aResult.Add('project_path', lProjectPath);
  if lTargetOS <> '' then
    aResult.Add('target_os', lTargetOS);
  if lTargetCPU <> '' then
    aResult.Add('target_cpu', lTargetCPU);

  // Truncate output if very long
  if Length(lCombinedOutput) > 50000 then
    lCombinedOutput := Copy(lCombinedOutput, 1, 50000) + '... [truncated]';
  aResult.Add('output', lCombinedOutput);

  lErrJSON := ErrorsToJSON(lErrors);
  aResult.Add('errors', lErrJSON);
  aResult.Add('error_count', lErrorCount);
  aResult.Add('warning_count', lWarnCount);
  aResult.Add('note_count', lNoteCount);
end;

end.
