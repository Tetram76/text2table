unit UExportXML;

interface

uses
  SysUtils, Classes, UExportCommun, JclSimpleXML;

type
  TEncodeXML = class(TInfoEncodeFichier)
  private
    FNode: TJclSimpleXMLElem;
    FxmlFichier: TJclSimpleXML;
  public
    procedure WriteHeaderFile; override;
    procedure WriteData(Data: TData); override;

    constructor Create; override;
    destructor Destroy; override;

    function IsEmpty: Boolean; override;
    procedure SaveToStream(Stream: TStream; Encoding: TEncoding); override;

    property Node: TJclSimpleXMLElem read FNode;
  end;

implementation

uses
  UConvert, JclStreams, System.Generics.Collections;

{ TEncodeXML }

constructor TEncodeXML.Create;
begin
  inherited;
  FFlatBuild := False;
  FxmlFichier := TJclSimpleXML.Create;
  FxmlFichier.Options := FxmlFichier.Options + [sxoAutoCreate] - [sxoAutoIndent];
end;

destructor TEncodeXML.Destroy;
begin
  FxmlFichier.Free;
  inherited;
end;

function TEncodeXML.IsEmpty: Boolean;
begin
  Result := FxmlFichier.Root.ItemCount = 0;
end;

procedure TEncodeXML.SaveToStream(Stream: TStream; Encoding: TEncoding);
begin
  if Encoding = TEncoding.UTF8 then
    FxmlFichier.SaveToStream(Stream, seUTF8)
  else
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
  p: TPair<string, string>;
  s: string;
begin
  inherited;
  FNode := FxmlFichier.Root.Items.Add(TConvertOptions.XMLRecordName);
  for p in Data do
  begin
    s := FormatValue(p.Key, p.Value);

    if s <> '' then
    begin
      // if Pos('<', s) + Pos('>', s) > 0 then
      // FNode.Items.ItemNamed[p.Key].Items.AddCData(p.Key, s)
      // else
      FNode.Items.ItemNamed[p.Key].Items.AddText(p.Key, s);
    end;
  end;
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('xml', TEncodeXML);

end.
