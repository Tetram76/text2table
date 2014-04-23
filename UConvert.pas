unit UConvert;

interface

uses
  Windows, SysUtils, Classes, System.IOUtils, UExportCommun, Generics.Collections;

type
  TConvertOptions = class
  public type
    TDecodeParams = class
      class procedure I_switch(Sender: TObject; const Value: string);
      class procedure RF_switch(Sender: TObject; const Value: string);
      class procedure R_switch(Sender: TObject; const Value: string);
      class procedure IL_switch(Sender: TObject; const Value: string);
      class procedure O_switch(Sender: TObject; const Value: string);
      class procedure F_switch(Sender: TObject; const Value: string);
      class procedure L_switch(Sender: TObject; const Value: string);
      class procedure utf8_flag(Sender: TObject; const Value: string);
      class procedure iutf8_flag(Sender: TObject; const Value: string);
      class procedure headers_flag(Sender: TObject; const Value: string);
      class procedure DT_switch(Sender: TObject; const Value: string);
      class procedure rootnodename_switch(Sender: TObject; const Value: string);
      class procedure recordnodename_switch(Sender: TObject; const Value: string);
      class procedure emptystring_switch(Sender: TObject; const Value: string);
      class procedure emptydate_switch(Sender: TObject; const Value: string);
      class procedure emptytime_switch(Sender: TObject; const Value: string);
      class procedure emptyinteger_switch(Sender: TObject; const Value: string);
      class procedure emptynumber_switch(Sender: TObject; const Value: string);
      class procedure emptydata_flag(Sender: TObject; const Value: string);
    end;

  private
    class var FOutputFormat: TInfoEncodeFichierClass;
    class function GetOutputFormat: TInfoEncodeFichierClass; static;
    class function GetOuputEncoding: TEncoding; static;
    class function GetInutEncoding: TEncoding; static;

  public
    class var InputFilename: TFileName;
    class var OutputFilename: TFileName;
    class var InputLocale: string;
    class var AddHeaders: Boolean;
    class var OutputLocale: string;
    class var OutputUTF8: Boolean;
    class var InputUTF8: Boolean;
    class var XMLRootName: string;
    class var XMLRecordName: string;
    class var DataTypes: TDictionary<string, char>;

    class var RegEx: string;
    class var regExFileName: TFileName;

    class constructor Create;
    class destructor Destroy;

    class property OutputFormat: TInfoEncodeFichierClass read GetOutputFormat write FOutputFormat;
    class property OutputEncoding: TEncoding read GetOuputEncoding;
    class property InputEncoding: TEncoding read GetInutEncoding;

    class var EmptyData: Boolean;

    class var EmptyString: string;
    class var EmptyDate: string;
    class var EmptyTime: string;
    class var EmptyInteger: string;
    class var EmptyNumber: string;
  end;

  TConvertRuntime = class
  private
    class var inputStream: TStream;
    class var outputStream: TStream;

    class procedure PrepareStreams;
    class procedure CloseStreams;
  public
    class procedure ProcessConvert;
  end;

implementation

uses
  URegExp, UCommandLineParameters;

{ TConvertOptions }

class constructor TConvertOptions.Create;
begin
  InputFilename := '';

  RegEx := '';
  regExFileName := '';

  OutputFilename := '';
  AddHeaders := False;

  XMLRootName := 'data';
  XMLRecordName := 'record';
  DataTypes := TDictionary<string, char>.Create;
end;

class destructor TConvertOptions.Destroy;
begin
  DataTypes.Free;
end;

class function TConvertOptions.GetInutEncoding: TEncoding;
begin
  if InputUTF8 then
    Result := TEncoding.UTF8
  else
    Result := TEncoding.Default;
end;

class function TConvertOptions.GetOuputEncoding: TEncoding;
begin
  if OutputUTF8 then
    Result := TEncoding.UTF8
  else
    Result := TEncoding.Default;
end;

class function TConvertOptions.GetOutputFormat: TInfoEncodeFichierClass;
begin
  Result := FOutputFormat;
  if Result = nil then
    TInfoEncodeFichier.OutputFormats.TryGetValue('csv', Result);
end;

{ TConvertRuntime }

class procedure TConvertRuntime.CloseStreams;
begin
  FreeAndNil(inputStream);
  FreeAndNil(outputStream);
end;

class procedure TConvertRuntime.PrepareStreams;
begin
  if TConvertOptions.InputFilename <> '' then
    inputStream := TFileStream.Create(TConvertOptions.InputFilename, fmOpenRead)
  else
    inputStream := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));

  if TConvertOptions.OutputFilename <> '' then
  begin
    if TFile.Exists(TConvertOptions.OutputFilename) then
      TFile.Delete(TConvertOptions.OutputFilename);
    outputStream := TFileStream.Create(TConvertOptions.OutputFilename, fmCreate or fmOpenWrite);
  end
  else
    outputStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
end;

