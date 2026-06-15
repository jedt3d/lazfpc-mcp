unit mcputils.errorparser;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpjson;

type
  TBuildError = record
    FilePath: string;
    Line: Integer;
    Column: Integer;
    Message: string;
    ErrorType: string;
    Severity: string;
    procedure FromLine(const ALine: string);
  end;
  TBuildErrorArray = array of TBuildError;

function ParseCompilerOutput(const AOutput: string): TBuildErrorArray;
function ErrorsToJSON(const AErrors: TBuildErrorArray): TJSONArray;

implementation

{ TBuildError }

procedure TBuildError.FromLine(const ALine: string);
var
  lLine: string;
  lParenPos, lCommaPos, lClosePos, lColonPos: Integer;
  lTypeEnd: Integer;
  i: Integer;
begin
  FilePath := '';
  Line := 0;
  Column := 0;
  Message := '';
  ErrorType := '';
  Severity := '';

  lLine := Trim(ALine);
  if lLine = '' then
    Exit;

  // Find the pattern: filepath(line,col) Type: message
  // Look for the pattern from the end to handle paths with parentheses
  lClosePos := 0;
  lParenPos := 0;

  // Find last ')' followed by space and a known type word
  lClosePos := Pos(') ', lLine);
  if lClosePos = 0 then
    Exit; // Not an error line

  // Find matching '(' before the ')'
  lParenPos := 0;
  for i := lClosePos - 1 downto 1 do
  begin
    if lLine[i] = '(' then
    begin
      lParenPos := i;
      Break;
    end;
  end;

  if lParenPos = 0 then
    Exit;

  // Extract filepath (everything before '(')
  FilePath := Trim(Copy(lLine, 1, lParenPos - 1));

  // Parse line,col between parentheses
  lCommaPos := Pos(',', lLine, lParenPos);
  if lCommaPos > 0 then
  begin
    Line := StrToIntDef(Trim(Copy(lLine, lParenPos + 1, lCommaPos - lParenPos - 1)), 0);
    Column := StrToIntDef(Trim(Copy(lLine, lCommaPos + 1, lClosePos - lCommaPos - 1)), 0);
  end
  else
  begin
    Line := StrToIntDef(Trim(Copy(lLine, lParenPos + 1, lClosePos - lParenPos - 1)), 0);
  end;

  // Find the type (word between ') ' and ':')
  lColonPos := Pos(': ', lLine, lClosePos);
  if lColonPos = 0 then
    lColonPos := Pos(':', lLine, lClosePos);

  if lColonPos > 0 then
  begin
    ErrorType := Trim(Copy(lLine, lClosePos + 2, lColonPos - lClosePos - 2));
    Message := Trim(Copy(lLine, lColonPos + 1, MaxInt));
  end
  else
  begin
    ErrorType := Trim(Copy(lLine, lClosePos + 2, MaxInt));
    Message := '';
  end;

  // Set severity
  if (Pos('Error', ErrorType) > 0) or (Pos('Fatal', ErrorType) > 0) then
    Severity := 'error'
  else if Pos('Warning', ErrorType) > 0 then
    Severity := 'warning'
  else if Pos('Note', ErrorType) > 0 then
    Severity := 'note'
  else if Pos('Hint', ErrorType) > 0 then
    Severity := 'hint'
  else
    Severity := 'info';
end;

function ParseCompilerOutput(const AOutput: string): TBuildErrorArray;
var
  lLines: TStringList;
  lErr: TBuildError;
  I: Integer;
begin
  SetLength(Result, 0);
  lLines := TStringList.Create;
  try
    lLines.Text := AOutput;
    for I := 0 to lLines.Count - 1 do
    begin
      lErr.FromLine(lLines[I]);
      if lErr.ErrorType <> '' then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := lErr;
      end;
    end;
  finally
    lLines.Free;
  end;
end;

function ErrorsToJSON(const AErrors: TBuildErrorArray): TJSONArray;
var
  lObj: TJSONObject;
  lErr: TBuildError;
begin
  Result := TJSONArray.Create;
  for lErr in AErrors do
  begin
    lObj := TJSONObject.Create;
    lObj.Add('file', lErr.FilePath);
    lObj.Add('line', lErr.Line);
    lObj.Add('column', lErr.Column);
    lObj.Add('type', lErr.ErrorType);
    lObj.Add('severity', lErr.Severity);
    lObj.Add('message', lErr.Message);
    Result.Add(lObj);
  end;
end;

end.
