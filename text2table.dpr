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
  URegExp in 'URegExp.pas',
  UExportJSON in 'UExportJSON.pas';

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
      CP.RegisterSwitch('i', 'input', 'filename', 'Input filename to parse (default: use INPUT stream)', False, TConvertOptions.TDecodeParams.I_switch,
        'Input');
      CP.RegisterSwitch('r', 'regex', 'regex', 'Regular expression applied on input to extract data', False, TConvertOptions.TDecodeParams.R_switch, 'Input');
      CP.RegisterSwitch('rf', '', 'filename', 'Filename containing the regular expression applied on input to extract data', False,
        TConvertOptions.TDecodeParams.RF_switch, 'Input');

      CP.RegisterSwitch('il', 'ilocale', 'locale', 'Set locale for input data (default use system locale)', False,
        TConvertOptions.TDecodeParams.IL_switch, 'Input');

      CP.RegisterSwitch('o', 'output', 'filename', 'Output filename to write (default: use OUTPUT stream)', False, TConvertOptions.TDecodeParams.O_switch,
        'Output');

      outputFormats := TInfoEncodeFichier.outputFormats.Keys.ToArray;
      s := '';
      for f in outputFormats do
        s := s + #13#10'  - ' + f;
      CP.RegisterSwitch('f', 'format', 'format', 'Set one of output format:' + s, True, TConvertOptions.TDecodeParams.F_switch, 'Output');
      CP.RegisterFlag('', 'emptydata', '', 'Allow generating empty data structure if no records was found in INPUT', False,
        TConvertOptions.TDecodeParams.emptydata_flag, 'Output');

      CP.RegisterSwitch('l', 'locale', 'locale', 'Set locale for output data formatting when relevant (default use system locale)', False,
        TConvertOptions.TDecodeParams.L_switch, 'Output format');

      CP.RegisterFlag('', 'utf8', '', 'Use UTF8 encoding for output formatting when applicable (default use system)', False,
        TConvertOptions.TDecodeParams.utf8_flag, 'Output format');
      CP.RegisterFlag('', 'headers', '', 'Include headers in output file when relevant (default no)', False, TConvertOptions.TDecodeParams.headers_flag,
        'Output format');
      CP.RegisterSwitch('dt', 'datatype', 'field=type',
        'Define data type for each field in output.'#13#10'Use one -dt flag for each field to define. Use one of those <type> :'#13#10'  - * (text, default)'#13#10'  - i (integer)'#13#10'  - n (float, numeric, currency)'#13#10'  - d (date)'#13#10'  - t (timestamp)',
        False, TConvertOptions.TDecodeParams.DT_switch, 'Output format');
      CP.RegisterSwitch('', 'rootnodename', 'name', 'Set Root node name in XML output (default "data")', False,
        TConvertOptions.TDecodeParams.rootnodename_switch, 'Output format');
      CP.RegisterSwitch('', 'recordnodename', 'name', 'Set Record node name in XML output (default "record")', False,
        TConvertOptions.TDecodeParams.recordnodename_switch, 'Output format');
      CP.RegisterSwitch('', 'emptystring', 'string',
        'Define string in output data to use when a string capturing group is not found in INPUT data (default none)', False,
        TConvertOptions.TDecodeParams.emptystring_switch, 'Output format');
      CP.RegisterSwitch('', 'emptydate', 'string', 'Define string in output data to use when a date capturing group is not found in INPUT data (default none)',
        False, TConvertOptions.TDecodeParams.emptydate_switch, 'Output format');
      CP.RegisterSwitch('', 'emptytime', 'string', 'Define string in output data to use when a time capturing group is not found in INPUT data (default none)',
        False, TConvertOptions.TDecodeParams.emptytime_switch, 'Output format');
      CP.RegisterSwitch('', 'emptyinteger', 'string',
        'Define string in output data to use when an integer capturing group is not found in INPUT data (default none)', False,
        TConvertOptions.TDecodeParams.emptyinteger_switch, 'Output format');
      CP.RegisterSwitch('', 'emptynumber', 'string',
        'Define string in output data to use when a number capturing group is not found in INPUT data (default none)', False,
        TConvertOptions.TDecodeParams.emptynumber_switch, 'Output format');

      CP.Parse;

      if not CP.Validate then
      begin
        l.Error('Missing parameter(s) on command line:');
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
