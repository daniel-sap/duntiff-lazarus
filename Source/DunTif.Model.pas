unit DunTif.Model;

{$mode delphi}

interface

uses
  FPImage, SysUtils,
  DunTif.TiffTypes;

type
  EDunTifError = class(Exception);
  EDunTifNotInitialized = class(EDunTifError);

  { TDunTifDocument — растерен модел за един TIFF кадър (v1: една страница). }

  TDunTifPixelFormat = (
    pfGray8,
    pfRGB8
  );

  TDunTifMetadata = record
    Compression: Word;
    Photometric: Word;
    SamplesPerPixel: Word;
    BitsPerSample: string;
  end;

  TDunTifDocument = class
  private
    FImage: TFPMemoryImage;
    FMetadata: TDunTifMetadata;
    FReady: Boolean;
    FPixelFormat: TDunTifPixelFormat;
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure RequireReady(const AOperation: string);
    procedure ApplyDefaultMetadata(AFormat: TDunTifPixelFormat);
    function NormalizeFillColor(const AColor: TFPColor): TFPColor;
    procedure PixelFormatFromMetadata(const md: TDunTifMetadata; out AFormat: TDunTifPixelFormat);
  public
    constructor Create;
    destructor Destroy; override;

    { Нов празен документ: не е Ready докато не се извика Initialize. }
    procedure Initialize(AWidth, AHeight: Integer; AFormat: TDunTifPixelFormat;
      const AFillColor: TFPColor); overload;
    procedure Initialize(AWidth, AHeight: Integer; AFormat: TDunTifPixelFormat); overload;

    { След успешно зареждане от TIFF (само ModelReader). }
    procedure MarkReadyAfterLoad;

    procedure Fill(const AColor: TFPColor);

    property IsReady: Boolean read FReady;
    property PixelFormat: TDunTifPixelFormat read FPixelFormat;
    property Image: TFPMemoryImage read FImage;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property Metadata: TDunTifMetadata read FMetadata write FMetadata;
  end;

implementation

function DefaultBlack: TFPColor;
begin
  Result.alpha := $ffff;
  Result.red := 0;
  Result.green := 0;
  Result.blue := 0;
end;

{ TDunTifDocument }

constructor TDunTifDocument.Create;
begin
  inherited Create;
  FImage := TFPMemoryImage.Create(0, 0);
  FReady := False;
end;

destructor TDunTifDocument.Destroy;
begin
  FreeAndNil(FImage);
  inherited Destroy;
end;

procedure TDunTifDocument.RequireReady(const AOperation: string);
begin
  if not FReady then
    raise EDunTifNotInitialized.CreateFmt(
      'DunTif: cannot %s — document not initialized (call Initialize or load a TIFF first)',
      [AOperation]);
end;

procedure TDunTifDocument.ApplyDefaultMetadata(AFormat: TDunTifPixelFormat);
begin
  FMetadata.Compression := Ord(tcNone);
  case AFormat of
    pfGray8:
      begin
        FMetadata.Photometric := Ord(tpBlackIsZero);
        FMetadata.SamplesPerPixel := 1;
        FMetadata.BitsPerSample := '8';
      end;
    pfRGB8:
      begin
        FMetadata.Photometric := Ord(tpRGB);
        FMetadata.SamplesPerPixel := 3;
        FMetadata.BitsPerSample := '8,8,8';
      end;
  end;
end;

function TDunTifDocument.NormalizeFillColor(const AColor: TFPColor): TFPColor;
var
  g: Integer;
begin
  Result := AColor;
  if FPixelFormat <> pfGray8 then
    Exit;
  g := (77 * (AColor.red shr 8) + 150 * (AColor.green shr 8) + 29 * (AColor.blue shr 8)) div 256;
  Result.red := g * 257;
  Result.green := Result.red;
  Result.blue := Result.red;
  if Result.alpha = 0 then
    Result.alpha := $ffff;
end;

procedure TDunTifDocument.PixelFormatFromMetadata(const md: TDunTifMetadata;
  out AFormat: TDunTifPixelFormat);
begin
  case md.SamplesPerPixel of
    1: AFormat := pfGray8;
    3: AFormat := pfRGB8;
  else
    raise EDunTifError.CreateFmt(
      'DunTif: unsupported SamplesPerPixel %d for document model (supports 1 or 3)',
      [md.SamplesPerPixel]);
  end;
end;

procedure TDunTifDocument.Initialize(AWidth, AHeight: Integer; AFormat: TDunTifPixelFormat;
  const AFillColor: TFPColor);
begin
  if FReady then
    raise EDunTifError.Create('DunTif: document already initialized (create a new TDunTifDocument)');
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EDunTifError.Create('DunTif: Initialize requires positive width and height');

  FPixelFormat := AFormat;
  ApplyDefaultMetadata(AFormat);
  FImage.SetSize(AWidth, AHeight);
  FReady := True;
  Fill(AFillColor);
end;

procedure TDunTifDocument.Initialize(AWidth, AHeight: Integer; AFormat: TDunTifPixelFormat);
begin
  Initialize(AWidth, AHeight, AFormat, DefaultBlack);
end;

procedure TDunTifDocument.MarkReadyAfterLoad;
begin
  if FReady then
    raise EDunTifError.Create('DunTif: document already marked ready');
  if (FImage = nil) or (FImage.Width <= 0) or (FImage.Height <= 0) then
    raise EDunTifError.Create('DunTif: cannot mark ready — image has no pixels');
  PixelFormatFromMetadata(FMetadata, FPixelFormat);
  FReady := True;
end;

procedure TDunTifDocument.Fill(const AColor: TFPColor);
var
  x, y: Integer;
  c: TFPColor;
begin
  RequireReady('fill image');
  c := NormalizeFillColor(AColor);
  for y := 0 to FImage.Height - 1 do
    for x := 0 to FImage.Width - 1 do
      FImage.Colors[x, y] := c;
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
