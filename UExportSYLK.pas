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
    procedure ProcessData(qry: TIBQuery; var c: Integer);
  public
    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;

    procedure WriteHeaderFile; override;
    procedure WriteHeaderDataset(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteMasterData(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteDetailData(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteFooterFile; override;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;
  end;

implementation

{ TEncodeSYLK }

constructor TEncodeSYLK.Create(LogCallBack: TLogEvent);
begin
  inherited;
  Extension := '.slk';
  fs := TMemoryStream.Create;
  fsSYLK.ShortDateFormat := '';
  fsSYLK.DecimalSeparator := '.';
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
  WriteString('P;P' + StringReplace(FormatSettings.ShortDateFormat, '-', '\-', [rfReplaceAll])); // P = format de données ; Pxxx = index P3 format date
  WriteString('P;P' + StringReplace(FormatSettings.ShortDateFormat, '-', '\-', [rfReplaceAll]) + '\ ' + FormatSettings.LongTimeFormat);
  // P = format de données ; Pxxx = index P4 format date/heure
  WriteString('F;P0');
  FCurrentLine := 0;
end;

procedure TEncodeSYLK.WriteHeaderDataset;
var
  c: Integer;

  procedure ProcessHeaderType(qry: TIBQuery);
  var
    i: Integer;
  begin
    for i := 0 to Pred(qry.Fields.Count) do
    begin
      case qry.Fields[i].DataType of
        ftFloat, ftCurrency:
          WriteString('F;P1;C' + IntToStr(c));
        ftInteger:
          WriteString('F;P2;C' + IntToStr(c));
        ftDate:
          WriteString('F;P3;C' + IntToStr(c));
        ftTimestamp:
          WriteString('F;P4;C' + IntToStr(c));
      end;
      Inc(c);
    end;
    WriteString('F;P0;FG0C;R1');
  end;

  procedure ProcessHeaderName(qry: TIBQuery);
  var
    i: Integer;
  begin
    for i := 0 to Pred(qry.Fields.Count) do
    begin
      WriteString(Format('C;Y%d;X%d;K"%s"', [FCurrentLine, c, qry.Fields[i].DisplayName]));
      Inc(c);
    end;
  end;

begin
  inherited;

  c := 1;
  if Assigned(IBMaster) then
    ProcessHeaderType(IBMaster);
  if Assigned(IBDetail) then
    ProcessHeaderType(IBDetail);

  c := 1;
  Inc(FCurrentLine);
  if Assigned(IBMaster) then
    ProcessHeaderName(IBMaster);
  if Assigned(IBDetail) then
    ProcessHeaderName(IBDetail);
end;

procedure TEncodeSYLK.WriteMasterData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;

  FCurrentColumn := 1;
  Inc(FCurrentLine);
  ProcessData(IBMaster, FCurrentColumn);
end;

procedure TEncodeSYLK.WriteDetailData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;

  ProcessData(IBDetail, FCurrentColumn);
end;

procedure TEncodeSYLK.WriteString(s: string);
begin
  s := s + #13#10;
  fs.Write(s[1], Length(s));
end;

procedure TEncodeSYLK.ProcessData(qry: TIBQuery; var c: Integer);
var
  i: Integer;
  s: string;
begin
  for i := 0 to Pred(qry.Fields.Count) do
  begin
    if not qry.Fields[i].IsNull then
    begin
      case qry.Fields[i].DataType of
        ftDate:
          s := Format('C;Y%d;X%d;K%d', [FCurrentLine, c, Trunc(qry.Fields[i].AsDateTime)], fsSYLK);
        ftTimestamp:
          s := Format('C;Y%d;X%d;K%f', [FCurrentLine, c, qry.Fields[i].AsDateTime], fsSYLK);
        ftFloat, ftCurrency:
          s := Format('C;Y%d;X%d;K%s', [FCurrentLine, c, FormatCurr('0.##', qry.Fields[i].AsCurrency, fsSYLK)]);
        ftInteger:
          s := Format('C;Y%d;X%d;K%s', [FCurrentLine, c, qry.Fields[i].AsString], fsSYLK);
      else
        begin
          s := AdjustLineBreaks(qry.Fields[i].AsString);
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
