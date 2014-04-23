unit UExportSYLK;

interface

uses
  SysUtils, Classes, UExportCommun;

type
  TEncodeSYLK = class(TInfoEncodeFichier)
  private
    fs: TMemoryStream;
    fsSYLK: TFormatSettings;
    FCurrentLine, FCurrentColumn: Integer;
    procedure WriteString(s: string);
    procedure ProcessData(Data: TData; var c: Integer);
  public
    constructor Create; override;
    destructor Destroy; override;

    function FormatDate(const Value: string): string; override;
    function FormatDateTime(const Value: string): string; override;
    function FormatNumber(const Value: string): string; override;
    function FormatString(const Value: string): string; override;

    procedure WriteHeaderFile; override;
    procedure WriteHeaderDataset; override;
    procedure WriteData(Data: TData); override;
    procedure WriteFooterFile; override;

    function IsEmpty: Boolean; override;
    procedure SaveToStream(Stream: TStream; Encoding: TEncoding); override;
  end;

implementation

uses
  UConvert;

const
  fmtCELL = 'C;Y%d;X%d;K%s';

  { TEncodeSYLK }

constructor TEncodeSYLK.Create;
begin
  inherited;
  fs := TMemoryStream.Create;
  fsSYLK.ShortDateFormat := '';
  fsSYLK.DecimalSeparator := '.';
  WriteBOM := False;
end;

destructor TEncodeSYLK.Destroy;
begin
  fs.Free;
  inherited;
end;

function TEncodeSYLK.FormatDate(const Value: string): string;
begin
  Result := Format('%d', [Trunc(StrToDate(Value, InputFormatSettings))], fsSYLK);
end;

function TEncodeSYLK.FormatDateTime(const Value: string): string;
begin
  Result := Format('%f', [StrToDateTime(Value, InputFormatSettings)], fsSYLK);
end;

function TEncodeSYLK.FormatNumber(const Value: string): string;
begin
  Result := FormatCurr('0.##', StrToCurr(Value, InputFormatSettings), fsSYLK);
end;

function TEncodeSYLK.FormatString(const Value: string): string;
begin
  Result := AdjustLineBreaks(Value);
  Result := StringReplace(Result, sLineBreak, Chr(27) + ' :', [rfReplaceAll]);
  Result := StringReplace(Result, ';', ';;', [rfReplaceAll]);
  Result := Format('"%s"', [Result], fsSYLK);
end;

function TEncodeSYLK.IsEmpty: Boolean;
begin
  if TConvertOptions.AddHeaders then
    Result := FCurrentLine = 1
  else
    Result := FCurrentLine = 0;
end;

procedure TEncodeSYLK.SaveToStream(Stream: TStream; Encoding: TEncoding);
begin
  fs.SaveToStream(Stream);
end;

procedure TEncodeSYLK.WriteFooterFile;
begin
  inherited;
  WriteString('E'); // E = fin du fichier
end;

procedure TEncodeSYLK.WriteHeaderFile;
begin
  inherited;
  fs.Size := 0;
  WriteString('ID;P'); // ID = fichier sylk; P = généré par un programme
  WriteString('P;PGeneral'); // P = format de données ; PGeneral = index P0 format générique
  WriteString('P;P0.00'); // P = format de données ; P0.00 = index P1 format numérique 2 décimales
  WriteString('P;P0'); // P = format de données ; P0 = index P2 format entier
  WriteString('P;P' + StringReplace(OutputFormatSettings.ShortDateFormat, '-', '\-', [rfReplaceAll])); // P = format de données ; Pxxx = index P3 format date
  WriteString('P;P' + StringReplace(OutputFormatSettings.ShortDateFormat, '-', '\-', [rfReplaceAll]) + '\ ' + OutputFormatSettings.LongTimeFormat);
  // P = format de données ; Pxxx = index P4 format date/heure
  WriteString('F;P0');
  FCurrentLine := 0;
end;

procedure TEncodeSYLK.WriteHeaderDataset;
var
  c: Integer;
  t: char;
  i: Integer;
begin
  inherited;

  c := 1;
  for i := 0 to Pred(Headers.Count) do
  begin
    if TConvertOptions.DataTypes.TryGetValue(Headers[i], t) then
      case t of
        'n': // ftFloat, ftCurrency:
          WriteString('F;P1;C' + IntToStr(c));
        'i': // ftInteger:
          WriteString('F;P2;C' + IntToStr(c));
        'd': // ftDate:
          WriteString('F;P3;C' + IntToStr(c));
        't': // ftTimestamp:
          WriteString('F;P4;C' + IntToStr(c));
      end;
    Inc(c);
  end;

  WriteString('F;P0;FG0C;R1');

  if TConvertOptions.AddHeaders then
  begin
    c := 1;
    Inc(FCurrentLine);
    for i := 0 to Pred(Headers.Count) do
    begin
      WriteString(Format(fmtCELL, [FCurrentLine, c, FormatString(Headers[i])]));
      Inc(c);
    end;
  end;
end;

procedure TEncodeSYLK.WriteData(Data: TData);
begin
  inherited;

  FCurrentColumn := 1;
  Inc(FCurrentLine);
  ProcessData(Data, FCurrentColumn);
end;

procedure TEncodeSYLK.WriteString(s: string);
var
  b: TArray<Byte>;
begin
  s := s + #13#10;
  b := TConvertOptions.OutputEncoding.GetBytes(s);
  fs.Write(b, Length(b));
end;

procedure TEncodeSYLK.ProcessData(Data: TData; var c: Integer);
var
  i: Integer;
  s, h: string;
begin
  for i := 0 to Pred(Headers.Count) do
  begin
    h := Headers[i];
    Data.TryGetValue(h, s);
    WriteString(Format(fmtCELL, [FCurrentLine, c, FormatValue(h, s)], fsSYLK));
    Inc(c);
  end;
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('sylk', TEncodeSYLK);

end.
