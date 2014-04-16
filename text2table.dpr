program text2table;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  UCommandLineParameters in 'UCommandLineParameters.pas',
  console.logger in 'console.logger.pas',
  UConvert in 'UConvert.pas',
  UExportXML in 'UExportXML.pas',
  UExportCSV in 'UExportCSV.pas',
  UExportCommun in 'UExportCommun.pas',
  UExportSYLK in 'UExportSYLK.pas';

// https://code.google.com/p/fbclone/source/browse/trunk/fbclone.dpr

var
  CP: TCommandLineParameters;
  p: TCommandLineParameter;
  l: ILogger;
  outputFormats: TArray<String>;
  s, f: string;

begin
  l := TConsoleLogger.Create;

  CP := TCommandLineParameters.Create;
  try
    try
      CP.RegisterFlag('h', 'help', '', 'Show this help message', False,
        procedure(Sender: TObject; const Value: string)
        begin
          l.Info(CP.PrintSyntax);
          l.Info;
          l.Info(CP.PrintHelp);
          Halt(0);
        end, 'General');
      CP.RegisterSwitch('i', 'input', 'filename', 'Input filename to parse (default: use INPUT pipe)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.InputFilename := Value;
        end, 'Input');
      CP.RegisterSwitch('r', 'regex', 'regex', 'Regular expression applied on input to extract data', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.RegEx := Value;
        end, 'Input');
      CP.RegisterSwitch('rf', '', 'filename', 'Filename containing the regular expression applied on input to extract data', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.regExFileName := Value;
        end, 'Input');

      CP.RegisterSwitch('o', 'output', 'filename', 'Output filename to write (default: use OUTPUT pipe)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.OutputFilename := Value;
        end, 'Output');

      CP.RegisterFlag('', 'headers', '', 'Include headers in output file when relevant (default no)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.AddHeaders := True;
        end, 'Output');

      CP.RegisterSwitch('l', 'locale', 'locale', 'Set locale for output data formatting (default use system locale)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.Locale := Value;
        end, 'Output');

      outputFormats := TInfoEncodeFichier.outputFormats.Keys.ToArray;
      s := '';
      for f in outputFormats do
      begin
        if SameText(f, 'csv') then
          s := s + #13#10'  - ' + f + ' (default)'
        else
          s := s + #13#10'  - ' + f;
      end;

      CP.RegisterSwitch('f', 'format', 'format', 'Set one of output format:' + s, False,
        procedure(Sender: TObject; const Value: string)
        begin
          if not TInfoEncodeFichier.outputFormats.TryGetValue(Value, TConvertOptions.OutputFormat) then
            raise ECommandLineError.Create('Unknown output format : ' + Value);
        end, 'Output');

      CP.Parse;

      if not CP.Validate then
      begin
        l.Error('Missing parameters on command line:');
        for p in CP.Missing do
          l.Error(' ' + p.ToShortSyntax);
        l.Error;
        l.Error(CP.PrintSyntax);
        Halt(1);
      end;

      if not(CP.Flag['r'] or CP.Flag['rf']) then
      begin
        l.Error('Missing parameters on command line:');
        l.Error('  -r or -rf must be used to define regular expression');
        l.Error;
        l.Error(CP.PrintSyntax);
        Halt(1);
      end;

      if CP.Flag['r'] and CP.Flag['rf'] then
      begin
        l.Error('Conflict between parameters on command line:');
        l.Error(' Flags -r and -rf cannot be used together');
        l.Error;
        l.Error(CP.PrintSyntax);
        Halt(1);
      end;

    except
      on E: Exception do
      begin
        l.Error('Error on command line, ' + E.Message);
        l.Error;
        l.Error(CP.PrintSyntax);
        Halt(1);
      end;
    end;
  finally
    CP.Free;
  end;

  try
    TConvertRuntime.ProcessConvert;
{$IFDEF DEBUG}
    if TConvertOptions.OutputFilename = '' then
    begin
      WriteLn;
      WriteLn('[DEBUG] Press Return to terminate');
      ReadLn;
    end;
{$ENDIF}
  except
    on E: Exception do
    begin
      l.Error('General exception ' + E.Message);
      Halt(1);
    end;
  end;

end.
