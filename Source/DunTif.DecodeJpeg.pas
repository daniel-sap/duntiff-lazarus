unit DunTif.DecodeJpeg;

{$mode delphi}

interface

uses
  SysUtils, Classes,
  FPImage,
  DunTif.TiffTypes;

type
  TDunTifJpegDecoder = class
  public
    class procedure DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage); static;
  end;

implementation

uses
  DunTif.BinReader,
  DunTif.DecodeRaster8,
  DunTif.JpegDecode;

class procedure TDunTifJpegDecoder.DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage);
var
  r: TDunTifBinReader;
  stripIdx: Integer;
  rowsThisStrip: Integer;
  rowStart: Integer;
  remainingRows: Integer;
  compressed: TBytes;
  raw: TBytes;
  jpegFrame: TTiffFrame;
begin
  if (AStream = nil) or (AOut = nil) then
    Exit;

  if (Frame.Width = 0) or (Frame.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid frame dimensions');

  if Frame.SamplesPerPixel <> 3 then
    raise EDunTifParseError.CreateFmt('DunTif: JPEG decoder requires SamplesPerPixel=3 (got %d)', [Frame.SamplesPerPixel]);

  AOut.SetSize(Frame.Width, Frame.Height);
  jpegFrame := Frame;
  jpegFrame.SamplesPerPixel := 3;

  r := TDunTifBinReader.Create(AStream, Frame.Endian);
  try
    if (Frame.JpegInterchangeOffset > 0) and (Frame.JpegInterchangeLength > 0) and
      (Length(Frame.StripOffsets) = 1) then
    begin
      if Frame.JpegInterchangeLength > High(Integer) then
        raise EDunTifParseError.Create('DunTif: JPEG interchange segment too large');
      r.SeekAbs(Frame.JpegInterchangeOffset);
      compressed := r.ReadBytes(Integer(Frame.JpegInterchangeLength));
      raw := DunTifDecodeJpegStripToRgb8(Frame.JpegTables, compressed, Integer(Frame.Width), Integer(Frame.Height));
      TDunTifRaster8.WriteChunkyStrip(raw, jpegFrame, AOut, 0, Integer(Frame.Height));
      Exit;
    end;

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

      if (stripIdx > High(Frame.StripByteCounts)) or (stripIdx > High(Frame.StripOffsets)) then
        raise EDunTifParseError.Create('DunTif: strip arrays mismatch');

      if Frame.StripByteCounts[stripIdx] <= 0 then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d has invalid compressed size', [stripIdx]);
      if Frame.StripByteCounts[stripIdx] > High(Integer) then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d compressed size too large', [stripIdx]);

      r.SeekAbs(Frame.StripOffsets[stripIdx]);
      compressed := r.ReadBytes(Integer(Frame.StripByteCounts[stripIdx]));
      raw := DunTifDecodeJpegStripToRgb8(Frame.JpegTables, compressed, Integer(Frame.Width), rowsThisStrip);
      TDunTifRaster8.WriteChunkyStrip(raw, jpegFrame, AOut, rowStart, rowsThisStrip);
      Inc(rowStart, rowsThisStrip);
    end;
  finally
    r.Free;
  end;
end;

end.
