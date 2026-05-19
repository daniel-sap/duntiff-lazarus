unit DunTif.JpegDecode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function DunTifBuildJpegStripStream(const Tables, Strip: TBytes): TBytes;
function DunTifDecodeJpegStripToRgb8(const Compressed: TBytes; AWidth, ARows: Integer): TBytes; overload;
function DunTifDecodeJpegStripToRgb8(const Tables, Compressed: TBytes; AWidth, ARows: Integer): TBytes; overload;

implementation

uses
  FPImage, FPReadJPEG,
  DunTif.BinReader;

function DunTifBuildJpegStripStream(const Tables, Strip: TBytes): TBytes;
var
  tablesLen, stripStart, stripLen: Integer;
begin
  if Length(Strip) < 2 then
    raise EDunTifParseError.Create('DunTif: JPEG strip too short');
  if (Strip[0] <> $FF) or (Strip[1] <> $D8) then
    raise EDunTifParseError.Create('DunTif: JPEG strip missing SOI marker');

  if Length(Tables) = 0 then
    Exit(Strip);

  tablesLen := Length(Tables);
  { JPEGTables often ends with EOI (FF D9) after table-only scan; strip follows without a new SOI. }
  if (tablesLen >= 2) and (Tables[tablesLen - 2] = $FF) and (Tables[tablesLen - 1] = $D9) then
    Dec(tablesLen, 2);

  stripStart := 2;
  stripLen := Length(Strip) - stripStart;
  SetLength(Result, tablesLen + stripLen);
  if tablesLen > 0 then
    Move(Tables[0], Result[0], tablesLen);
  Move(Strip[stripStart], Result[tablesLen], stripLen);
end;

function DunTifDecodeJpegStripToRgb8(const Compressed: TBytes; AWidth, ARows: Integer): TBytes;
begin
  Result := DunTifDecodeJpegStripToRgb8(nil, Compressed, AWidth, ARows);
end;

function DunTifDecodeJpegStripToRgb8(const Tables, Compressed: TBytes; AWidth, ARows: Integer): TBytes;
var
  streamBytes: TBytes;
  mem: TMemoryStream;
  reader: TFPReaderJPEG;
  img: TFPMemoryImage;
  x, y, p: Integer;
  c: TFPColor;
begin
  if (AWidth <= 0) or (ARows <= 0) then
    raise EDunTifParseError.Create('DunTif: JPEG decode requires positive width and row count');
  if Length(Compressed) = 0 then
    raise EDunTifParseError.Create('DunTif: empty JPEG strip');

  streamBytes := DunTifBuildJpegStripStream(Tables, Compressed);
  mem := TMemoryStream.Create;
  try
    if Length(streamBytes) > 0 then
      mem.WriteBuffer(streamBytes[0], Length(streamBytes));
    mem.Position := 0;

    reader := TFPReaderJPEG.Create;
    img := TFPMemoryImage.Create(0, 0);
    try
      reader.ImageRead(mem, img);
      if (img.Width <> AWidth) or (img.Height <> ARows) then
        raise EDunTifParseError.CreateFmt('DunTif: JPEG size %dx%d <> expected %dx%d',
          [img.Width, img.Height, AWidth, ARows]);

      SetLength(Result, AWidth * ARows * 3);
      p := 0;
      for y := 0 to ARows - 1 do
        for x := 0 to AWidth - 1 do
        begin
          c := img.Colors[x, y];
          Result[p] := Byte(c.red shr 8);
          Result[p + 1] := Byte(c.green shr 8);
          Result[p + 2] := Byte(c.blue shr 8);
          Inc(p, 3);
        end;
    finally
      img.Free;
      reader.Free;
    end;
  finally
    mem.Free;
  end;
end;

end.
