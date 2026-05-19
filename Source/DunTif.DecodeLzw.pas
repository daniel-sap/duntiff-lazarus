unit DunTif.DecodeLzw;

{$mode delphi}

interface

uses
  SysUtils, Classes,
  FPImage,
  DunTif.TiffTypes;

type
  TDunTifLzwDecoder = class
  public
    class procedure DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage); static;
  end;

implementation

uses
  DunTif.BinReader,
  DunTif.DecodeRaster8,
  DunTif.DecodePredictor,
  DunTif.TiffLzw;

class procedure TDunTifLzwDecoder.DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage);
var
  r: TDunTifBinReader;
  stripIdx: Integer;
  rowsThisStrip: Integer;
  rowStart: Integer;
  remainingRows: Integer;
  bytesPerPixel: Integer;
  needBytes: Int64;
  compressed: TBytes;
  raw: TBytes;
begin
  if (AStream = nil) or (AOut = nil) then
    Exit;

  if (Frame.Width = 0) or (Frame.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid frame dimensions');

  if not DunTifStripSamplesPerPixelSupported(Frame.SamplesPerPixel) then
    raise EDunTifParseError.CreateFmt(
      'DunTif: unsupported SamplesPerPixel %d (LZW decoder)', [Frame.SamplesPerPixel]);

  bytesPerPixel := Frame.SamplesPerPixel;
  AOut.SetSize(Frame.Width, Frame.Height);

  r := TDunTifBinReader.Create(AStream, Frame.Endian);
  try
    rowStart := 0;
    for stripIdx := 0 to High(Frame.StripOffsets) do
    begin
      if rowStart >= Integer(Frame.Height) then
        Break;

      remainingRows := Integer(Frame.Height) - rowStart;
      if Frame.RowsPerStrip > Cardinal(High(Integer)) then
        rowsThisStrip := remainingRows
      else
        rowsThisStrip := Integer(Frame.RowsPerStrip);
      if rowsThisStrip > remainingRows then
        rowsThisStrip := remainingRows;

      needBytes := Int64(rowsThisStrip) * Int64(Frame.Width) * bytesPerPixel;
      if needBytes < 0 then
        raise EDunTifParseError.Create('DunTif: negative strip decode size');
      if needBytes > High(Integer) then
        raise EDunTifParseError.Create('DunTif: strip decode size exceeds decoder limit');

      if (stripIdx > High(Frame.StripByteCounts)) or (stripIdx > High(Frame.StripOffsets)) then
        raise EDunTifParseError.Create('DunTif: strip arrays mismatch');

      if Frame.StripByteCounts[stripIdx] <= 0 then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d has invalid compressed size', [stripIdx]);
      if Frame.StripByteCounts[stripIdx] > High(Integer) then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d compressed size too large', [stripIdx]);

      r.SeekAbs(Frame.StripOffsets[stripIdx]);
      compressed := r.ReadBytes(Integer(Frame.StripByteCounts[stripIdx]));
      raw := DunTifTiffLzwDecompress(compressed, Integer(needBytes));
      DunTifApplyPredictorToStrip(raw, Frame, rowsThisStrip);

      TDunTifRaster8.WriteChunkyStrip(raw, Frame, AOut, rowStart, rowsThisStrip);
      Inc(rowStart, rowsThisStrip);
    end;
  finally
    r.Free;
  end;
end;

end.
