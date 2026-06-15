unit mcputils.errorparser;

{$mode objfpc}{$H+}

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
    procedure FromLine(const ALine: string);
  end;
  TBuildErrorArray = array of TBuildError;

function ParseCompilerOutput(const AOutput: string): TBuildErrorArray;
function ErrorsToJSON(const AErrors: TBuildErrorArray): TJSONArray;

implementation

{ TBuildError }

procedure TBuildError.FromLine(const ALine: string);
begin
  Message := ALine;
  FilePath := '';
  Line := 0;
  Column := 0;
  ErrorType := '';
end;

function ParseCompilerOutput(const AOutput: string): TBuildErrorArray;
begin
  SetLength(Result, 0);
  // TODO: Parse FPC error lines like "file.pas(123,45) Error: message"
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
    lObj.Add('message', lErr.Message);
    lObj.Add('type', lErr.ErrorType);
    Result.Add(lObj);
  end;
end;

end.
