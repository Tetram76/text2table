unit UExportCommun;

interface

uses
  SysUtils, Classes, System.IOUtils, Generics.Collections;

type
  TData = TDictionary<string, string>;

  TLogEvent = procedure(const Message: string; Erreur: Boolean) of object;
  TProcessCallback = TNotifyEvent;
  TProcessDataCallback = procedure(Sender: TObject; Data: TData) of object;

  TInfoEncodeFichierClass = class of TInfoEncodeFichier;

  TInfoEncodeFichier = class
  private
    class var FOutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
  public
    class function OutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
    class procedure RegisterOutputFormat(const Format: string; EncodeClass: TInfoEncodeFichierClass);
    class constructor Create;
    class destructor Destroy;

  private
    FOnWriteHeaderFile: TProcessCallback;
    FOnWriteFooterFile: TProcessCallback;
    FOnWriteFooterDataset: TProcessCallback;
    FOnWriteHeaderDataset: TProcessCallback;
    FOnWriteData: TProcessDataCallback;
    FInputFormatSettings: TFormatSettings;
    FOutputFormatSettings: TFormatSettings;
    FHeaders: TList<string>;
    FWriteBOM: Boolean;
    procedure SetWriteBOM(const Value: Boolean);
  protected
    FFlatBuild: Boolean;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function FormatValue(const Header, Value: string): string;
    function FormatString(const Value: string): string; virtual;
    function FormatDate(const Value: string): string; virtual;
    function FormatDateTime(const Value: string): string; virtual;
    function FormatInteger(const Value: string): string; virtual;
    function FormatNumber(const Value: string): string; virtual;

    procedure WriteHeaderFile; virtual;
    procedure WriteHeaderDataset; virtual;
    procedure WriteData(Data: TData); virtual;
    procedure WriteFooterDataset; virtual;
    procedure WriteFooterFile; virtual;

    procedure SetOutputLocale(locale: string); virtual;
    procedure SetInputLocale(locale: string); virtual;

    function IsEmpty: Boolean; virtual;
    procedure SaveToStream(Stream: TStream; Encoding: TEncoding); virtual; abstract;

    procedure BuildFile(const Data, RegEx: string);

    property Headers: TList<string> read FHeaders;

    property OutputFormatSettings: TFormatSettings read FOutputFormatSettings;
    property InputFormatSettings: TFormatSettings read FInputFormatSettings;

    property OnWriteHeaderFile: TProcessCallback read FOnWriteHeaderFile write FOnWriteHeaderFile;
    property OnWriteHeaderDataset: TProcessCallback read FOnWriteHeaderDataset write FOnWriteHeaderDataset;
    property OnWriteData: TProcessDataCallback read FOnWriteData write FOnWriteData;
    property OnWriteFooterDataset: TProcessCallback read FOnWriteFooterDataset write FOnWriteFooterDataset;
    property OnWriteFooterFile: TProcessCallback read FOnWriteFooterFile write FOnWriteFooterFile;

    property WriteBOM: Boolean read FWriteBOM write SetWriteBOM;
  end;

  TWindowsStringList = class(TStringList)
  public
    constructor Create; virtual;
  end;

  TUnixStringList = class(TStringList)
  public
    constructor Create; virtual;
  end;

implementation

uses
  URegExp, UConvert;

{ TWindowsStringList }

constructor TWindowsStringList.Create;
begin
  inherited;
  LineBreak := #13#10;
end;

{ TUnixStringList }

constructor TUnixStringList.Create;
begin
  inherited;
  LineBreak := #10;
end;

{ TInfoEncodeFichier }

procedure TInfoEncodeFichier.BuildFile(const Data, RegEx: string);
var
  headerWritten: Boolean;
  i: Integer;
  s: string;
  RegExp: TRegExp;
  sl: TData;
begin
  RegExp := TRegExp.Create;
  sl := TData.Create;
  try
    RegExp.Prepare(TConvertOptions.RegEx);
    Headers.Clear;
    // PCRE retourne le noms en en commençant par le "fin" de la regex
    for i := Pred(RegExp.CaptureCount) downto 0 do
    begin
      s := RegExp.CaptureNames[i];
      if Headers.IndexOf(s) = -1 then
        Headers.Add(s);
    end;

    RegExp.BeginSearch(Data);

    headerWritten := False;

    WriteHeaderFile;
    if Assigned(OnWriteHeaderFile) then
      OnWriteHeaderFile(Self);

    while RegExp.Next do
    begin
      sl.Clear;

      // TODO: même si le groupe catpurant n'est pas dans la chaine analysée, il apparait quand même dans la liste des CaptureNames
      // Il faudrait donc trouver un moyen de différencier "chaine vide" de "non trouvé"

      // PCRE retourne le noms en en commençant par le "fin" de la regex
      for i := Pred(RegExp.CaptureCount) downto 0 do
      begin
        s := RegExp.CaptureNames[i];
        sl.AddOrSetValue(s, RegExp.GetCaptureByName(s));
      end;

      if not headerWritten then
      begin
        WriteHeaderDataset;
        if Assigned(OnWriteHeaderDataset) then
          OnWriteHeaderDataset(Self);
        headerWritten := True;
      end;

      WriteData(sl);
      if Assigned(OnWriteData) then
        OnWriteData(Self, sl);
    end;

    if headerWritten then
    begin
      WriteFooterDataset;
      if Assigned(OnWriteFooterDataset) then
        OnWriteFooterDataset(Self);
    end;

    WriteFooterFile;
    if Assigned(OnWriteFooterFile) then
      OnWriteFooterFile(Self);
  finally
    sl.Free;
    RegExp.Free;
  end;
