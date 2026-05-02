unit DunTif.Model;

{$mode delphi}

interface

uses
  FPImage, SysUtils;

type
  EDunTifError = class(Exception);

  { TDunTifDocument — растерен модел за един TIFF кадър (v1: една страница). }

  TDunTifDocument = class
  private
    FImage: TFPMemoryImage;
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    property Image: TFPMemoryImage read FImage;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

implementation

{ TDunTifDocument }

constructor TDunTifDocument.Create;
begin
  inherited Create;
  FImage := TFPMemoryImage.Create(0, 0);
end;

destructor TDunTifDocument.Destroy;
begin
  FreeAndNil(FImage);
  inherited Destroy;
end;

function TDunTifDocument.GetWidth: Integer;
begin
  if FImage <> nil then
    Result := FImage.Width
  else
    Result := 0;
end;

function TDunTifDocument.GetHeight: Integer;
begin
  if FImage <> nil then
    Result := FImage.Height
  else
    Result := 0;
end;

end.
