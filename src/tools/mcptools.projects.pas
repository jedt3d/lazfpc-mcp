unit mcptools.projects;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TListProjectsTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  DOM, XMLRead;

const
  SkipDirs: array[0..8] of string = (
    '.', '..', 'lib', 'backup', '__history', '.git', '.svn',
    'node_modules', 'dist'
  );

function ShouldSkipDir(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(SkipDirs) do
    if SameText(AName, SkipDirs[I]) then
    begin
      Result := True;
      Exit;
    end;
  // Also skip lib_* pattern
  if Copy(AName, 1, 4) = 'lib_' then
    Result := True;
end;

function GetProjectTitleFromLPI(const ALpiPath: string): string;
var
  lDoc: TXMLDocument;
  lRoot, lNode: TDOMNode;
begin
  Result := '';
  try
    ReadXMLFile(lDoc, ALpiPath);
    try
      lRoot := lDoc.DocumentElement;
      if lRoot <> nil then
      begin
        lNode := lRoot.FindNode('ProjectOptions');
        if lNode <> nil then
          lNode := lNode.FindNode('General');
        if lNode <> nil then
          lNode := lNode.FindNode('Title');
        if lNode <> nil then
          Result := Trim(lNode.TextContent);
      end;
    finally
      lDoc.Free;
    end;
  except
    // Ignore XML parse errors
  end;
end;

procedure ScanDir(const ADir: string; ARecursive: Boolean; AResults: TJSONArray);
var
  lSR: TSearchRec;
  lPath, lExt, lBaseName, lProjName, lTitle: string;
  lObj: TJSONObject;
  lLpiExists: Boolean;
begin
  if FindFirst(ADir + '/*', faAnyFile, lSR) = 0 then
  begin
    try
      repeat
        if (lSR.Name = '.') or (lSR.Name = '..') then
          Continue;

        lPath := ADir + '/' + lSR.Name;

        if (lSR.Attr and faDirectory) <> 0 then
        begin
          if ARecursive and not ShouldSkipDir(lSR.Name) then
            ScanDir(lPath, ARecursive, AResults);
        end
        else
        begin
          lExt := LowerCase(ExtractFileExt(lSR.Name));

          if (lExt = '.lpi') or (lExt = '.lpr') or (lExt = '.lpk') then
          begin
            lBaseName := ChangeFileExt(lSR.Name, '');
            lProjName := lBaseName;

            lObj := TJSONObject.Create;
            lObj.Add('name', lProjName);
            lObj.Add('path', lPath);

            if lExt = '.lpk' then
            begin
              lObj.Add('type', 'package');
            end
            else
            begin
              lObj.Add('type', 'application');

              // Check if corresponding .lpr exists
              if lExt = '.lpi' then
              begin
                if FileExists(ADir + '/' + lBaseName + '.lpr') then
                  lObj.Add('main_source', lBaseName + '.lpr');
              end;

              // Try to get title from .lpi
              if lExt = '.lpi' then
              begin
                lTitle := GetProjectTitleFromLPI(lPath);
                if lTitle <> '' then
                  lObj.Add('title', lTitle);
              end;
            end;

            AResults.Add(lObj);
          end;
        end;
      until FindNext(lSR) <> 0;
    finally
      FindClose(lSR);
    end;
  end;
end;

{ TListProjectsTool }

constructor TListProjectsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('directory_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('recursive',
    TJSONObject.Create(['type', 'boolean',
      'description', 'Search subdirectories recursively (default true)']), False);
end;

procedure TListProjectsTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lDir: string;
  lRecursive: Boolean;
  lProjects: TJSONArray;
begin
  lDir := aInput.Get('directory_path', '');
  lRecursive := aInput.Get('recursive', True);

  if lDir = '' then
    raise EMCPException.Create('directory_path is required');

  if not DirectoryExists(lDir) then
    raise EMCPException.CreateFmt('Directory not found: %s', [lDir]);

  lProjects := TJSONArray.Create;
  ScanDir(lDir, lRecursive, lProjects);

  aResult.Add('directory', lDir);
  aResult.Add('recursive', lRecursive);
  aResult.Add('projects', lProjects);
  aResult.Add('project_count', lProjects.Count);
end;

end.
