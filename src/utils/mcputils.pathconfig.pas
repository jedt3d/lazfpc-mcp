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

implementation

function GetWorkspaceRoot: string;
begin
  Result := DefaultWorkspaceRoot;
end;

function GetFPCVersion: string;
var
  lFPCPath: string;
begin
  lFPCPath := GetFPCPath;
  if FileExists(lFPCPath) then
  begin
    // TODO: run fpc -iV and capture output
    Result := '3.2.2';
  end
  else
    Result := '3.2.2';
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

function BuildFPCPath: string;
begin
  Result := GetWorkspaceRoot + '/fpc/lib/fpc/' + GetFPCVersion;
end;

end.
