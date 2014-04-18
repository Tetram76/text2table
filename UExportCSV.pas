unit UExportCSV;

interface

uses
  SysUtils, Classes, UExportCommun;

type
  TEncodeCSV = class(TInfoEncodeFichier)
  private
    fsData: TMemoryStream;
    FCurrentLine: Integer;
    FNewLineStr: string;
    procedure WriteRawString(fs: TStream; s: string);
    procedure WriteString(fs: TStream; s: string);
    procedure ProcessData(fs: TStream; Data: TData);
  public
    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;

    procedure WriteHeaderDataset; override;
    procedure WriteData(Data: TData); override;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;

    property NewLineStr: string read FNewLineStr write FNewLineStr;
  end;

implementation

uses
  UConvert;

{ TEncodeCSV }

constructor TEncodeCSV.Create(LogCallBack: TLogEvent);
begin
  inherited;
  Extension := '.csv';
  FNewLineStr := sLineBreak;
  FCurrentLine := 0;
  fsData := TMemoryStream.Create;
end;

destructor TEncodeCSV.Destroy;
begin
  fsData.Free;
  inherited;
end;

procedure TEncodeCSV.ProcessData(fs: TStream; Data: TData);
var
  i: Integer;
  s, t: string;
begin
  for i := 0 to Pred(Data.Count) do
  begin
    if i > 0 then
      WriteRawString(fs, ';');

    if Data[i] <> '' then
    begin
      TConvertOptions.DataTypes.TryGetValue(Headers[i], t);
      if t = '' then
        t := '*';

      case t[1] of
        'd':
          s := FormatDateTime(OutputFormatSettings.ShortDateFormat, Trunc(StrToDate(Data[i], InputFormatSettings)), OutputFormatSettings);
        't':
          s := FormatDateTime(OutputFormatSettings.ShortDateFormat, Trunc(StrToDateTime(Data[i], InputFormatSettings)), OutputFormatSettings) + ' ' +
            FormatDateTime(OutputFormatSettings.ShortTimeFormat, Frac(StrToDateTime(Data[i], InputFormatSettings)), OutputFormatSettings);
        'n':
          s := Format('%s', [FormatCurr('0.##', StrToCurr(Data[i], InputFormatSettings), OutputFormatSettings)]);
        'i':
          s := IntToStr(StrToInt(Data[i]));
      else
        begin
          s := AdjustLineBreaks(Data[i]);
          s := StringReplace(s, sLineBreak, FNewLineStr, [rfReplaceAll]);
        end;
      end;
      WriteString(fs, s);
    end;
  end;
end;

function TEncodeCSV.SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean;
begin
  Result := FCurrentLine > 0;
  if Result then
    fsData.SaveToStream(Stream);
end;

procedure TEncodeCSV.WriteHeaderDataset;
var
  i: Integer;
begin
  inherited;

  if TConvertOptions.AddHeaders then
  begin
    for i := 0 to Pred(Headers.Count) do
    begin
      if i > 0 then
        WriteRawString(fsData, ';');
      WriteString(fsData, Headers[i]);
    end;

    WriteRawString(fsData, #13#10);
  end;
end;

procedure TEncodeCSV.WriteData(Data: TData);
begin
  inherited;

  Inc(FCurrentLine);
  ProcessData(fsData, Data);
end;

procedure TEncodeCSV.WriteRawString(fs: TStream; s: string);
var
  b: TArray<Byte>;
begin
  b := TEncoding.Default.GetBytes(s);
  fs.Write(b, Length(b));
end;

procedure TEncodeCSV.WriteString(fs: TStream; s: string);
begin
  s := StringReplace(s, '"', '""', [rfReplaceAll]);
  if Pos('"', s) + Pos(';', s) + Pos(#13, s) + Pos(#10, s) + Pos(#9, s) > 0 then
    s := '"' + s + '"';
  WriteRawString(fs, s);
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('csv', TEncodeCSV);

end.
