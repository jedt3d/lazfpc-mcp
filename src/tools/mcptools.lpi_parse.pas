unit mcptools.lpi_parse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TParseLPITool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  DOM, XMLRead;

function GetChildText(ANode: TDOMNode; const AName: string): string;
var
  lChild: TDOMNode;
begin
  Result := '';
  if ANode = nil then
    Exit;
  lChild := ANode.FindNode(AName);
  if lChild <> nil then
    Result := Trim(lChild.TextContent);
end;

function NavigatePath(ARoot: TDOMNode; const APath: string): TDOMNode;
var
  lWork: string;
  lDotPos: Integer;
  lPart: string;
begin
  Result := ARoot;
  lWork := APath;
  while (Result <> nil) and (lWork <> '') do
  begin
    lDotPos := Pos('.', lWork);
    if lDotPos > 0 then
    begin
      lPart := Copy(lWork, 1, lDotPos - 1);
      lWork := Copy(lWork, lDotPos + 1, MaxInt);
    end
    else
    begin
      lPart := lWork;
      lWork := '';
    end;
    Result := Result.FindNode(lPart);
  end;
end;

{ TParseLPITool }

constructor TParseLPITool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('lpi_path',
    TJSONObject.Create(['type', 'string']), True);
end;

procedure TParseLPITool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lLpiPath: string;
  lDoc: TXMLDocument;
  lRoot, lProjOpts, lCompOpts, lNode, lUnitsNode, lUnitNode: TDOMNode;
  lUnits: TJSONArray;
  lUnitFile: string;
  lI: Integer;
  lUnitStr: string;
  lCompilerOpts, lSearchPaths: TJSONObject;
begin
  lLpiPath := aInput.Get('lpi_path', '');

  if lLpiPath = '' then
    raise EMCPException.Create('lpi_path is required');

  if not FileExists(lLpiPath) then
    raise EMCPException.CreateFmt('File not found: %s', [lLpiPath]);

  ReadXMLFile(lDoc, lLpiPath);
  try
    lRoot := lDoc.DocumentElement; // <CONFIG>

    aResult.Add('lpi_path', lLpiPath);

    // Project name from filename
    aResult.Add('project_name', ChangeFileExt(ExtractFileName(lLpiPath), ''));

    // Project title from XML
    lProjOpts := NavigatePath(lRoot, 'ProjectOptions.General');
    aResult.Add('title', GetChildText(lProjOpts, 'Title'));

    // Units
    lUnits := TJSONArray.Create;
    lUnitsNode := NavigatePath(lRoot, 'ProjectOptions.Units');
    if lUnitsNode <> nil then
    begin
      lI := 0;
      while True do
      begin
        lUnitNode := lUnitsNode.FindNode('Unit' + IntToStr(lI));
        if lUnitNode = nil then
          Break;
        lUnitFile := GetChildText(lUnitNode, 'Filename');
        if lUnitFile <> '' then
        begin
          lUnitStr := ExtractFileName(lUnitFile);
          lUnits.Add(lUnitStr);
        end;
        Inc(lI);
      end;
    end;
    aResult.Add('units', lUnits);
    aResult.Add('unit_count', lUnits.Count);

    // Compiler options
    lCompOpts := NavigatePath(lRoot, 'CompilerOptions');
    lCompilerOpts := TJSONObject.Create;

    lNode := NavigatePath(lCompOpts, 'CodeGeneration');
    if lNode <> nil then
    begin
      lCompilerOpts.Add('target_os', GetChildText(lNode, 'TargetOS'));
      lCompilerOpts.Add('target_cpu', GetChildText(lNode, 'TargetCPU'));
      lCompilerOpts.Add('optimization', GetChildText(lNode, 'OptimizationLevel'));
    end;

    aResult.Add('compiler_options', lCompilerOpts);

    // Search paths
    lNode := NavigatePath(lCompOpts, 'SearchPaths');
    lSearchPaths := TJSONObject.Create;
    if lNode <> nil then
    begin
      lSearchPaths.Add('unit_files', GetChildText(lNode, 'OtherUnitFiles'));
      lSearchPaths.Add('include_files', GetChildText(lNode, 'IncludeFiles'));
      lSearchPaths.Add('libraries', GetChildText(lNode, 'Libraries'));
      lSearchPaths.Add('object_files', GetChildText(lNode, 'OtherUnitFiles'));
    end;
    aResult.Add('search_paths', lSearchPaths);

  finally
    lDoc.Free;
  end;
end;

end.
