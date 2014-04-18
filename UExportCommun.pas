unit UExportCommun;

interface

uses
  SysUtils, Classes, System.IOUtils, Generics.Collections;

type
  TData = TList<string>;

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
    FExtension: string;
    FOnWriteHeaderFile: TProcessCallback;
    FOnWriteFooterFile: TProcessCallback;
    FOnWriteFooterDataset: TProcessCallback;
    FOnWriteHeaderDataset: TProcessCallback;
    FOnWriteData: TProcessDataCallback;
    FInputFormatSettings: TFormatSettings;
    FOutputFormatSettings: TFormatSettings;
    FHeaders: TData;
  protected
    FFlatBuild: Boolean;
  public

    FLogCallback: TLogEvent;

    constructor Create(LogCallBack: TLogEvent); virtual;
    destructor Destroy; override;

    procedure WriteHeaderFile; virtual;
    procedure WriteHeaderDataset; virtual;
    procedure WriteData(Data: TData); virtual;
    procedure WriteFooterDataset; virtual;
    procedure WriteFooterFile; virtual;

    procedure SetHeaders(List: TData); virtual;
    procedure SetOutputLocale(locale: string); virtual;
    procedure SetInputLocale(locale: string); virtual;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; virtual; abstract;

    procedure BuildFile(const Data, RegEx: string);

    property Headers: TData read FHeaders write SetHeaders;

    property Extension: string read FExtension write FExtension;
    property OutputFormatSettings: TFormatSettings read FOutputFormatSettings;
    property InputFormatSettings: TFormatSettings read FInputFormatSettings;

    property OnWriteHeaderFile: TProcessCallback read FOnWriteHeaderFile write FOnWriteHeaderFile;
    property OnWriteHeaderDataset: TProcessCallback read FOnWriteHeaderDataset write FOnWriteHeaderDataset;
    property OnWriteData: TProcessDataCallback read FOnWriteData write FOnWriteData;
    property OnWriteFooterDataset: TProcessCallback read FOnWriteFooterDataset write FOnWriteFooterDataset;
    property OnWriteFooterFile: TProcessCallback read FOnWriteFooterFile write FOnWriteFooterFile;
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
    // PCRE retourne le noms en en commençant par le "fin" de la regex
    for i := Pred(RegExp.CaptureCount) downto 0 do
    begin
      s := RegExp.CaptureNames[i];
      if sl.IndexOf(s) = -1 then
        sl.Add(s);
    end;
    SetHeaders(sl);

    RegExp.BeginSearch(Data);

    headerWritten := False;

    WriteHeaderFile;
    if Assigned(OnWriteHeaderFile) then
      OnWriteHeaderFile(Self);

    while RegExp.Next do
    begin
      sl.Clear;
      for s in Headers do
        sl.Add(RegExp.GetCaptureByName(s));

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

constructor TInfoEncodeFichier.Create(LogCallBack: TLogEvent);
begin
  FLogCallback := LogCallBack;
  FFlatBuild := True;
  FHeaders := TData.Create;

  SetOutputLocale('');
  SetInputLocale('');
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

class function TInfoEncodeFichier.OutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
begin
  Result := FOutputFormats;
end;

class procedure TInfoEncodeFichier.RegisterOutputFormat(const Format: string; EncodeClass: TInfoEncodeFichierClass);
begin
  FOutputFormats.AddOrSetValue(Format, EncodeClass);
end;

procedure TInfoEncodeFichier.SetHeaders(List: TData);
begin
  FHeaders.Clear;
  FHeaders.AddRange(List.ToArray);
end;

procedure TInfoEncodeFichier.SetInputLocale(locale: string);
begin
  FInputFormatSettings := TFormatSettings.Create(locale);
end;

procedure TInfoEncodeFichier.SetOutputLocale(locale: string);
begin
  FOutputFormatSettings := TFormatSettings.Create(locale);
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
