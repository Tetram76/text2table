unit UExportCommun;

interface

uses
  SysUtils, Classes, System.IOUtils, Generics.Collections, IBQuery;

type
  TLogEvent = procedure(const Message: string; Erreur: Boolean) of object;
  TProcessCallback = TNotifyEvent;
  TProcessDataCallback = procedure(Sender: TObject; IBMaster, IBDetail: TIBQuery) of object;

  TInfoEncodeFichierClass = class of TInfoEncodeFichier;

  TInfoEncodeFichier = class
  private
    class var FOutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
  public
    class function OutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
    class procedure RegisterOutputFormat(Format: string; EncodeClass: TInfoEncodeFichierClass);
    class constructor Create;
    class destructor Destroy;

  private
    FExtension: string;
    FOnWriteHeaderFile: TProcessCallback;
    FOnWriteFooterFile: TProcessCallback;
    FOnWriteFooterDataset: TProcessDataCallback;
    FOnWriteHeaderDataset: TProcessDataCallback;
    FOnWriteDetailData: TProcessDataCallback;
    FOnWriteMasterData: TProcessDataCallback;
    FFormatSettings: TFormatSettings;
  protected
    FFlatBuild: Boolean;
  public

    FLogCallback: TLogEvent;

    constructor Create(LogCallBack: TLogEvent); virtual;
    destructor Destroy; override;

    procedure WriteHeaderFile; virtual;
    procedure WriteHeaderDataset(IBMaster, IBDetail: TIBQuery); virtual;
    procedure WriteMasterData(IBMaster, IBDetail: TIBQuery); virtual;
    procedure WriteDetailData(IBMaster, IBDetail: TIBQuery); virtual;
    procedure WriteFooterDataset(IBMaster, IBDetail: TIBQuery); virtual;
    procedure WriteFooterFile; virtual;

    procedure SetHeaders(List: TStrings); virtual; abstract;
    procedure SetLocale(locale: string); virtual;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; virtual; abstract;

    procedure BuildFile(IBMaster, IBDetail: TIBQuery; Parameters: array of string);

    property Extension: string read FExtension write FExtension;
    property FormatSettings: TFormatSettings read FFormatSettings;

    property OnWriteHeaderFile: TProcessCallback read FOnWriteHeaderFile write FOnWriteHeaderFile;
    property OnWriteHeaderDataset: TProcessDataCallback read FOnWriteHeaderDataset write FOnWriteHeaderDataset;
    property OnWriteMasterData: TProcessDataCallback read FOnWriteMasterData write FOnWriteMasterData;
    property OnWriteDetailData: TProcessDataCallback read FOnWriteDetailData write FOnWriteDetailData;
    property OnWriteFooterDataset: TProcessDataCallback read FOnWriteFooterDataset write FOnWriteFooterDataset;
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

procedure TInfoEncodeFichier.BuildFile(IBMaster, IBDetail: TIBQuery; Parameters: array of string);
var
  headerWritten: Boolean;
  i: Integer;
  p: string;
begin
  headerWritten := False;

  if not IBMaster.Active then
    IBMaster.Open;

  WriteHeaderFile;
  if Assigned(OnWriteHeaderFile) then
    OnWriteHeaderFile(Self);

  while not IBMaster.Eof do
  begin
    if Assigned(IBDetail) and (Length(Parameters) > 0) then
    begin
      IBDetail.Close;
      for i := Low(Parameters) to High(Parameters) do
      begin
        p := Parameters[i];
        IBDetail.ParamByName(p).AssignField(IBMaster.FieldByName(p));
      end;
      IBDetail.Open;
    end;

    if not headerWritten then
    begin
      WriteHeaderDataset(IBMaster, IBDetail);
      if Assigned(OnWriteHeaderDataset) then
        OnWriteHeaderDataset(Self, IBMaster, IBDetail);
      headerWritten := True;
    end;

    if not Assigned(IBDetail) then
    begin
      WriteMasterData(IBMaster, IBDetail);
      if Assigned(OnWriteMasterData) then
        OnWriteMasterData(Self, IBMaster, IBDetail);
    end
    else
    begin
      if not FFlatBuild then
      begin
        WriteMasterData(IBMaster, IBDetail);
        if Assigned(OnWriteMasterData) then
          OnWriteMasterData(Self, IBMaster, IBDetail);
      end;
      while not IBDetail.Eof do
      begin
        if FFlatBuild then
        begin
          WriteMasterData(IBMaster, IBDetail);
          if Assigned(OnWriteMasterData) then
            OnWriteMasterData(Self, IBMaster, IBDetail);
        end;
        WriteDetailData(IBMaster, IBDetail);
        if Assigned(OnWriteDetailData) then
          OnWriteDetailData(Self, IBMaster, IBDetail);

        IBDetail.Next;
      end;
    end;

    IBMaster.Next;
  end;
  if headerWritten then
  begin
    WriteFooterDataset(IBMaster, IBDetail);
    if Assigned(OnWriteFooterDataset) then
      OnWriteFooterDataset(Self, IBMaster, IBDetail);
  end;

  WriteFooterFile;
  if Assigned(OnWriteFooterFile) then
    OnWriteFooterFile(Self);
end;

constructor TInfoEncodeFichier.Create(LogCallBack: TLogEvent);
begin
  FLogCallback := LogCallBack;
  FFlatBuild := True;

  SetLocale('');
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

  inherited;
end;

class function TInfoEncodeFichier.OutputFormats: TDictionary<string, TInfoEncodeFichierClass>;
begin
  Result := FOutputFormats;
end;

class procedure TInfoEncodeFichier.RegisterOutputFormat(Format: string; EncodeClass: TInfoEncodeFichierClass);
begin
  FOutputFormats.AddOrSetValue(Format, EncodeClass);
end;

procedure TInfoEncodeFichier.SetLocale(locale: string);
begin
  FFormatSettings := TFormatSettings.Create(locale);
end;

procedure TInfoEncodeFichier.WriteFooterDataset(IBMaster, IBDetail: TIBQuery);
begin

end;

procedure TInfoEncodeFichier.WriteFooterFile;
begin

end;

procedure TInfoEncodeFichier.WriteHeaderDataset(IBMaster, IBDetail: TIBQuery);
begin

end;

procedure TInfoEncodeFichier.WriteHeaderFile;
begin

end;

procedure TInfoEncodeFichier.WriteDetailData(IBMaster, IBDetail: TIBQuery);
begin

end;

procedure TInfoEncodeFichier.WriteMasterData(IBMaster, IBDetail: TIBQuery);
begin

end;

end.
