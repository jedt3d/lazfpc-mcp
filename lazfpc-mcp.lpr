{
  This file is part of the lazfpc-mcp project.

  lazfpc-mcp - MCP server for Lazarus/Free Pascal development
  Copyright (c) 2025 by Worajedt Sitthidumrong

  See the file COPYING.FPC, included in this distribution,
  for details about the copyright.

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published
  by the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version with the following exception:

  As a special exception, if you link this library with other files to
  produce an executable, this library does not by itself cause the resulting
  executable to be covered by the GNU Library General Public License. This
  exception does not however invalidate any other reasons why the executable
  file might be covered by the GNU Library General Public License.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

program lazfpc_mcp;

{$mode objfpc}{$H+}

uses
  mcp.application.stdio,
  mcp.tools,
  mcp.resources,
  mcp.prompts,
  mcptools.build,
  mcptools.lfm,
  mcptools.lpi_parse,
  mcptools.tests,
  mcptools.docs,
  mcptools.projects;

type
  { TLazFPCMCPApplication }

  TLazFPCMCPApplication = class(TMCPStdIOApplication)
  private
    procedure RegisterTools;
  protected
    procedure DoRun; override;
  public
    procedure Initialize; override;
  end;

{ TLazFPCMCPApplication }

procedure TLazFPCMCPApplication.Initialize;
begin
  inherited Initialize;
end;

procedure TLazFPCMCPApplication.RegisterTools;
begin
  TBuildProjectTool.Create(
    'build_project',
    'Build a Lazarus .lpi project using lazbuild. ' +
    'Returns compiler output, errors, and warnings as structured JSON. ' +
    'Supports macOS (darwin) and Windows (win64) cross-compilation targets.'
  ).Register;

  TParseLFMTool.Create(
    'parse_lfm',
    'Parse a Lazarus .lfm form file and return the component tree as JSON. ' +
    'Returns component names, class types, properties (position, size, align, anchors), ' +
    'and nested child components.'
  ).Register;

  TParseLPITool.Create(
    'parse_lpi',
    'Parse a Lazarus .lpi project file and return project metadata. ' +
    'Returns units list, dependencies, compiler options, output directory, ' +
    'and target platform settings.'
  ).Register;

  TRunTestsTool.Create(
    'run_fpcunit_tests',
    'Build and run an FPCUnit test project. ' +
    'Returns pass/fail results per test case, total counts, and execution time.'
  ).Register;

  TSearchFPCHelpTool.Create(
    'search_fpc_help',
    'Search Free Pascal RTL/FCL documentation and Lazarus Wiki. ' +
    'Returns matching documentation entries with snippets and URLs.'
  ).Register;

  TListProjectsTool.Create(
    'list_projects',
    'Scan a directory for Lazarus project files (.lpi, .lpr). ' +
    'Returns a list of discovered projects with names, paths, and types.'
  ).Register;
end;

procedure TLazFPCMCPApplication.DoRun;
begin
  RegisterTools;
  inherited DoRun;
end;

var
  Application: TLazFPCMCPApplication;

begin
  Application := TLazFPCMCPApplication.Create(nil);
  Application.Title := 'lazfpc-mcp';
  Application.Initialize;
  Application.Run;
  Application.Free;
end.
