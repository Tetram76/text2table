unit UExportCSV;

interface

uses
  SysUtils, Classes, UExportCommun, IBQuery, DB;

type
  TEncodeCSV = class(TInfoEncodeFichier)
  private
    fsMaster, fsDetail: TMemoryStream;
    FCurrentLineMaster, FCurrentLineChild: Integer;
    FAddHeaders: Boolean;
    FNewLineStr: string;
    procedure WriteRawString(fs: TStream; s: string);
    procedure WriteString(fs: TStream; s: string);
    procedure ProcessData(fs: TStream; qry: TIBQuery);
  public
    constructor Create(LogCallBack: TLogEvent); override;

    procedure WriteHeaderDataset(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteMasterData(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteDetailData(IBMaster, IBDetail: TIBQuery); override;

    property AddHeaders: Boolean read FAddHeaders write FAddHeaders;
    property NewLineStr: string read FNewLineStr write FNewLineStr;
  end;

  TEncodeSimpleCSV = class(TEncodeCSV)
  public
    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;
    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;
  end;

  TEncodeDoubleCSV = class(TEncodeCSV)
  public
    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;
    function SaveToFile(FileNameMaster, FileNameDetail: string): Boolean; reintroduce;
  end;

implementation

{ TEncodeCSV }

constructor TEncodeCSV.Create(LogCallBack: TLogEvent);
begin
  inherited;
  Extension := '.csv';
  FNewLineStr := sLineBreak;
  FAddHeaders := True;
  FCurrentLineMaster := 0;
  FCurrentLineChild := 0;
end;

procedure TEncodeCSV.ProcessData(fs: TStream; qry: TIBQuery);
var
  i: Integer;
  s: string;
begin
  for i := 0 to Pred(qry.Fields.Count) do
  begin
    if i > 0 then
      WriteRawString(fs, ';');
    if not qry.Fields[i].IsNull then
    begin
      case qry.Fields[i].DataType of
        ftDate:
          s := FormatDateTime(FormatSettings.ShortDateFormat, Trunc(qry.Fields[i].AsDateTime), FormatSettings);
        ftDateTime, ftTimestamp:
          s := FormatDateTime(FormatSettings.ShortDateFormat, Trunc(qry.Fields[i].AsDateTime), FormatSettings) + ' ' +
            FormatDateTime(FormatSettings.ShortTimeFormat, Trunc(qry.Fields[i].AsDateTime), FormatSettings);
        ftFloat, ftCurrency:
          s := Format('%s', [FormatCurr('0.##', qry.Fields[i].AsCurrency, FormatSettings)]);
        ftInteger:
          s := IntToStr(qry.Fields[i].AsInteger);
      else
        begin
          s := AdjustLineBreaks(qry.Fields[i].AsString);
          s := StringReplace(s, sLineBreak, FNewLineStr, [rfReplaceAll]);
        end;
      end;
      WriteString(fs, s);
    end;
  end;
end;

procedure TEncodeCSV.WriteDetailData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;

  Inc(FCurrentLineChild);
  if fsDetail = fsMaster then
    WriteRawString(fsDetail, ';');
  ProcessData(fsDetail, IBDetail);
  WriteRawString(fsDetail, #13#10);
end;

procedure TEncodeCSV.WriteHeaderDataset(IBMaster, IBDetail: TIBQuery);

  procedure ProcessHeaderName(fs: TStream; qry: TIBQuery);
  var
    i: Integer;
  begin
    for i := 0 to Pred(qry.Fields.Count) do
    begin
      if i > 0 then
        WriteRawString(fs, ';');
      WriteString(fs, qry.Fields[i].DisplayName);
    end;
  end;

begin
  inherited;

  if not FAddHeaders then
    Exit;

  if Assigned(IBMaster) then
    ProcessHeaderName(fsMaster, IBMaster);
  if Assigned(IBDetail) then
  begin
    if Assigned(IBMaster) and (fsMaster = fsDetail) then
      WriteRawString(fsDetail, ';');
    ProcessHeaderName(fsDetail, IBDetail);
  end;
  WriteRawString(fsMaster, #13#10);
  if fsMaster <> fsDetail then
    WriteRawString(fsDetail, #13#10);
end;

procedure TEncodeCSV.WriteMasterData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;

  Inc(FCurrentLineMaster);
  ProcessData(fsMaster, IBMaster);
  if fsDetail <> fsMaster then
    WriteRawString(fsMaster, #13#10);
end;

procedure TEncodeCSV.WriteRawString(fs: TStream; s: string);
begin
  fs.Write(s[1], Length(s));
end;

procedure TEncodeCSV.WriteString(fs: TStream; s: string);
begin
  s := StringReplace(s, '"', '""', [rfReplaceAll]);
  if Pos('"', s) + Pos(';', s) + Pos(#13, s) + Pos(#10, s) + Pos(#9, s) > 0 then
    s := '"' + s + '"';
  WriteRawString(fs, s);
end;

{ TEncodeDoubleCSV }

constructor TEncodeDoubleCSV.Create(LogCallBack: TLogEvent);
begin
  inherited;
  FFlatBuild := False; // on n'a pas besoin de réécrire le master à chaque detail
  fsMaster := TMemoryStream.Create;
  fsDetail := TMemoryStream.Create;
end;

destructor TEncodeDoubleCSV.Destroy;
begin
  fsMaster.Free;
  fsDetail.Free;
  inherited;
end;

function TEncodeDoubleCSV.SaveToFile(FileNameMaster, FileNameDetail: string): Boolean;
begin
  if ExtractFileExt(FileNameMaster) = '' then
    FileNameMaster := FileNameMaster + Extension;
  if ExtractFileExt(FileNameDetail) = '' then
    FileNameDetail := FileNameDetail + Extension;
  Result := FCurrentLineMaster > 0;
  if Result then
  begin
    fsMaster.SaveToFile(FileNameMaster);
    fsDetail.SaveToFile(FileNameDetail);
  end;
end;

{ TEncodeSimpleCSV }

constructor TEncodeSimpleCSV.Create(LogCallBack: TLogEvent);
begin
  inherited;
  fsMaster := TMemoryStream.Create;
  fsDetail := fsMaster;
end;

destructor TEncodeSimpleCSV.Destroy;
begin
  fsMaster.Free;
  inherited;
end;

function TEncodeSimpleCSV.SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean;
begin
  Result := FCurrentLineMaster > 0;
  // if ExtractFileExt(FileName) = '' then FileName := FileName + Extension;
  if Result then
    fsMaster.SaveToStream(Stream);
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('csv', TEncodeCSV);

end.