class procedure TConvertRuntime.ProcessConvert;
var
  Preamble: TBytes;
  EncodeOutput: TInfoEncodeFichier;
  ss: TStringStream;
begin
  PrepareStreams;
  try
    EncodeOutput := TConvertOptions.OutputFormat.Create;
    try
      EncodeOutput.SetOutputLocale(TConvertOptions.OutputLocale);

      if TConvertOptions.regExFileName <> '' then
      begin
        ss := TStringStream.Create;
        try
          ss.LoadFromFile(TConvertOptions.regExFileName);
          TConvertOptions.RegEx := ss.DataString;
        finally
          ss.Free;
        end;
      end;

      ss := TStringStream.Create('', TConvertOptions.InputEncoding);
      try
        if TConvertRuntime.inputStream.Size = 0 then
          raise EStreamError.Create('No data to parse');
        try
          ss.CopyFrom(TConvertRuntime.inputStream, 0);
        except
          if TConvertRuntime.inputStream.Size = -1 then
            raise EStreamError.Create('No data to parse')
          else
            raise;
        end;
        EncodeOutput.BuildFile(ss.DataString, TConvertOptions.RegEx);
      finally
        ss.Free;
      end;

      if TConvertOptions.OutputFilename <> '' then
        outputStream.Size := 0;

      if EncodeOutput.WriteBOM then
      begin
        Preamble := TConvertOptions.OutputEncoding.GetPreamble;
        if Length(Preamble) > 0 then
          outputStream.WriteBuffer(Preamble, Length(Preamble));
      end;

      if TConvertOptions.EmptyData or not EncodeOutput.IsEmpty then
        EncodeOutput.SaveToStream(outputStream, TConvertOptions.OutputEncoding);
    finally
      EncodeOutput.Free;
    end;
  finally
    CloseStreams;
  end;
end;

{ TConvertOptions.TDecodeParams }

class procedure TConvertOptions.TDecodeParams.DT_switch(Sender: TObject; const Value: string);
var
  sl: TStringList;
  f, t: string;
begin
  sl := TStringList.Create;
  try
    sl.Add(Value);
    f := LowerCase(sl.Names[0], TLocaleOptions.loInvariantLocale);
    t := LowerCase(sl.ValueFromIndex[0], TLocaleOptions.loInvariantLocale);
  finally
    sl.Free;
  end;
  if not CharInSet(t[1], ['*', 'i', 'n', 'd', 't']) then
    raise ECommandLineError.Create('Unknown data type : ' + Value);
  TConvertOptions.DataTypes.Add(f, t[1]);
end;

class procedure TConvertOptions.TDecodeParams.emptydata_flag(Sender: TObject; const Value: string);
begin
  TConvertOptions.EmptyData := True;
end;

class procedure TConvertOptions.TDecodeParams.emptydate_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.EmptyDate := Value;
end;

class procedure TConvertOptions.TDecodeParams.emptyinteger_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.EmptyInteger := Value;
end;

class procedure TConvertOptions.TDecodeParams.emptynumber_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.EmptyNumber := Value;
end;

class procedure TConvertOptions.TDecodeParams.emptystring_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.EmptyString := Value;
end;

class procedure TConvertOptions.TDecodeParams.emptytime_switch(Sender: TObject; const Value: string);
begin

end;

class procedure TConvertOptions.TDecodeParams.F_switch(Sender: TObject; const Value: string);
var
  o: TInfoEncodeFichierClass;
begin
  if TInfoEncodeFichier.OutputFormats.TryGetValue(Value, o) then
    TConvertOptions.OutputFormat := o
  else
    raise ECommandLineError.Create('Unknown output format : ' + Value);
end;

class procedure TConvertOptions.TDecodeParams.headers_flag(Sender: TObject; const Value: string);
begin
  TConvertOptions.AddHeaders := True;
end;

class procedure TConvertOptions.TDecodeParams.IL_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.InputLocale := Value;
end;

class procedure TConvertOptions.TDecodeParams.iutf8_flag(Sender: TObject; const Value: string);
begin
  TConvertOptions.InputUTF8 := True;
end;

class procedure TConvertOptions.TDecodeParams.I_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.InputFilename := Value;
end;

class procedure TConvertOptions.TDecodeParams.L_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.OutputLocale := Value;
end;

class procedure TConvertOptions.TDecodeParams.O_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.OutputFilename := Value;
end;

class procedure TConvertOptions.TDecodeParams.recordnodename_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.XMLRootName := Value;
end;

class procedure TConvertOptions.TDecodeParams.RF_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.regExFileName := Value;
end;

class procedure TConvertOptions.TDecodeParams.rootnodename_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.XMLRootName := Value;
end;

class procedure TConvertOptions.TDecodeParams.R_switch(Sender: TObject; const Value: string);
begin
  TConvertOptions.RegEx := Value;
end;

class procedure TConvertOptions.TDecodeParams.utf8_flag(Sender: TObject; const Value: string);
begin
  TConvertOptions.OutputUTF8 := True;
end;

end.
