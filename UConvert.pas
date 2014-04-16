unit UConvert;

interface

uses
  Windows, SysUtils, Classes, System.IOUtils, UExportCommun;

type
  TConvertOptions = class
  public
    class var OutputFormat: TInfoEncodeFichierClass;
    class var InputFilename, OutputFilename: TFileName;
    class var AddHeaders: Boolean;
    class var Locale: string;

    class var RegEx: string;
    class var regExFileName: TFileName;

    class constructor Create;
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

{ TConvertOptions }

class constructor TConvertOptions.Create;
begin
  InputFilename := '';

  RegEx := '';
  regExFileName := '';

  OutputFilename := '';
  TInfoEncodeFichier.OutputFormats.TryGetValue('csv', OutputFormat);
  AddHeaders := False;
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
begin
  PrepareStreams;
  try
    EncodeOutput := TConvertOptions.OutputFormat.Create(nil);
    try
      EncodeOutput.SetLocale(TConvertOptions.Locale);

      // TODO: compiler la regex
      // TODO: recupérer la liste des noms des champs capturants de la regex
      EncodeOutput.SetHeaders(nil);

      EncodeOutput.WriteHeaderFile;
      EncodeOutput.WriteHeaderDataset(nil,nil);

      // TODO: appliquer la regex sur inputStream
      // TODO: pour chaque correspondance de la regex, ecrire un enregistrement :
      EncodeOutput.WriteMasterData(nil, nil);

      EncodeOutput.WriteFooterDataset(nil,nil);
      EncodeOutput.WriteFooterFile;

      EncodeOutput.SaveToStream(outputStream, TEncoding.Default);
    finally
      EncodeOutput.Free;
    end;
  finally
    CloseStreams;
  end;
end;

end.
