unit mcptools.lfm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TParseLFMTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  LfmParser;

function NodeToJSON(ANode: TLayoutNode; AMaxDepth, ACurrentDepth: Integer): TJSONObject;
var
  lProps: TJSONObject;
  lLayout: TJSONObject;
  lChildren: TJSONArray;
  I: Integer;
  lLine, lName, lVal: string;
  lEqPos: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('name', ANode.Name);
  Result.Add('class', ANode.ControlClassName);
  Result.Add('keyword', ANode.HeaderKeyword);

  // Properties
  lProps := TJSONObject.Create;
  for I := 0 to ANode.Properties.Count - 1 do
  begin
    lLine := Trim(ANode.Properties[I]);
    lEqPos := Pos('=', lLine);
    if lEqPos > 0 then
    begin
      lName := Trim(Copy(lLine, 1, lEqPos - 1));
      lVal := Trim(Copy(lLine, lEqPos + 1, MaxInt));
      lProps.Add(lName, lVal);
    end;
  end;
  Result.Add('properties', lProps);

  // Layout summary
  lLayout := TJSONObject.Create;
  if ANode.HasLeft then
    lLayout.Add('left', ANode.Left);
  if ANode.HasTop then
    lLayout.Add('top', ANode.Top);
  if ANode.HasWidth then
    lLayout.Add('width', ANode.Width);
  if ANode.HasHeight then
    lLayout.Add('height', ANode.Height);
  if ANode.Align <> '' then
    lLayout.Add('align', ANode.Align);
  if ANode.Anchors <> '' then
    lLayout.Add('anchors', ANode.Anchors);
  Result.Add('layout', lLayout);

  // Children (respect max_depth)
  if (AMaxDepth = 0) or (ACurrentDepth < AMaxDepth) then
  begin
    lChildren := TJSONArray.Create;
    for I := 0 to ANode.Children.Count - 1 do
    begin
      lChildren.Add(NodeToJSON(ANode.Children[I], AMaxDepth, ACurrentDepth + 1));
    end;
    Result.Add('children', lChildren);
  end;
end;

{ TParseLFMTool }

constructor TParseLFMTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('lfm_path',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('max_depth',
    TJSONObject.Create(['type', 'integer',
      'description', 'Max depth for component tree (0 = unlimited)']), False);
end;

procedure TParseLFMTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lLfmPath: string;
  lMaxDepth: Integer;
  lTree: TLfmTree;
begin
  lLfmPath := aInput.Get('lfm_path', '');
  lMaxDepth := aInput.Get('max_depth', 0);

  if lLfmPath = '' then
    raise EMCPException.Create('lfm_path is required');

  if not FileExists(lLfmPath) then
    raise EMCPException.CreateFmt('File not found: %s', [lLfmPath]);

  lTree := TLfmTree.Create;
  try
    lTree.LoadFromFile(lLfmPath);
    aResult.Add('lfm_path', lLfmPath);
    if lTree.RootNode <> nil then
      aResult.Add('root', NodeToJSON(lTree.RootNode, lMaxDepth, 0))
    else
      aResult.Add('root', TJSONObject.Create);
  finally
    lTree.Free;
  end;
end;

end.
