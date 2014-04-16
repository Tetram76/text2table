unit UCommandLineParameters;

interface

uses
  SysUtils, Classes, Generics.Collections;

type
  ECommandLineError = Exception;

  TCommandLineParameter = class;

  TOnParameterEventReference = reference to procedure(Sender: TObject; const Value: string);
  TOnParameterEvent = procedure(Sender: TObject; const Value: string) of object;

  TParameterType = (ptFlag, ptSwitch, ptParameter);

  TCommandLineParameter = class
  private
    FPresent: Boolean;
    FOnParameterEvent: TOnParameterEvent;
    FOnParameterEventReference: TOnParameterEventReference;
    FShortParameter: string;
    FLongParameter: string;
    FParameterType: TParameterType;
    FMandatory: Boolean;
    FShortDescription: string;
    FLongDescription: string;
    procedure DoOnParameter(const Value: string);
    procedure SetOnParameterEvent(const Value: TOnParameterEvent);
    procedure SetOnParameterEventReference(const Value: TOnParameterEventReference);
  public
    function ToShortSyntax: string;
    function ToLongSyntax: string;

    property ShortParameter: string read FShortParameter;
    property LongParameter: string read FLongParameter;
    property Mandatory: Boolean read FMandatory;
    property ParameterType: TParameterType read FParameterType;

    property ShortDescription: string read FShortDescription;
    property LongDescription: string read FLongDescription;

    property OnParameterReference: TOnParameterEventReference read FOnParameterEventReference;
    property OnParameter: TOnParameterEvent read FOnParameterEvent;
  end;

  TCommandLineParameters = class
  private
    FParameters: TDictionary<string, TList<TCommandLineParameter>>;
    FMissing: TList<TCommandLineParameter>;
    function CreateParameter(const Short, Long, ShortDescription, Description: string; ParameterType: TParameterType; Mandatory: Boolean;
      Event: TOnParameterEvent; EventReference: TOnParameterEventReference): TCommandLineParameter;
    function FindParameter(const Value: string): TCommandLineParameter;
    function FindNextParameter(lastShownParameter: TCommandLineParameter): TCommandLineParameter;
    function GetFlag(const ShortParameter: string): Boolean;
    procedure AddParameters(const Section: string; Parameter: TCommandLineParameter);
  public
    constructor Create;
    destructor Destroy; override;

    function RegisterFlag(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent; const Section: string = '')
      : TCommandLineParameter; overload;
    function RegisterFlag(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference;
      const Section: string = ''): TCommandLineParameter; overload;
    function RegisterSwitch(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent; const Section: string = '')
      : TCommandLineParameter; overload;
    function RegisterSwitch(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference;
      const Section: string = ''): TCommandLineParameter; overload;
    function RegisterParameter(const ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent; const Section: string = '')
      : TCommandLineParameter; overload;
    function RegisterParameter(const ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference; const Section: string = '')
      : TCommandLineParameter; overload;

    function PrintSyntax: String;
    function PrintHelp: string;

    procedure Parse;
    function Validate: Boolean;

    property Missing: TList<TCommandLineParameter> read FMissing;
    property Flag[const ShortParameter: string]: Boolean read GetFlag;
  end;

implementation

{ TCommandLineParameter }

procedure TCommandLineParameter.DoOnParameter(const Value: string);
begin
  FPresent := True;
  if Assigned(FOnParameterEvent) then
    FOnParameterEvent(Self, Value);
  if Assigned(FOnParameterEventReference) then
    FOnParameterEventReference(Self, Value);
end;

procedure TCommandLineParameter.SetOnParameterEvent(const Value: TOnParameterEvent);
begin
  FOnParameterEvent := Value;
  FOnParameterEventReference := nil;
end;

procedure TCommandLineParameter.SetOnParameterEventReference(const Value: TOnParameterEventReference);
begin
  FOnParameterEventReference := Value;
  FOnParameterEvent := nil;
end;

