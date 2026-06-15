unit mcptools.docs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, mcp.tools;

type
  TSearchFPCHelpTool = class(TMCPTool)
  public
    constructor create(const aName: string; const aDescription: string); override;
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

uses
  StrUtils;

const
  FPCSrcRoot = '/Users/worajedt/Lazarus/fpc-src';
  MaxFilesToScan = 500;

function DetectMatchType(const ALine, AQuery: string): string;
var
  lUpperLine: string;
begin
  Result := 'reference';
  lUpperLine := ALine;
  if (Pos('function ' + AQuery, lUpperLine) > 0) or
     (Pos('procedure ' + AQuery, lUpperLine) > 0) then
    Result := 'method'
  else if (Pos(AQuery + ' = class', lUpperLine) > 0) or
          (Pos(AQuery + ' = class(', lUpperLine) > 0) then
    Result := 'class_declaration'
  else if Pos(AQuery + ' = record', lUpperLine) > 0 then
    Result := 'record_declaration'
  else if Pos(AQuery + ' = type', lUpperLine) > 0 then
    Result := 'type_alias'
  else if Pos(AQuery + ' = interface', lUpperLine) > 0 then
    Result := 'interface_declaration'
  else if Pos('const' + #9 + AQuery, lUpperLine) > 0 then
    Result := 'constant'
  else if Pos('resourcestring', lUpperLine) > 0 then
    Result := 'string_resource';
end;

procedure ScanFile(const AFilePath, AQuery: string; AResults: TJSONArray; AMaxResults: Integer; var ACount: Integer);
var
  lLines: TStringList;
  I: Integer;
  lLine, lTrimmed: string;
  lMatchType: string;
  lObj: TJSONObject;
  lFound: Integer;
begin
  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(AFilePath);
    except
      Exit;
    end;

    for I := 0 to lLines.Count - 1 do
    begin
      lLine := lLines[I];
      lFound := Pos(UpperCase(AQuery), UpperCase(lLine));
      if lFound > 0 then
      begin
        lTrimmed := Trim(lLine);
        if lTrimmed = '' then
          Continue;

        lMatchType := DetectMatchType(lLine, AQuery);

        lObj := TJSONObject.Create;
        lObj.Add('file', StringReplace(AFilePath, FPCSrcRoot + '/', '', []));
        lObj.Add('line', I + 1);
        lObj.Add('context', lTrimmed);
        lObj.Add('match_type', lMatchType);
        AResults.Add(lObj);

        Inc(ACount);
        if ACount >= AMaxResults then
          Exit;
      end;
    end;
  finally
    lLines.Free;
  end;
end;

procedure ScanDir(const ADir, AQuery: string; AResults: TJSONArray; AMaxResults: Integer;
  var ACount, AFilesScanned: Integer; var AStop: Boolean);
var
  lSR: TSearchRec;
  lPath: string;
begin
  if AStop then
    Exit;

  if FindFirst(ADir + '/*', faAnyFile, lSR) = 0 then
  begin
    try
      repeat
        if (lSR.Name = '.') or (lSR.Name = '..') then
          Continue;

        lPath := ADir + '/' + lSR.Name;

        if (lSR.Attr and faDirectory) <> 0 then
        begin
          // Skip unwanted directories
          if (lSR.Name = 'tests') or (lSR.Name = 'examples') or
             (lSR.Name = 'test') or (lSR.Name = '.git') or
             (lSR.Name = '.svn') or (lSR.Name = 'backup') then
            Continue;
          ScanDir(lPath, AQuery, AResults, AMaxResults, ACount, AFilesScanned, AStop);
        end
        else
        begin
          // Only search Pascal source files
          if (ExtractFileExt(lSR.Name) = '.pas') or
             (ExtractFileExt(lSR.Name) = '.pp') or
             (ExtractFileExt(lSR.Name) = '.inc') then
          begin
            ScanFile(lPath, AQuery, AResults, AMaxResults, ACount);
            Inc(AFilesScanned);
            if (ACount >= AMaxResults) or (AFilesScanned >= MaxFilesToScan) then
            begin
              AStop := True;
              Break;
            end;
          end;
        end;
      until FindNext(lSR) <> 0;
    finally
      FindClose(lSR);
    end;
  end;
end;

{ TSearchFPCHelpTool }

constructor TSearchFPCHelpTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('query',
    TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('max_results',
    TJSONObject.Create(['type', 'integer',
      'description', 'Maximum number of results to return (default 10)']), False);
end;

procedure TSearchFPCHelpTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  lQuery: string;
  lMaxResults: Integer;
  lResults: TJSONArray;
  lCount, lFilesScanned: Integer;
  lStop: Boolean;
  lDirs: array[0..2] of string;
  I: Integer;
begin
  lQuery := aInput.Get('query', '');
  lMaxResults := aInput.Get('max_results', 10);

  if lQuery = '' then
    raise EMCPException.Create('query is required');

  lResults := TJSONArray.Create;
  lCount := 0;
  lFilesScanned := 0;
  lStop := False;

  lDirs[0] := FPCSrcRoot + '/rtl';
  lDirs[1] := FPCSrcRoot + '/fcl';
  lDirs[2] := FPCSrcRoot + '/packages';

  for I := 0 to 2 do
  begin
    if DirectoryExists(lDirs[I]) then
      ScanDir(lDirs[I], lQuery, lResults, lMaxResults, lCount, lFilesScanned, lStop);
    if lStop then
      Break;
  end;

  aResult.Add('query', lQuery);
  aResult.Add('results', lResults);
  aResult.Add('total_matches', lCount);
  aResult.Add('files_scanned', lFilesScanned);
  aResult.Add('truncated', lCount >= lMaxResults);
end;

end.
