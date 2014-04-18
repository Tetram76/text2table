unit UConvert;

interface

uses
  Windows, SysUtils, Classes, System.IOUtils, UExportCommun, Generics.Collections;

type
  TConvertOptions = class
  private
    class var FOutputFormat: TInfoEncodeFichierClass;
    class function GetOutputFormat: TInfoEncodeFichierClass; static;
  public
    class var InputFilename: TFileName;
    class var OutputFilename: TFileName;

  class var
    InputLocale: string;

    class property OutputFormat: TInfoEncodeFichierClass read GetOutputFormat write FOutputFormat;
    class var AddHeaders: Boolean;
    class var OutputLocale: string;
    class var XMLRootName: string;
    class var XMLRecordName: string;
    class var DataTypes: TDictionary<string, string>;

    class var RegEx: string;
    class var regExFileName: TFileName;

    class constructor Create;
    class destructor Destroy;
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
  URegExp;

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
  DataTypes := TDictionary<string, string>.Create;
end;

class destructor TConvertOptions.Destroy;
begin
  DataTypes.Free;
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
  EncodeOutput: TInfoEncodeFichier;
  ss: TStringStream;
begin
  PrepareStreams;
  try
    EncodeOutput := TConvertOptions.OutputFormat.Create(nil);
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

      ss := TStringStream.Create;
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

      EncodeOutput.SaveToStream(outputStream, TEncoding.Default);
    finally
      EncodeOutput.Free;
    end;
  finally
    CloseStreams;
  end;
end;

end.
