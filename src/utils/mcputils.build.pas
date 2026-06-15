unit mcputils.build;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function RunLazBuild(const ALazBuildPath, AFPCPath, AFPCBinDir: string;
  const AProjectPath, ATargetOS, ATargetCPU: string;
  out AOutput, AStdErr: string): Boolean;

implementation

uses
  Process;

function RunLazBuild(const ALazBuildPath, AFPCPath, AFPCBinDir: string;
  const AProjectPath, ATargetOS, ATargetCPU: string;
  out AOutput, AStdErr: string): Boolean;
var
  lProc: TProcess;
  lOut, lErr: TStringList;
  lCmd: string;
begin
  AOutput := '';
  AStdErr := '';
  Result := False;

  lProc := TProcess.Create(nil);
  lOut := TStringList.Create;
  lErr := TStringList.Create;
  try
    lProc.Executable := ALazBuildPath;
    lProc.Parameters.Add('-B');
    lProc.Parameters.Add('--compiler=' + AFPCPath);
    lProc.Parameters.Add(AProjectPath);

    if ATargetOS <> '' then
      lProc.Parameters.Add('--os=' + ATargetOS);
    if ATargetCPU <> '' then
      lProc.Parameters.Add('--cpu=' + ATargetCPU);

    lProc.Options := [poUsePipes, poNoConsole];

    try
      lProc.Execute;
    except
      on E: Exception do
      begin
        AStdErr := 'Failed to execute lazbuild: ' + E.Message;
        Exit;
      end;
    end;

    while lProc.Running or (lProc.Output.NumBytesAvailable > 0) do
    begin
      if lProc.Output.NumBytesAvailable > 0 then
      begin
        SetLength(lCmd, lProc.Output.NumBytesAvailable);
        lProc.Output.Read(lCmd[1], Length(lCmd));
        AOutput := AOutput + lCmd;
      end;
      Sleep(10);
    end;

    if lProc.ExitStatus = 0 then
      Result := True;

    if lProc.ExitCode <> 0 then
      AStdErr := Format('lazbuild exited with code %d', [lProc.ExitCode]);
  finally
    lOut.Free;
    lErr.Free;
    lProc.Free;
  end;
end;

end.
