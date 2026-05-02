unit DunTif.DecodeBaseline;

{$mode delphi}

interface

uses
  SysUtils, Classes,
  FPImage,
  DunTif.TiffTypes;

type
  TDunTifBaselineDecoder = class
  public
    class procedure DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage); static;
  end;

implementation

uses
  DunTif.BinReader,
  DunTif.DecodeRaster8,
  DunTif.DecodePredictor;

class procedure TDunTifBaselineDecoder.DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage);
var
  r: TDunTifBinReader;
  stripIdx: Integer;
  rowsThisStrip: Integer;
  rowStart: Integer;
  remainingRows: Integer;
  bytesPerPixel: Integer;
  needBytes: Int64;
  buf: TBytes;
begin
  if (AStream = nil) or (AOut = nil) then
    Exit;

  if (Frame.Width = 0) or (Frame.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid frame dimensions');

  if (Frame.SamplesPerPixel <> 1) and (Frame.SamplesPerPixel <> 3) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported SamplesPerPixel %d (baseline decoder)', [Frame.SamplesPerPixel]);

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

      if (stripIdx > High(Frame.StripByteCounts)) or (stripIdx > High(Frame.StripOffsets)) then
        raise EDunTifParseError.Create('DunTif: strip arrays mismatch');

      if Frame.StripByteCounts[stripIdx] < needBytes then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d too small (%d < %d)',
          [stripIdx, Frame.StripByteCounts[stripIdx], needBytes]);
      if needBytes > High(Integer) then
        raise EDunTifParseError.Create('DunTif: uncompressed strip exceeds decoder limit');

      r.SeekAbs(Frame.StripOffsets[stripIdx]);
      buf := r.ReadBytes(Integer(needBytes));
      DunTifApplyPredictorToStrip(buf, Frame, rowsThisStrip);

      TDunTifRaster8.WriteChunkyStrip(buf, Frame, AOut, rowStart, rowsThisStrip);
      Inc(rowStart, rowsThisStrip);
    end;
  finally
    r.Free;
  end;
end;

end.
