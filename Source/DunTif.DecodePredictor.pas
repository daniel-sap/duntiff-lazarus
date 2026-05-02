unit DunTif.DecodePredictor;

{$mode delphi}

interface

uses
  SysUtils,
  DunTif.TiffTypes;

procedure DunTifApplyPredictorToStrip(var Buf: TBytes; const Frame: TTiffFrame; RowsThisStrip: Integer);

implementation

procedure UndoHorizontalDiff8(var Buf: TBytes; Width, Rows, BytesPerPixel: Integer);
var
  rowBytes: Integer;
  r: Integer;
  x: Integer;
  base: Integer;
begin
  rowBytes := Width * BytesPerPixel;
  for r := 0 to Rows - 1 do
  begin
    base := r * rowBytes;
    for x := BytesPerPixel to rowBytes - 1 do
      Buf[base + x] := Byte(Byte(Buf[base + x]) + Buf[base + x - BytesPerPixel]);
  end;
end;

procedure DunTifApplyPredictorToStrip(var Buf: TBytes; const Frame: TTiffFrame; RowsThisStrip: Integer);
begin
  if Frame.Predictor <> 2 then
    Exit;
  UndoHorizontalDiff8(Buf, Integer(Frame.Width), RowsThisStrip, Frame.SamplesPerPixel);
end;

end.
