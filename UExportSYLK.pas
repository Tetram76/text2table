unit UExportSYLK;

interface

uses
  SysUtils, Classes, UExportCommun, IBQuery, DB;

type
  TEncodeSYLK = class(TInfoEncodeFichier)
  private
    fs: TMemoryStream;
    fsSYLK: TFormatSettings;
    FCurrentLine, FCurrentColumn: Integer;
    procedure WriteString(s: string);
    procedure ProcessData(Data: TData; var c: Integer);
  public
    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;

    procedure WriteHeaderFile; override;
    procedure WriteHeaderDataset; override;
    procedure WriteData(Data: TData); override;
    procedure WriteFooterFile; override;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;
  end;

implementation

uses
  UConvert;

{ TEncodeSYLK }

constructor TEncodeSYLK.Create(LogCallBack: TLogEvent);
begin
  inherited;
  Extension := '.slk';
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

function TEncodeSYLK.SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean;
begin
  Result := FCurrentLine > 0;
  if Result then
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
  t: string;
  i: Integer;
begin
  inherited;

  c := 1;
  for i := 0 to Pred(Headers.Count) do
  begin
    if TConvertOptions.DataTypes.TryGetValue(Headers[i], t) then
      case t[1] of
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
      WriteString(Format('C;Y%d;X%d;K"%s"', [FCurrentLine, c, Headers[i]]));
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
  s, t: string;
begin
  for i := 0 to Pred(Data.Count) do
  begin
    if Data[i] <> '' then
    begin
      TConvertOptions.DataTypes.TryGetValue(Headers[i], t);
      if t = '' then
        t := '*';

      case t[1] of
        'd':
          s := Format('C;Y%d;X%d;K%d', [FCurrentLine, c, Trunc(StrToDate(Data[i], InputFormatSettings))], fsSYLK);
        't':
          s := Format('C;Y%d;X%d;K%f', [FCurrentLine, c, StrToDateTime(Data[i], InputFormatSettings)], fsSYLK);
        'n':
          s := Format('C;Y%d;X%d;K%s', [FCurrentLine, c, FormatCurr('0.##', StrToCurr(Data[i], InputFormatSettings), fsSYLK)]);
        'i':
          s := Format('C;Y%d;X%d;K%s', [FCurrentLine, c, Data[i]], fsSYLK);
      else
        begin
          s := AdjustLineBreaks(Data[i]);
          s := StringReplace(s, sLineBreak, Chr(27) + ' :', [rfReplaceAll]);
          s := StringReplace(s, ';', ';;', [rfReplaceAll]);
          s := Format('C;Y%d;X%d;K"%s"', [FCurrentLine, c, s], fsSYLK);
        end;
      end;
      WriteString(s);
    end;

    Inc(c);
  end;
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('sylk', TEncodeSYLK);

end.
