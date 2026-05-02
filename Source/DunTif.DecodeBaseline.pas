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
  DunTif.BinReader;

function ByteToFPWord(b: Byte): Word; inline;
begin
  // Expand 8-bit component to 16-bit FPColor range
  Result := Word(b) * 257;
end;

class procedure TDunTifBaselineDecoder.DecodeToFPImage(AStream: TStream; const Frame: TTiffFrame; AOut: TFPMemoryImage);
var
  r: TDunTifBinReader;
  x, y: Integer;
  stripIdx: Integer;
  rowsThisStrip: Integer;
  rowStart: Integer;
  remainingRows: Integer;
  bytesPerPixel: Integer;
  bytesPerRow: Integer;
  needBytes: Int64;
  buf: TBytes;
  p: Int64;
  c: TFPColor;
  bR, bG, bB: Byte;
  bY: Byte;
begin
  if (AStream = nil) or (AOut = nil) then
    Exit;

  if (Frame.Width = 0) or (Frame.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid frame dimensions');

  if (Frame.SamplesPerPixel <> 1) and (Frame.SamplesPerPixel <> 3) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported SamplesPerPixel %d (baseline decoder)', [Frame.SamplesPerPixel]);

  bytesPerPixel := Frame.SamplesPerPixel;
  bytesPerRow := Int64(Frame.Width) * bytesPerPixel;

  AOut.SetSize(Frame.Width, Frame.Height);

  r := TDunTifBinReader.Create(AStream, Frame.Endian);
  try
    y := 0;
    for stripIdx := 0 to High(Frame.StripOffsets) do
    begin
      if y >= Integer(Frame.Height) then
        Break;

      rowStart := y;
      remainingRows := Integer(Frame.Height) - rowStart;
      if Frame.RowsPerStrip > Cardinal(High(Integer)) then
        rowsThisStrip := remainingRows
      else
        rowsThisStrip := Integer(Frame.RowsPerStrip);
      if rowsThisStrip > remainingRows then
        rowsThisStrip := remainingRows;

      needBytes := Int64(rowsThisStrip) * bytesPerRow;
      if needBytes < 0 then
        raise EDunTifParseError.Create('DunTif: negative strip decode size');

      if (stripIdx > High(Frame.StripByteCounts)) or (stripIdx > High(Frame.StripOffsets)) then
        raise EDunTifParseError.Create('DunTif: strip arrays mismatch');

      if Frame.StripByteCounts[stripIdx] < needBytes then
        raise EDunTifParseError.CreateFmt('DunTif: strip %d too small (%d < %d)',
          [stripIdx, Frame.StripByteCounts[stripIdx], needBytes]);

      r.SeekAbs(Frame.StripOffsets[stripIdx]);
      buf := r.ReadBytes(needBytes);

      p := 0;
      for y := rowStart to rowStart + rowsThisStrip - 1 do
      begin
        for x := 0 to Integer(Frame.Width) - 1 do
        begin
          if Frame.SamplesPerPixel = 3 then
          begin
            bR := buf[p + 0];
            bG := buf[p + 1];
            bB := buf[p + 2];
            c.red := ByteToFPWord(bR);
            c.green := ByteToFPWord(bG);
            c.blue := ByteToFPWord(bB);
            c.alpha := $FFFF;
            AOut.Colors[x, y] := c;
            Inc(p, 3);
          end
          else
          begin
            bY := buf[p];
            c.red := ByteToFPWord(bY);
            c.green := c.red;
            c.blue := c.red;
            c.alpha := $FFFF;
            AOut.Colors[x, y] := c;
            Inc(p, 1);
          end;
        end;
      end;
    end;
  finally
    r.Free;
  end;
end;

end.

