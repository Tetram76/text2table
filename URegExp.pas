unit URegExp;

interface

uses
  SysUtils, Classes, JclPCRE;

type
  ERegExException = Exception;

  TRegExp = class
  strict private
    FLastFoundPos: Integer;
    FSearchString: string;
  private
    FRegEx: TJclRegEx;
    function GetCaptureName(Index: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;

    function CaptureCount: Integer;

    procedure Prepare(const RegEx: string);

    procedure BeginSearch(const s: string);
    function Next: Boolean;
    function Match: Boolean;

    function GetCaptureByName(const Group: string): string;
    property CaptureNames[Index: Integer]: string read GetCaptureName;
  end;

implementation

{ TRegExp }

procedure TRegExp.BeginSearch(const s: string);
begin
  FSearchString := s;
  FLastFoundPos := 1;
end;

function TRegExp.CaptureCount: Integer;
begin
  // après la compilation, CaptureNameCount et CaptureCount sont égaux
  // mais après une recherche, CaptureCount = CaptureNameCount + 1
  // Captures[0] correspond à ???
  Result := FRegEx.CaptureNameCount;
end;

constructor TRegExp.Create;
begin
  FRegEx := TJclRegEx.Create;
  FRegEx.Options := FRegEx.Options + [roDupNames];
end;

destructor TRegExp.Destroy;
begin
  FRegEx.Free;
  inherited;
end;

function TRegExp.GetCaptureByName(const Group: string): string;
var
  i: Integer;
begin
  i := FRegEx.IndexOfName(Group);
  if (i > 0) and (i < FRegEx.CaptureCount) then
    Result := FRegEx.Captures[i]
  else
    Result := '';
end;

function TRegExp.GetCaptureName(Index: Integer): string;
begin
  Result := FRegEx.CaptureNames[Index];
end;

function TRegExp.Match: Boolean;
begin
  Result := FRegEx.Match(FSearchString, FLastFoundPos);
end;

function TRegExp.Next: Boolean;
begin
  Result := Match;
  FLastFoundPos := FRegEx.CaptureRanges[0].LastPos + 1;
end;

procedure TRegExp.Prepare(const RegEx: string);
begin
  if not FRegEx.Compile(RegEx, True) then
    raise ERegExException.Create('Cannot compile regex: ' + FRegEx.ErrorMessage);
  if FRegEx.CaptureCount = 0 then
    raise ERegExException.Create('At least one capturing group must be defined');
  if FRegEx.CaptureCount <> FRegEx.CaptureNameCount then
    raise ERegExException.Create('All capturing group must be named');
end;

end.
