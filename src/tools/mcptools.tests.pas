unit mcptools.tests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TRunTestsTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  mcputils.pathconfig, mcputils.build, mcputils.errorparser, mcputils.process;

{ TRunTestsTool }

constructor TRunTestsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('test_project_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('suite_filter',
    TJSONObject.Create(['type', 'string',
      'description', 'Only run tests matching this name pattern']), False);
end;

procedure TRunTestsTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lProjectPath, lSuiteFilter: string;
  lBuildOutput, lBuildErr: string;
  lBuildSuccess: Boolean;
  lExePath, lBaseName, lTestOutput, lTestErr: string;
  lTestSuccess: Boolean;
  lResults: TJSONArray;
  lLines: TStringList;
  lTotalRun, lPassed, lFailed: Integer;
  I: Integer;
  lLine, lTrimmed: string;
  lColonPos: Integer;
  lSuite, lTestName, lStatus, lMessage: string;
  lResultObj: TJSONObject;
  lArgs: array of string;
  lErr: TBuildError;
  lErrArr: TBuildErrorArray;
  lErrJSON: TJSONArray;
begin
  lProjectPath := aInput.Get('test_project_path', '');
  lSuiteFilter := aInput.Get('suite_filter', '');

  if lProjectPath = '' then
    raise EMCPException.Create('test_project_path is required');

  if not FileExists(lProjectPath) then
    raise EMCPException.CreateFmt('Project file not found: %s', [lProjectPath]);

  aResult.Add('test_project_path', lProjectPath);

  // Step 1: Build the test project
  lBuildSuccess := RunLazBuild(GetLazBuildPath, GetFPCPath, GetFPCBinDir,
    lProjectPath, '', '', lBuildOutput, lBuildErr);

  aResult.Add('build_success', lBuildSuccess);

  if not lBuildSuccess then
  begin
    lErrArr := ParseCompilerOutput(lBuildOutput + LineEnding + lBuildErr);
    lErrJSON := ErrorsToJSON(lErrArr);
    aResult.Add('success', False);
    aResult.Add('output', lBuildOutput);
    aResult.Add('errors', lErrJSON);
    aResult.Add('error_count', Length(lErrArr));
    Exit;
  end;

  // Step 2: Find the executable
  lBaseName := ChangeFileExt(lProjectPath, '');
  lExePath := lBaseName;

  // Check for .app bundle on macOS
  if not FileExists(lExePath) then
  begin
    lExePath := ChangeFileExt(lProjectPath, '.app/Contents/MacOS/' +
      ExtractFileName(ChangeFileExt(lProjectPath, '')));
  end;

  if not FileExists(lExePath) then
  begin
    aResult.Add('success', False);
    aResult.Add('error', 'Test executable not found. Expected: ' + lBaseName);
    aResult.Add('build_output', lBuildOutput);
    Exit;
  end;

  aResult.Add('executable_path', lExePath);

  // Step 3: Run tests
  SetLength(lArgs, 1);
  lArgs[0] := '--all';
  if lSuiteFilter <> '' then
  begin
    SetLength(lArgs, 3);
    lArgs[0] := '--suite=' + lSuiteFilter;
    lArgs[1] := '--all';
    lArgs[2] := '--format=plain';
  end
  else
  begin
    SetLength(lArgs, 2);
    lArgs[0] := '--all';
    lArgs[1] := '--format=plain';
  end;

  lTestSuccess := RunProcess(lExePath, lArgs, lTestOutput, lTestErr);

  // Step 4: Parse output
  lResults := TJSONArray.Create;
  lTotalRun := 0;
  lPassed := 0;
  lFailed := 0;

  lLines := TStringList.Create;
  try
    lLines.Text := lTestOutput + LineEnding + lTestErr;
    for I := 0 to lLines.Count - 1 do
    begin
      lLine := lLines[I];
      lTrimmed := Trim(lLine);

      // Skip empty lines and headers
      if (lTrimmed = '') or (Pos('TestCases:', lTrimmed) = 1) or
         (Pos('TestSuite:', lTrimmed) = 1) then
        Continue;

      lStatus := '';
      lSuite := '';
      lTestName := '';
      lMessage := '';

      // Try format: SuiteName.TestName: PASS  or  SuiteName.TestName: Ok
      // or  SuiteName.TestName: FAIL - message
      lColonPos := Pos(': ', lTrimmed);
      if lColonPos > 0 then
      begin
        lTestName := Copy(lTrimmed, 1, lColonPos - 1);
        lLine := Trim(Copy(lTrimmed, lColonPos + 2, MaxInt));

        // Check status keywords
        if (Pos('PASS', UpperCase(lLine)) = 1) or (Pos('OK', UpperCase(lLine)) = 1) then
        begin
          lStatus := 'passed';
          lMessage := '';
        end
        else if (Pos('FAIL', UpperCase(lLine)) = 1) or (Pos('ERROR', UpperCase(lLine)) = 1) then
        begin
          lStatus := 'failed';
          // Extract message after FAIL/ERROR keyword
          lMessage := Trim(Copy(lLine, Pos(' ', lLine) + 1, MaxInt));
          if Copy(lMessage, 1, 2) = '- ' then
            lMessage := Trim(Copy(lMessage, 3, MaxInt));
        end;
      end;

      // Also handle indented test results: "  TestName: PASS"
      if (lStatus = '') and (lColonPos = 0) then
      begin
        if Pos('PASS', UpperCase(lTrimmed)) > 0 then
        begin
          lStatus := 'passed';
          lTestName := Trim(StringReplace(lTrimmed, 'PASS', '', [rfIgnoreCase]));
        end
        else if Pos('FAIL', UpperCase(lTrimmed)) > 0 then
        begin
          lStatus := 'failed';
          lTestName := Trim(StringReplace(lTrimmed, 'FAIL', '', [rfIgnoreCase]));
        end;
      end;

      if lStatus <> '' then
      begin
        Inc(lTotalRun);
        if lStatus = 'passed' then
          Inc(lPassed)
        else
          Inc(lFailed);

        // Split suite.testname if there's a dot
        lColonPos := Pos('.', lTestName);
        if lColonPos > 0 then
        begin
          lSuite := Copy(lTestName, 1, lColonPos - 1);
          lTestName := Copy(lTestName, lColonPos + 1, MaxInt);
        end;

        lResultObj := TJSONObject.Create;
        lResultObj.Add('suite', lSuite);
        lResultObj.Add('test', lTestName);
        lResultObj.Add('status', lStatus);
        if lMessage <> '' then
          lResultObj.Add('message', lMessage);
        lResults.Add(lResultObj);
      end;
    end;
  finally
    lLines.Free;
  end;

  aResult.Add('success', lFailed = 0);
  aResult.Add('tests_run', lTotalRun);
  aResult.Add('tests_passed', lPassed);
  aResult.Add('tests_failed', lFailed);
  aResult.Add('results', lResults);
  aResult.Add('output', lTestOutput);
end;

end.