procedure SplitString(const inlineString: string; List: TStrings; MaxWidth: Integer);

  procedure SplitLine(s: string);
  var
    p, pFirst: PChar;
    buf: string;
  begin
    pFirst := @s[1];
    p := pFirst;
    while (p^ <> #0) do
    begin
      while (p^ <> #0) and (p - pFirst < MaxWidth) do
        Inc(p);

      if (p^ <> #0) then
      begin
        while (p > pFirst) and (p^ <> #32) do
          Dec(p);
        Inc(p);
      end;

      SetLength(buf, p - pFirst);
      StrLCopy(@buf[1], pFirst, Length(buf));
      List.Add(buf);

      while (p^ <> #0) and (p^ = #32) do
        Inc(p);
      pFirst := p;
    end;
  end;

var
  sl: TStringList;
  s: string;
begin
  List.Clear;

  sl := TStringList.Create;
  try
    sl.Text := inlineString;
    for s in sl do
      SplitLine(s);
  finally
    sl.Free;
  end;
end;

function TCommandLineParameter.ToLongSyntax: string;
const
  tabParam = 8;
  tabDesc = 24;
  screenWidth = 80;

var
  s, L: string;
  i: Integer;
  sl: TStringList;
begin
  Result := StringOfChar(#32, tabParam);

  if FParameterType <> ptParameter then
  begin
    if FShortParameter <> '' then
      s := '-' + FShortParameter;
    if FLongParameter <> '' then
      L := '--' + FLongParameter;

    if (FShortParameter <> '') and (FLongParameter <> '') then
      Result := Result + s + ', ' + L
    else
      Result := Result + s + L;
  end;

  s := FLongDescription;
  if not FMandatory then
    s := '[optional]'#13#10 + s;

  if s <> '' then
  begin
    sl := TStringList.Create;
    try
      SplitString(s, sl, screenWidth - tabDesc);

      for i := 0 to Pred(sl.Count) do
        if (i = 0) and (Length(Result) < tabDesc) then
          Result := Result + StringOfChar(#32, tabDesc - Length(Result)) + sl[i]
        else
          Result := Result + #13#10 + StringOfChar(#32, tabDesc) + sl[i]
    finally
      sl.Free;
    end;
  end;
  Result := Result + #13#10;
end;

function TCommandLineParameter.ToShortSyntax: string;
var
  s, L: string;
begin
  Result := ' ';
  if not Mandatory then
    Result := Result + '[';

  if FParameterType <> ptParameter then
  begin
    if FShortParameter <> '' then
      s := '-' + FShortParameter;
    if FLongParameter <> '' then
      L := '--' + FLongParameter;

    if (FShortParameter <> '') then
      Result := Result + s
    else
      Result := Result + L;
  end;

  if FShortDescription <> '' then
    Result := Result + ' <' + FShortDescription + '>';

  if not FMandatory then
    Result := Result + ']';
end;

{ TCommandLineParameters }

procedure TCommandLineParameters.AddParameters(const Section: string; Parameter: TCommandLineParameter);
var
  L: TList<TCommandLineParameter>;
begin
  if not FParameters.TryGetValue(Section, L) then
  begin
    L := TObjectList<TCommandLineParameter>.Create(True);
    FParameters.Add(Section, L);
  end;
  L.Add(Parameter);
end;

constructor TCommandLineParameters.Create;
begin
  FParameters := TObjectDictionary < string, TList < TCommandLineParameter >>.Create([doOwnsValues]);
  FMissing := TList<TCommandLineParameter>.Create;
end;

function TCommandLineParameters.CreateParameter(const Short, Long, ShortDescription, Description: string; ParameterType: TParameterType; Mandatory: Boolean;
  Event: TOnParameterEvent; EventReference: TOnParameterEventReference): TCommandLineParameter;
begin
  Result := TCommandLineParameter.Create;
  Result.FShortParameter := Short;
  Result.FLongParameter := Long;
  Result.FShortDescription := ShortDescription;
  Result.FLongDescription := Description;
  Result.FMandatory := Mandatory;
  Result.FParameterType := ParameterType;
  if Assigned(Event) then
    Result.SetOnParameterEvent(Event)
  else
    Result.SetOnParameterEventReference(EventReference);
end;

destructor TCommandLineParameters.Destroy;
begin
  FMissing.Free;
  FParameters.Free;
  inherited;
end;

function TCommandLineParameters.FindNextParameter(lastShownParameter: TCommandLineParameter): TCommandLineParameter;
var
  Section: string;
begin
  for Section in FParameters.Keys do
    for Result in FParameters[Section] do
    begin
      if (lastShownParameter = nil) and (Result.ParameterType = ptParameter) then
        Exit
      else if (lastShownParameter = Result) then
        lastShownParameter := nil;
    end;
  Result := nil;
end;

function TCommandLineParameters.FindParameter(const Value: string): TCommandLineParameter;
var
  longParam: Boolean;
  Section: string;
begin
  Result := nil;
  if Value = '' then
    Exit;

  longParam := Value[1] = '-';

  for Section in FParameters.Keys do
    for Result in FParameters[Section] do
    begin
      if Result.FParameterType in [ptFlag, ptSwitch] then
        if ((Result.ShortParameter = Value) and not longParam) or (('-' + Result.LongParameter = Value) and longParam) then
          Exit;
    end;
  Result := nil;
end;

function TCommandLineParameters.GetFlag(const ShortParameter: string): Boolean;
var
  Section: string;
  p: TCommandLineParameter;
begin
  Result := False;
  for Section in FParameters.Keys do
    for p in FParameters[Section] do
    begin
      if ((p.ShortParameter = ShortParameter) or ((p.ShortParameter = '') and (p.LongParameter = ShortParameter))) then
      begin
        Result := p.FPresent;
        Break;
      end;
    end;
end;

procedure TCommandLineParameters.Parse;
var
  i: Integer;
  Section, p: string;

  param, lastParam: TCommandLineParameter;
begin
  FMissing.Clear;
  for Section in FParameters.Keys do
    for param in FParameters[Section] do
      if param.Mandatory then
        FMissing.Add(param);

  lastParam := nil;
  i := 1;
  while i <= ParamCount do
  begin
    p := ParamStr(i);

    if CharInSet(p[1], ['-', '/']) then
    begin
      param := FindParameter(Copy(p, 2, MaxInt));
      if param = nil then
        raise ECommandLineError.Create('Option not supported: ' + p);
      case param.ParameterType of
        ptFlag:
          param.DoOnParameter('');
        ptSwitch:
          begin
            Inc(i);
            param.DoOnParameter(ParamStr(i));
          end;
      else
        Assert(True, 'should never happen');
      end;
      FMissing.Remove(param);
    end
    else
    begin
      param := FindNextParameter(lastParam);
      if param = nil then
        raise ECommandLineError.Create('No parameter allowed here: ' + p);
      lastParam := param;
      param.DoOnParameter(p);
      FMissing.Remove(param);
    end;

    Inc(i);
  end;
end;

function TCommandLineParameters.PrintHelp: string;
var
  s: string;
  Section: string;
  p: TCommandLineParameter;
begin
  s := 'Arguments allowed for this application: '#13#10;
  for Section in FParameters.Keys do
  begin
    s := s + #13#10'' + Section + ':';
    for p in FParameters.Items[Section] do
      s := s + #13#10 + p.ToLongSyntax;
  end;
  Result := s;
end;

function TCommandLineParameters.PrintSyntax: String;
var
  s, Section: string;
  p: TCommandLineParameter;
begin
  s := 'Syntax: ' + ExtractFileName(ParamStr(0));
  for Section in FParameters.Keys do
    for p in FParameters[Section] do
      s := s + p.ToShortSyntax;
  Result := s;
end;

function TCommandLineParameters.RegisterFlag(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter(Short, Long, ShortDescription, Description, ptFlag, Mandatory, Event, nil);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.RegisterFlag(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter(Short, Long, ShortDescription, Description, ptFlag, Mandatory, nil, Event);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.RegisterParameter(const ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter('', '', ShortDescription, Description, ptSwitch, Mandatory, Event, nil);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.RegisterParameter(const ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter('', '', ShortDescription, Description, ptParameter, Mandatory, nil, Event);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.RegisterSwitch(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEvent;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter(Short, Long, ShortDescription, Description, ptSwitch, Mandatory, Event, nil);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.RegisterSwitch(const Short, Long, ShortDescription, Description: string; Mandatory: Boolean; Event: TOnParameterEventReference;
  const Section: string = ''): TCommandLineParameter;
begin
  Result := CreateParameter(Short, Long, ShortDescription, Description, ptSwitch, Mandatory, nil, Event);
  AddParameters(Section, Result);
end;

function TCommandLineParameters.Validate: Boolean;
begin
  Result := FMissing.Count = 0;
end;

end.
