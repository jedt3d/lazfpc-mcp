unit LfmParser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FGL;

type
  TLayoutNode = class;
  TLayoutNodeList = specialize TFPGObjectList<TLayoutNode>;

  TLayoutNode = class
  private
    function GetPropertyIndex(const APropName: string): Integer;
    function GetLeadingSpaces(const ALine: string): string;
  public
    Name: string;
    ControlClassName: string;
    HeaderKeyword: string; // 'object', 'inherited', or 'inline'
    
    // Quick layout access fields
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    HasLeft, HasTop, HasWidth, HasHeight: Boolean;
    
    Align: string;       // e.g., 'alTop'
    Anchors: string;     // e.g., '[akLeft, akTop]'
    
    // Grid child cells
    GridRow: Integer;
    GridColumn: Integer;
    GridRowSpan: Integer;
    GridColSpan: Integer;
    HasGridRow, HasGridColumn, HasGridRowSpan, HasGridColSpan: Boolean;
    
    // Unified ordered property list (all properties in original order)
    Properties: TStringList;
    
    Children: TLayoutNodeList;
    Parent: TLayoutNode;
    
    constructor Create;
    destructor Destroy; override;
    
    procedure SetProperty(const APropName, APropVal: string);
    procedure DeleteProperty(const APropName: string);
    procedure AddPropertyLine(const ALine: string);
    procedure ParseLayoutField(const APropName, APropVal: string);
  end;

  TLfmTree = class
  private
    procedure SerializeNode(ANode: TLayoutNode; AStrings: TStrings; ADepth: Integer);
  public
    RootNode: TLayoutNode;
    
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadFromFile(const AFilename: string);
    procedure SaveToFile(const AFilename: string);
    procedure LoadFromStrings(ALines: TStrings);
    procedure SaveToStrings(ALines: TStrings);
  end;

implementation

{ TLayoutNode }

constructor TLayoutNode.Create;
begin
  Properties := TStringList.Create;
  Children := TLayoutNodeList.Create(True);
  
  HasLeft := False;
  HasTop := False;
  HasWidth := False;
  HasHeight := False;
  HasGridRow := False;
  HasGridColumn := False;
  HasGridRowSpan := False;
  HasGridColSpan := False;
  
  Left := 0;
  Top := 0;
  Width := 0;
  Height := 0;
  GridRow := 0;
  GridColumn := 0;
  GridRowSpan := 1;
  GridColSpan := 1;
end;

destructor TLayoutNode.Destroy;
begin
  Properties.Free;
  Children.Free;
  inherited Destroy;
end;

