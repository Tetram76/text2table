unit UExportXML;

interface

uses
  SysUtils, Classes, UExportCommun, JclSimpleXML, IBQuery;

type
  TEncodeXML = class(TInfoEncodeFichier)
  private
    FParentNode, FChildNode: TJclSimpleXMLElem;
    FxmlFichier: TJclSimpleXML;
    FMasterNodeName: string;
    FRootName: string;
    FChildNodeName: string;
    FChildrenNodeName: string;
  public
    procedure WriteHeaderFile; override;
    procedure WriteMasterData(IBMaster, IBDetail: TIBQuery); override;
    procedure WriteDetailData(IBMaster, IBDetail: TIBQuery); override;

    constructor Create(LogCallBack: TLogEvent); override;
    destructor Destroy; override;

    function SaveToStream(Stream: TStream; Encoding: TEncoding): Boolean; override;

    property RootName: string read FRootName write FRootName;
    property MasterNodeName: string read FMasterNodeName write FMasterNodeName;
    property ChildrenNodeName: string read FChildrenNodeName write FChildrenNodeName;
    property ChildNodeName: string read FChildNodeName write FChildNodeName;

    property ParentNode: TJclSimpleXMLElem read FParentNode;
    property ChildNode: TJclSimpleXMLElem read FChildNode;
  end;

implementation

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
  Result := FxmlFichier.Root.ItemCount > 1;
  if Result then FxmlFichier.SaveToStream(Stream);
end;

procedure TEncodeXML.WriteDetailData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;
  if Assigned(FParentNode) then
    FChildNode := FParentNode.Items.ItemNamed[FChildrenNodeName].Items.Add(FChildNodeName);
end;

procedure TEncodeXML.WriteHeaderFile;
begin
  inherited;
  FxmlFichier.Root.Clear;
  FxmlFichier.Root.Name := FRootName;
  FParentNode := nil;
  FChildNode := nil;
end;

procedure TEncodeXML.WriteMasterData(IBMaster, IBDetail: TIBQuery);
begin
  inherited;
  FParentNode := FxmlFichier.Root.Items.Add(FMasterNodeName);
end;

initialization
  TInfoEncodeFichier.RegisterOutputFormat('xml', TEncodeXML);

end.


