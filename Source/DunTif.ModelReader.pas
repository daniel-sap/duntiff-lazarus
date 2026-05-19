unit DunTif.ModelReader;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  DunTif.Model;

type
  TDunTifModelReader = class
  public
    class function LoadFromStream(AStream: TStream): TDunTifDocument; static;
    class function LoadFromFile(const AFileName: string): TDunTifDocument; static;
  end;

implementation

uses
  DunTif.TiffTypes,
  DunTif.TiffParser,
  DunTif.DecodeBaseline,
  DunTif.DecodePackBits,
  DunTif.DecodeLzw,
  DunTif.DecodeDeflate,
  DunTif.DecodeJpeg;

function FormatTiffReadFailure(const E: Exception): string;
begin
  Result := E.Message;
end;

class function TDunTifModelReader.LoadFromStream(AStream: TStream): TDunTifDocument;
var
  frame: TTiffFrame;
  bitsText: string;
  i: Integer;
  md: TDunTifMetadata;
begin
  if AStream = nil then
    raise EDunTifError.Create('DunTif: stream is nil');

  Result := TDunTifDocument.Create;
  try
    frame := TDunTifTiffParser.ParseSingleFrame(AStream);
    case frame.Compression of
      Ord(tcNone):
        TDunTifBaselineDecoder.DecodeToFPImage(AStream, frame, Result.Image);
      Ord(tcPackBits):
        TDunTifPackBitsDecoder.DecodeToFPImage(AStream, frame, Result.Image);
      Ord(tcLZW):
        TDunTifLzwDecoder.DecodeToFPImage(AStream, frame, Result.Image);
      Ord(tcDeflateAdobe), Ord(tcDeflate):
        TDunTifDeflateDecoder.DecodeToFPImage(AStream, frame, Result.Image);
      Ord(tcJpeg):
        TDunTifJpegDecoder.DecodeToFPImage(AStream, frame, Result.Image);
    else
      raise EDunTifError.CreateFmt(
        'DunTif: unsupported compression %d (supports None=1, LZW=5, JPEG=7, Deflate=8/32946, PackBits=32773)',
        [frame.Compression]);
    end;

    bitsText := '';
    for i := 0 to High(frame.BitsPerSample) do
    begin
      if bitsText <> '' then
        bitsText := bitsText + ',';
      bitsText := bitsText + IntToStr(frame.BitsPerSample[i]);
    end;

    md.Compression := frame.Compression;
    md.Photometric := frame.Photometric;
    md.SamplesPerPixel := frame.SamplesPerPixel;
    md.BitsPerSample := bitsText;
    Result.Metadata := md;
    Result.MarkReadyAfterLoad;
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDunTifError.CreateFmt('DunTif: failed to read TIFF stream (%s)', [FormatTiffReadFailure(E)]);
    end;
  end;
end;

class function TDunTifModelReader.LoadFromFile(const AFileName: string): TDunTifDocument;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(fs);
  finally
    fs.Free;
  end;
end;

end.
