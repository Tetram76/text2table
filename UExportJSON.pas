unit UExportJSON;

interface

uses
  SysUtils, Classes, UExportCommun, superobject;

type
  TEncodeJSON = class(TInfoEncodeFichier)
  private
    json: ISuperObject;
  public
    constructor Create; override;

    function FormatInteger(const Value: string): string; override;
    function FormatNumber(const Value: string): string; override;

    procedure WriteData(Data: TData); override;

    function IsEmpty: Boolean; override;
    procedure SaveToStream(Stream: TStream; Encoding: TEncoding); override;
  end;

implementation

uses
  System.Generics.Collections;

{ TEncodeJSON }

constructor TEncodeJSON.Create;
begin
  inherited;
  json := SA([]);
end;

function TEncodeJSON.FormatInteger(const Value: string): string;
begin
  Result := SO(SO(Value).AsInteger).AsString;
end;

function TEncodeJSON.FormatNumber(const Value: string): string;
begin
  Result := SO(SO(Value).AsDouble).AsString;
end;

function TEncodeJSON.IsEmpty: Boolean;
begin
  Result := json.AsArray.Length = 0;
end;

procedure TEncodeJSON.SaveToStream(Stream: TStream; Encoding: TEncoding);
begin
  json.SaveTo(Stream);
end;

procedure TEncodeJSON.WriteData(Data: TData);
var
  p: TPair<string, string>;
  json_sub: ISuperObject;
  s: string;
begin
  json_sub := SO();
  for p in Data do
  begin
    s := FormatValue(p.Key, p.Value);
    if s <> '' then
      json_sub.s[p.Key] := s;
  end;
  json.AsArray.Add(json_sub);
end;

initialization

TInfoEncodeFichier.RegisterOutputFormat('json', TEncodeJSON);

end.