function TLayoutNode.GetLeadingSpaces(const ALine: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ALine) do
  begin
    if (ALine[I] = ' ') or (ALine[I] = #9) then
      Result := Result + ALine[I]
    else
      Break;
  end;
end;

function TLayoutNode.GetPropertyIndex(const APropName: string): Integer;
var
  I: Integer;
  Line: string;
  EqPos: Integer;
  NamePart: string;
begin
  Result := -1;
  for I := 0 to Properties.Count - 1 do
  begin
    Line := Trim(Properties[I]);
    EqPos := Pos('=', Line);
    if EqPos > 1 then
    begin
      NamePart := Trim(Copy(Line, 1, EqPos - 1));
      if NamePart = APropName then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;
end;

procedure TLayoutNode.SetProperty(const APropName, APropVal: string);
var
  Idx: Integer;
  NewLine: string;
  Indent: string;
begin
  Idx := GetPropertyIndex(APropName);
  if Idx >= 0 then
  begin
    NewLine := GetLeadingSpaces(Properties[Idx]) + APropName + ' = ' + APropVal;
    Properties[Idx] := NewLine;
  end
  else
  begin
    Indent := '      ';
    if Parent <> nil then Indent := '    ';
    NewLine := Indent + APropName + ' = ' + APropVal;
    Properties.Add(NewLine);
  end;
  
  ParseLayoutField(APropName, APropVal);
end;

procedure TLayoutNode.DeleteProperty(const APropName: string);
var
  Idx: Integer;
begin
  Idx := GetPropertyIndex(APropName);
  if Idx >= 0 then
  begin
    Properties.Delete(Idx);
  end;
  
  if APropName = 'Left' then HasLeft := False
  else if APropName = 'Top' then HasTop := False
  else if APropName = 'Width' then HasWidth := False
  else if APropName = 'Height' then HasHeight := False
  else if APropName = 'Align' then Align := ''
  else if APropName = 'Anchors' then Anchors := ''
  else if APropName = 'Row' then HasGridRow := False
  else if APropName = 'Column' then HasGridColumn := False
  else if APropName = 'RowSpan' then HasGridRowSpan := False
  else if APropName = 'ColSpan' then HasGridColSpan := False;
end;

procedure TLayoutNode.AddPropertyLine(const ALine: string);
begin
  Properties.Add(ALine);
end;

procedure TLayoutNode.ParseLayoutField(const APropName, APropVal: string);
begin
  if APropName = 'Left' then
  begin
    Left := StrToIntDef(APropVal, 0);
    HasLeft := True;
  end
  else if APropName = 'Top' then
  begin
    Top := StrToIntDef(APropVal, 0);
    HasTop := True;
  end
  else if APropName = 'Width' then
  begin
    Width := StrToIntDef(APropVal, 0);
    HasWidth := True;
  end
  else if APropName = 'Height' then
  begin
    Height := StrToIntDef(APropVal, 0);
    HasHeight := True;
  end
  else if APropName = 'Align' then
  begin
    Align := APropVal;
  end
  else if APropName = 'Anchors' then
  begin
    Anchors := APropVal;
  end
  else if APropName = 'Row' then
  begin
    GridRow := StrToIntDef(APropVal, 0);
    HasGridRow := True;
  end
  else if APropName = 'Column' then
  begin
    GridColumn := StrToIntDef(APropVal, 0);
    HasGridColumn := True;
  end
  else if APropName = 'RowSpan' then
  begin
    GridRowSpan := StrToIntDef(APropVal, 1);
    HasGridRowSpan := True;
  end
  else if APropName = 'ColSpan' then
  begin
    GridColSpan := StrToIntDef(APropVal, 1);
    HasGridColSpan := True;
  end;
end;

{ TLfmTree }

constructor TLfmTree.Create;
begin
  RootNode := nil;
end;

destructor TLfmTree.Destroy;
begin
  if RootNode <> nil then
    RootNode.Free;
  inherited Destroy;
end;

procedure TLfmTree.LoadFromFile(const AFilename: string);
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.LoadFromFile(AFilename);
    LoadFromStrings(List);
  finally
    List.Free;
  end;
end;

procedure TLfmTree.SaveToFile(const AFilename: string);
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    SaveToStrings(List);
    List.SaveToFile(AFilename);
  finally
    List.Free;
  end;
end;

procedure TLfmTree.LoadFromStrings(ALines: TStrings);
var
  I: Integer;
  Line: string;
  Trimmed: string;
  ActiveNode: TLayoutNode;
  NodeStack: TFPList;
  InMultiLineBlock: Boolean;
  MultiLineEndChar: Char;
  MultiLineProperty: string;
  
  procedure ParseHeader(const ALine: string; out AKeyword, AName, AClass: string);
  var
    ColPos, SpacePos: Integer;
  begin
    AKeyword := '';
    AName := '';
    AClass := '';
    
    SpacePos := Pos(' ', ALine);
    if SpacePos > 0 then
    begin
      AKeyword := Copy(ALine, 1, SpacePos - 1);
      ColPos := Pos(':', ALine);
      if ColPos > 0 then
      begin
        AName := Trim(Copy(ALine, SpacePos + 1, ColPos - SpacePos - 1));
        AClass := Trim(Copy(ALine, ColPos + 1, Length(ALine)));
      end
      else
      begin
        AName := Trim(Copy(ALine, SpacePos + 1, Length(ALine)));
      end;
    end;
  end;

var
  PropName, PropVal: string;
  NewNode: TLayoutNode;
  SpacePos: Integer;
begin
  if RootNode <> nil then
  begin
    RootNode.Free;
    RootNode := nil;
  end;
  
  ActiveNode := nil;
  MultiLineEndChar := #0;
  InMultiLineBlock := False;
  MultiLineProperty := '';
  
  NodeStack := TFPList.Create;
  try
    I := 0;
    while I < ALines.Count do
    begin
      Line := ALines[I];
      Trimmed := Trim(Line);
      
      if Trimmed = '' then
      begin
        Inc(I);
        Continue;
      end;
      
      if InMultiLineBlock then
      begin
        ActiveNode.AddPropertyLine(Line);
        if (Length(Trimmed) > 0) and (Trimmed[Length(Trimmed)] = MultiLineEndChar) then
        begin
          InMultiLineBlock := False;
        end;
        Inc(I);
        Continue;
      end;
      
      if (Pos('object ', Trimmed) = 1) or 
         (Pos('inherited ', Trimmed) = 1) or 
         (Pos('inline ', Trimmed) = 1) then
      begin
        NewNode := TLayoutNode.Create;
        ParseHeader(Trimmed, NewNode.HeaderKeyword, NewNode.Name, NewNode.ControlClassName);
        
        if ActiveNode = nil then
        begin
          RootNode := NewNode;
        end
        else
        begin
          NewNode.Parent := ActiveNode;
          ActiveNode.Children.Add(NewNode);
        end;
        
        ActiveNode := NewNode;
        NodeStack.Add(ActiveNode);
        Inc(I);
        Continue;
      end;
      
      if Trimmed = 'end' then
      begin
        if NodeStack.Count > 0 then
        begin
          NodeStack.Delete(NodeStack.Count - 1);
          if NodeStack.Count > 0 then
            ActiveNode := TLayoutNode(NodeStack[NodeStack.Count - 1])
          else
            ActiveNode := nil;
        end;
        Inc(I);
        Continue;
      end;
      
      if ActiveNode <> nil then
      begin
        SpacePos := Pos('=', Trimmed);
        if (SpacePos > 0) and (SpacePos < Length(Trimmed)) then
        begin
          PropName := Trim(Copy(Trimmed, 1, SpacePos - 1));
          PropVal := Trim(Copy(Trimmed, SpacePos + 1, Length(Trimmed)));
          
          if (Length(PropVal) > 0) and 
             ((PropVal[1] = '(') or (PropVal[1] = '{') or (PropVal[1] = '<')) then
          begin
            InMultiLineBlock := True;
            if PropVal[1] = '(' then MultiLineEndChar := ')'
            else if PropVal[1] = '{' then MultiLineEndChar := '}'
            else MultiLineEndChar := '>';
            
            MultiLineProperty := PropName;
            ActiveNode.AddPropertyLine(Line);
            
            if (Length(PropVal) > 1) and (PropVal[Length(PropVal)] = MultiLineEndChar) then
            begin
              InMultiLineBlock := False;
            end;
          end
          else
          begin
            ActiveNode.AddPropertyLine(Line);
            ActiveNode.ParseLayoutField(PropName, PropVal);
          end;
        end
        else
        begin
          ActiveNode.AddPropertyLine(Line);
        end;
      end;
      
      Inc(I);
    end;
  finally
    NodeStack.Free;
  end;
end;

procedure TLfmTree.SerializeNode(ANode: TLayoutNode; AStrings: TStrings; ADepth: Integer);
var
  Indent: string;
  I: Integer;
  Child: TLayoutNode;
begin
  Indent := StringOfChar(' ', ADepth * 2);
  
  // Write the object header
  AStrings.Add(Indent + ANode.HeaderKeyword + ' ' + ANode.Name + ': ' + ANode.ControlClassName);
  
  // Write all properties in their exact original order
  for I := 0 to ANode.Properties.Count - 1 do
  begin
    AStrings.Add(ANode.Properties[I]);
  end;
  
  // Recursively serialize nested children
  for I := 0 to ANode.Children.Count - 1 do
  begin
    Child := ANode.Children[I];
    SerializeNode(Child, AStrings, ADepth + 1);
  end;
  
  // Write the block end
  AStrings.Add(Indent + 'end');
end;

procedure TLfmTree.SaveToStrings(ALines: TStrings);
begin
  if RootNode <> nil then
    SerializeNode(RootNode, ALines, 0);
end;

end.
