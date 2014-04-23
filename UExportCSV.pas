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
    constructor Create; override;
    destructor Destroy; override;

    function FormatString(const Value: string): string; override;

    procedure WriteHeaderDataset; override;
    procedure WriteData(Data: TData); override;

    function IsEmpty: Boolean; override;
    procedure SaveToStream(Stream: TStream; Encoding: TEncoding); override;

    property NewLineStr: string read FNewLineStr write FNewLineStr;
  end;

implementation

uses
  UConvert;

{ TEncodeCSV }

constructor TEncodeCSV.Create;
begin
  inherited;
  FNewLineStr := sLineBreak;
  FCurrentLine := 0;
  fsData := TMemoryStream.Create;
end;

destructor TEncodeCSV.Destroy;
begin
  fsData.Free;
  inherited;
end;

function TEncodeCSV.FormatString(const Value: string): string;
begin
  Result := AdjustLineBreaks(Value);
  Result := StringReplace(Result, sLineBreak, FNewLineStr, [rfReplaceAll]);
end;

function TEncodeCSV.IsEmpty: Boolean;
begin
  if TConvertOptions.AddHeaders then
    Result := FCurrentLine = 1
  else
    Result := FCurrentLine = 0;
end;

procedure TEncodeCSV.ProcessData(fs: TStream; Data: TData);
var
  i: Integer;
  s, h: string;
begin
  for i := 0 to Pred(Headers.Count) do
  begin
    h := Headers[i];

    if i > 0 then
      WriteRawString(fs, ';');

    Data.TryGetValue(h, s);
    WriteString(fs, FormatValue(h, s));
  end;
end;

procedure TEncodeCSV.SaveToStream(Stream: TStream; Encoding: TEncoding);
begin
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
  b := TConvertOptions.OutputEncoding.GetBytes(s);
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
