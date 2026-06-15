unit mcputils.pathconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  DefaultWorkspaceRoot = '/Users/worajedt/Lazarus';

function GetWorkspaceRoot: string;
function GetFPCPath: string;
function GetFPCVersion: string;
function GetLazBuildPath: string;
function GetFPCBinDir: string;
function BuildFPCPath: string;
function GetEnvironmentPath: string;

implementation

uses
  Process;

function GetWorkspaceRoot: string;
begin
  Result := DefaultWorkspaceRoot;
end;

function GetFPCBinDir: string;
begin
  Result := GetWorkspaceRoot + '/fpc/bin';
end;

function GetFPCPath: string;
begin
  Result := GetFPCBinDir + '/fpc';
end;

function GetLazBuildPath: string;
begin
  Result := GetWorkspaceRoot + '/lazarus/lazbuild';
end;

function GetFPCVersion: string;
var
  lProc: TProcess;
  lStream: TMemoryStream;
  lBuf: string;
  lLine: string;
  lPos: Integer;
begin
  Result := '3.2.2';
  lProc := TProcess.Create(nil);
  lStream := TMemoryStream.Create;
  try
    lProc.Executable := GetFPCPath;
    lProc.Parameters.Add('-iV');
    lProc.Options := [poUsePipes, poNoConsole, poWaitOnExit];
    try
      lProc.Execute;
    except
      on E: Exception do
        Exit;
    end;
    while lProc.Output.NumBytesAvailable > 0 do
    begin
      SetLength(lBuf, lProc.Output.NumBytesAvailable);
      lProc.Output.Read(lBuf[1], Length(lBuf));
      lStream.Write(lBuf[1], Length(lBuf));
    end;
    if lStream.Size > 0 then
    begin
      SetLength(lLine, lStream.Size);
      lStream.Position := 0;
      lStream.Read(lLine[1], lStream.Size);
      lLine := Trim(lLine);
      lPos := Pos(#10, lLine);
      if lPos > 0 then
        lLine := Trim(Copy(lLine, 1, lPos - 1));
      if lLine <> '' then
        Result := lLine;
    end;
  finally
    lStream.Free;
    lProc.Free;
  end;
end;

function BuildFPCPath: string;
begin
  Result := GetWorkspaceRoot + '/fpc/lib/fpc/' + GetFPCVersion;
end;

function GetEnvironmentPath: string;
begin
  Result := GetFPCBinDir + ':' + BuildFPCPath + ':' + GetEnvironmentVariable('PATH');
end;

end.
