unit mcputils.process;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function RunProcess(const AExecutable: string; const AArgs: array of string;
  out AStdOut, AStdErr: string; ATimeoutMs: Cardinal = 60000): Boolean;

implementation

uses
  Process;

function RunProcess(const AExecutable: string; const AArgs: array of string;
  out AStdOut, AStdErr: string; ATimeoutMs: Cardinal = 60000): Boolean;
var
  lProc: TProcess;
  lBuf: string;
  lOutStream, lErrStream: TMemoryStream;
  lElapsed: Cardinal;
  I: Integer;
begin
  AStdOut := '';
  AStdErr := '';
  Result := False;

  lProc := TProcess.Create(nil);
  lOutStream := TMemoryStream.Create;
  lErrStream := TMemoryStream.Create;
  try
    lProc.Executable := AExecutable;
    for I := 0 to High(AArgs) do
      lProc.Parameters.Add(AArgs[I]);
    lProc.Options := [poUsePipes, poNoConsole];

    try
      lProc.Execute;
    except
      on E: Exception do
      begin
        AStdErr := 'Failed to execute ' + AExecutable + ': ' + E.Message;
        Exit;
      end;
    end;

    lElapsed := 0;
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
      if not lProc.Running then
        Break;
      Sleep(10);
      Inc(lElapsed, 10);
      if lElapsed >= ATimeoutMs then
      begin
        lProc.Terminate(1);
        AStdErr := AStdErr + LineEnding + 'Process timed out after ' + IntToStr(ATimeoutMs) + 'ms';
        Break;
      end;
    end;

    lProc.WaitOnExit;

    if lOutStream.Size > 0 then
    begin
      SetLength(AStdOut, lOutStream.Size);
      lOutStream.Position := 0;
      lOutStream.Read(AStdOut[1], lOutStream.Size);
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
