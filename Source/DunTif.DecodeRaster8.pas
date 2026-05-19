unit DunTif.DecodeRaster8;

{$mode delphi}

interface

uses
  SysUtils,
  FPImage,
  DunTif.TiffTypes;

type
  { Shared chunky 8-bit Gray/RGB/RGBA strip writer for strip decoders. }

  TDunTifRaster8 = class
  public
    class procedure WriteChunkyStrip(const Buf: TBytes; const Frame: TTiffFrame;
      AOut: TFPMemoryImage; rowStart, rowsThisStrip: Integer); static;
  end;

implementation

uses
  DunTif.BinReader;

function ByteToFPWord(b: Byte): Word; inline;
begin
  Result := Word(b) * 257;
end;

class procedure TDunTifRaster8.WriteChunkyStrip(const Buf: TBytes; const Frame: TTiffFrame;
  AOut: TFPMemoryImage; rowStart, rowsThisStrip: Integer);
var
  x, y: Integer;
  bytesPerPixel: Integer;
  bytesPerRow: Int64;
  needBytes: Int64;
  p: Int64;
  c: TFPColor;
  bR, bG, bB, bA: Byte;
  bY: Byte;
begin
  if AOut = nil then
    Exit;

  if not DunTifStripSamplesPerPixelSupported(Frame.SamplesPerPixel) then
    raise EDunTifParseError.CreateFmt(
      'DunTif: unsupported SamplesPerPixel %d in raster writer (supports 1, 3, or 4)',
      [Frame.SamplesPerPixel]);

  bytesPerPixel := Frame.SamplesPerPixel;
  bytesPerRow := Int64(Frame.Width) * bytesPerPixel;
  needBytes := Int64(rowsThisStrip) * bytesPerRow;

  if Int64(Length(Buf)) < needBytes then
    raise EDunTifParseError.CreateFmt('DunTif: strip buffer too small (%d < %d)',
      [Length(Buf), needBytes]);

  p := 0;
  for y := rowStart to rowStart + rowsThisStrip - 1 do
  begin
    for x := 0 to Integer(Frame.Width) - 1 do
    begin
      if Frame.SamplesPerPixel = 4 then
      begin
        bR := Buf[p + 0];
        bG := Buf[p + 1];
        bB := Buf[p + 2];
        bA := Buf[p + 3];
        c.red := ByteToFPWord(bR);
        c.green := ByteToFPWord(bG);
        c.blue := ByteToFPWord(bB);
        c.alpha := ByteToFPWord(bA);
        AOut.Colors[x, y] := c;
        Inc(p, 4);
      end
      else if Frame.SamplesPerPixel = 3 then
      begin
        bR := Buf[p + 0];
        bG := Buf[p + 1];
        bB := Buf[p + 2];
        c.red := ByteToFPWord(bR);
        c.green := ByteToFPWord(bG);
        c.blue := ByteToFPWord(bB);
        c.alpha := $FFFF;
        AOut.Colors[x, y] := c;
        Inc(p, 3);
      end
      else
      begin
        bY := Buf[p];
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

end.
