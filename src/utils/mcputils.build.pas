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

function setenv(name, value: PChar; overwrite: LongInt): LongInt; cdecl; external 'c' name 'setenv';

function RunLazBuild(const ALazBuildPath, AFPCPath, AFPCBinDir: string;
  const AProjectPath, ATargetOS, ATargetCPU: string;
  out AOutput, AStdErr: string): Boolean;
var
  lProc: TProcess;
  lBuf: string;
  lOutStream, lErrStream: TMemoryStream;
  lNewPath: string;
begin
  AOutput := '';
  AStdErr := '';
  Result := False;

  lNewPath := AFPCBinDir + ':' + GetEnvironmentVariable('PATH');
  setenv('PATH', PChar(lNewPath), 1);

  lProc := TProcess.Create(nil);
  lOutStream := TMemoryStream.Create;
  lErrStream := TMemoryStream.Create;
  try
    lProc.Executable := ALazBuildPath;
    lProc.Parameters.Add('-B');
    lProc.Parameters.Add('--compiler=' + AFPCPath);
    if ATargetOS <> '' then
      lProc.Parameters.Add('--os=' + ATargetOS);
    if ATargetCPU <> '' then
      lProc.Parameters.Add('--cpu=' + ATargetCPU);
    lProc.Parameters.Add(AProjectPath);
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

    while lProc.Running or (lProc.Output.NumBytesAvailable > 0) or (lProc.Stderr.NumBytesAvailable > 0) do
    begin
      while lProc.Output.NumBytesAvailable > 0 do
      begin
        SetLength(lBuf, lProc.Output.NumBytesAvailable);
        lProc.Output.Read(lBuf[1], Length(lBuf));
        lOutStream.Write(lBuf[1], Length(lBuf));
      end;
      while lProc.Stderr.NumBytesAvailable > 0 do
      begin
        SetLength(lBuf, lProc.Stderr.NumBytesAvailable);
        lProc.Stderr.Read(lBuf[1], Length(lBuf));
        lErrStream.Write(lBuf[1], Length(lBuf));
      end;
      if lProc.Running then
        Sleep(10);
    end;

    lProc.WaitOnExit;

    if lOutStream.Size > 0 then
    begin
      SetLength(AOutput, lOutStream.Size);
      lOutStream.Position := 0;
      lOutStream.Read(AOutput[1], lOutStream.Size);
    end;

    if lErrStream.Size > 0 then
    begin
      SetLength(AStdErr, lErrStream.Size);
      lErrStream.Position := 0;
      lErrStream.Read(AStdErr[1], lErrStream.Size);
    end;

    Result := (lProc.ExitStatus = 0);
  finally
    lOutStream.Free;
    lErrStream.Free;
    lProc.Free;
  end;
end;

end.
