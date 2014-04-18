unit UExportXML;

interface

uses
  SysUtils, Classes, UExportCommun, JclSimpleXML, IBQuery;

type
  TEncodeXML = class(TInfoEncodeFichier)
  private
    FNode: TJclSimpleXMLElem;
    FxmlFichier: TJclSimpleXML;
  public
    procedure WriteHeaderFile; override;
    procedure WriteData(Data: TData); override;

    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;

    property Node: TJclSimpleXMLElem read FNode;
  end;

implementation

uses
  UConvert;

{ TEncodeXML }

constructor TEncodeXML.Create(LogCallBack: TLogEvent);
begin
  inherited Create(LogCallBack);
  FFlatBuild := False;
  Extension := '.xml';
  FxmlFichier := TJclSimpleXML.Create;
  FxmlFichier.Options := FxmlFichier.Options + [sxoAutoCreate] - [sxoAutoIndent];
end;

destructor TEncodeXML.Destroy;
begin
  FxmlFichier.Free;
  inherited;
end;

function TEncodeXML.SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean;
begin
  Result := FxmlFichier.Root.ItemCount > 0;
  if Result then
    FxmlFichier.SaveToStream(Stream);
end;

procedure TEncodeXML.WriteHeaderFile;
begin
  inherited;
  FxmlFichier.Root.Clear;
  FxmlFichier.Root.Name := TConvertOptions.XMLRootName;
  FNode := nil;
end;

procedure TEncodeXML.WriteData(Data: TData);
var
  i: Integer;
  s: string;
begin
  inherited;
  FNode := FxmlFichier.Root.Items.Add(TConvertOptions.XMLRecordName);
  for i := 0 to Pred(Headers.Count) do
  begin
    s := Data[i];
    if Pos('<', s) + Pos('>', s) > 0 then
      FNode.Items.ItemNamed[Headers[i]].Items.AddCData(Headers[i], Data[i])
    else
      FNode.Items.ItemNamed[Headers[i]].Items.AddText(Headers[i], Data[i]);
  end;
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('xml', TEncodeXML);

end.