end;

constructor TInfoEncodeFichier.Create;
begin
  FFlatBuild := True;
  FHeaders := TList<string>.Create;

  SetOutputLocale('');
  SetInputLocale('');

  FWriteBOM := True;
end;

class constructor TInfoEncodeFichier.Create;
begin
  FOutputFormats := TDictionary<string, TInfoEncodeFichierClass>.Create;
end;

class destructor TInfoEncodeFichier.Destroy;
begin
  FOutputFormats.Free;
end;

destructor TInfoEncodeFichier.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

function TInfoEncodeFichier.FormatDate(const Value: string): string;
begin
  Result := SysUtils.FormatDateTime(OutputFormatSettings.ShortDateFormat, Trunc(StrToDate(Value, InputFormatSettings)), OutputFormatSettings);
end;

function TInfoEncodeFichier.FormatDateTime(const Value: string): string;
begin
  Result := SysUtils.FormatDateTime(OutputFormatSettings.ShortDateFormat, Trunc(StrToDateTime(Result, InputFormatSettings)), OutputFormatSettings) + ' ' +
    SysUtils.FormatDateTime(OutputFormatSettings.ShortTimeFormat, Frac(StrToDateTime(Result, InputFormatSettings)), OutputFormatSettings);
end;

function TInfoEncodeFichier.FormatInteger(const Value: string): string;
begin
  Result := IntToStr(StrToInt(Value));
end;

function TInfoEncodeFichier.FormatNumber(const Value: string): string;
begin
  Result := Format('%s', [FormatCurr('0.##', StrToCurr(Value, InputFormatSettings), OutputFormatSettings)])
end;

function TInfoEncodeFichier.FormatString(const Value: string): string;
begin
  Result := Value;
end;

function TInfoEncodeFichier.FormatValue(const Header, Value: string): string;
var
  t: char;
begin
  TConvertOptions.DataTypes.TryGetValue(Header, t);
  if t = '' then
    t := '*';

  Result := Value;

  case t of
    'd':
      if Result = '' then
        Result := TConvertOptions.EmptyDate
      else
        Result := FormatDate(Result);
    't':
      if Result = '' then
        Result := TConvertOptions.EmptyTime
      else
        Result := FormatDateTime(Result);
    'n':
      if Result = '' then
        Result := TConvertOptions.EmptyNumber
      else
        Result := FormatNumber(Result);
    'i':
      if Result = '' then
        Result := TConvertOptions.EmptyInteger
      else
        Result := FormatInteger(Result);
  else
    if Result = '' then
      Result := TConvertOptions.EmptyString
    else
      Result := FormatString(Result);
  end;
end;

function TInfoEncodeFichier.IsEmpty: Boolean;
begin
  Result := False;
end;

class function TInfoEncodeFichier.OutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
begin
  Result := FOutputFormats;
end;

class procedure TInfoEncodeFichier.RegisterOutputFormat(const Format: string; EncodeClass: TInfoEncodeFichierClass);
begin
  FOutputFormats.AddOrSetValue(Format, EncodeClass);
end;

procedure TInfoEncodeFichier.SetInputLocale(locale: string);
begin
  FInputFormatSettings := TFormatSettings.Create(locale);
end;

procedure TInfoEncodeFichier.SetOutputLocale(locale: string);
begin
  FOutputFormatSettings := TFormatSettings.Create(locale);
end;

procedure TInfoEncodeFichier.SetWriteBOM(const Value: Boolean);
begin
  FWriteBOM := Value;
end;

procedure TInfoEncodeFichier.WriteFooterDataset;
begin

end;

procedure TInfoEncodeFichier.WriteFooterFile;
begin

end;

procedure TInfoEncodeFichier.WriteHeaderDataset;
begin

end;

procedure TInfoEncodeFichier.WriteHeaderFile;
begin

end;

procedure TInfoEncodeFichier.WriteData(Data: TData);
begin

end;

end.
