program text2table;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  UCommandLineParameters in 'UCommandLineParameters.pas',
  console.logger in 'console.logger.pas',
  UConvert in 'UConvert.pas',
  UExportXML in 'UExportXML.pas',
  UExportCSV in 'UExportCSV.pas',
  UExportCommun in 'UExportCommun.pas',
  UExportSYLK in 'UExportSYLK.pas',
  URegExp in 'URegExp.pas';

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

      CP.RegisterSwitch('il', 'ilocale', 'locale', 'Set locale for input data (default use system locale)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.InputLocale := Value;
        end, 'Input');

      CP.RegisterSwitch('o', 'output', 'filename', 'Output filename to write (default: use OUTPUT pipe)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.OutputFilename := Value;
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
        var
          o: TInfoEncodeFichierClass;
        begin
          if TInfoEncodeFichier.outputFormats.TryGetValue(Value, o) then
            TConvertOptions.OutputFormat := o
          else
            raise ECommandLineError.Create('Unknown output format : ' + Value);
        end, 'Output');

      CP.RegisterSwitch('l', 'locale', 'locale', 'Set locale for output data formatting (default use system locale)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.OutputLocale := Value;
        end, 'Output format');

      CP.RegisterFlag('', 'headers', '', 'Include headers in output file when relevant (default no)', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.AddHeaders := True;
        end, 'Output format');

      CP.RegisterSwitch('dt', 'datatype', 'field=type',
        'Define data type for each field in output'#13#10'Use one of those <type> :'#13#10'  - * (text, default)'#13#10'  - i (integer)'#13#10'  - n (float, numeric, currency)'#13#10'  - d (date)'#13#10'  - t (timestamp)',
        False,
        procedure(Sender: TObject; const Value: string)
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
          TConvertOptions.DataTypes.Add(f, t);
        end, 'Output format');

      CP.RegisterSwitch('', 'rootnodename', 'name', 'Set Root node name in XML output (default "data")', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.XMLRootName := Value;
        end, 'Output format');

      CP.RegisterSwitch('', 'recordnodename', 'name', 'Set Record node name in XML output (default "record")', False,
        procedure(Sender: TObject; const Value: string)
        begin
          TConvertOptions.XMLRootName := Value;
        end, 'Output format');

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
  except
    on E: Exception do
    begin
      l.Error('General exception, ' + E.Message);
      Halt(1);
    end;
  end;

end.
