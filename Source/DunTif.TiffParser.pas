unit DunTif.TiffParser;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  DunTif.TiffTypes;

type
  TDunTifTiffParser = class
  public
    class function ParseSingleFrame(AStream: TStream): TTiffFrame; static;
  end;

implementation

uses
  DunTif.BinReader;

type
  TWordDynArray = array of Word;
  TCardinalDynArray = array of Cardinal;
  TInt64DynArray = array of Int64;
  TDoubleDynArray = array of Double;
  TTiffIfdEntryArray = array of TTiffIfdEntry;

const
  TAG_ImageWidth = 256;
  TAG_ImageLength = 257;
  TAG_BitsPerSample = 258;
  TAG_Compression = 259;
  TAG_PhotometricInterpretation = 262;
  TAG_StripOffsets = 273;
  TAG_SamplesPerPixel = 277;
  TAG_RowsPerStrip = 278;
  TAG_StripByteCounts = 279;
  TAG_PlanarConfiguration = 284;
  TAG_TileWidth = 322;
  TAG_TileLength = 323;
  TAG_Predictor = 317;
  TAG_JpegTables = 347;
  TAG_JpegInterchangeFormat = 513;
  TAG_JpegInterchangeFormatLength = 514;
  TAG_YCbCrSubSampling = 530;
  TAG_ReferenceBlackWhite = 532;

function InlineShort(ValueOrOffset: Cardinal; Endian: TTiffEndian): Word;
begin
  if Endian = teLittle then
    Result := Word(ValueOrOffset and $FFFF)
  else
    Result := Word((ValueOrOffset shr 16) and $FFFF);
end;

function InlineByte(ValueOrOffset: Cardinal; Endian: TTiffEndian; Index: Integer): Byte;
var
  shift: Integer;
begin
  // Index 0..3 in file order
  if (Index < 0) or (Index > 3) then
    Exit(0);
  if Endian = teLittle then
    shift := Index * 8
  else
    shift := (3 - Index) * 8;
  Result := Byte((ValueOrOffset shr shift) and $FF);
end;

procedure RequireTag(const Name: string; HasIt: Boolean);
begin
  if not HasIt then
    raise EDunTifParseError.CreateFmt('DunTif: missing required TIFF tag: %s', [Name]);
end;

function TagTypeSize(TagType: Word): Integer;
begin
  case TagType of
    1, 2, 6, 7: Result := 1; // BYTE/ASCII/SBYTE/UNDEFINED
    3, 8: Result := 2;       // SHORT/SSHORT
    4, 9: Result := 4;       // LONG/SLONG
    5, 10: Result := 8;      // RATIONAL/SRATIONAL
  else
    Result := 0;
  end;
end;

function ReadU16Array(R: TDunTifBinReader; const Entry: TTiffIfdEntry; Endian: TTiffEndian): TWordDynArray;
var
  i: Integer;
  totalBytes: Int64;
  off: Cardinal;
begin
  if Entry.TagType <> Ord(tttShort) then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d expected SHORT', [Entry.Tag]);
  SetLength(Result, Entry.Count);
  if Entry.Count = 0 then
    Exit;
  totalBytes := Int64(Entry.Count) * 2;
  if totalBytes <= 4 then
  begin
    for i := 0 to Entry.Count - 1 do
    begin
      if Endian = teLittle then
        Result[i] := Word((Entry.ValueOrOffset shr (i * 16)) and $FFFF)
      else
      begin
        // big-endian: shorts are packed from MSW downward
        if i = 0 then
          Result[i] := Word((Entry.ValueOrOffset shr 16) and $FFFF)
        else
          Result[i] := Word(Entry.ValueOrOffset and $FFFF);
      end;
    end;
    Exit;
  end;

  off := Entry.ValueOrOffset;
  R.SeekAbs(off);
  for i := 0 to Entry.Count - 1 do
    Result[i] := R.ReadU16;
end;

function ReadU32Array(R: TDunTifBinReader; const Entry: TTiffIfdEntry): TCardinalDynArray;
var
  i: Integer;
  totalBytes: Int64;
  off: Cardinal;
begin
  if Entry.TagType <> Ord(tttLong) then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d expected LONG', [Entry.Tag]);
  SetLength(Result, Entry.Count);
  if Entry.Count = 0 then
    Exit;
  totalBytes := Int64(Entry.Count) * 4;
  if totalBytes <= 4 then
  begin
    Result[0] := Entry.ValueOrOffset;
    Exit;
  end;
  off := Entry.ValueOrOffset;
  R.SeekAbs(off);
  for i := 0 to Entry.Count - 1 do
    Result[i] := R.ReadU32;
end;

function ReadOffsetsAsInt64(R: TDunTifBinReader; const Entry: TTiffIfdEntry; Endian: TTiffEndian): TInt64DynArray;
var
  u16s: TWordDynArray;
  u32s: TCardinalDynArray;
  i: Integer;
begin
  case Entry.TagType of
    Ord(tttShort):
      begin
        u16s := ReadU16Array(R, Entry, Endian);
        SetLength(Result, Length(u16s));
        for i := 0 to High(u16s) do
          Result[i] := u16s[i];
      end;
    Ord(tttLong):
      begin
        u32s := ReadU32Array(R, Entry);
        SetLength(Result, Length(u32s));
        for i := 0 to High(u32s) do
          Result[i] := u32s[i];
      end;
  else
    raise EDunTifParseError.CreateFmt('DunTif: tag %d has unsupported type %d', [Entry.Tag, Entry.TagType]);
  end;
end;

function ReadScalarAsInt64(R: TDunTifBinReader; const Entry: TTiffIfdEntry; Endian: TTiffEndian): Int64;
begin
  case Entry.TagType of
    Ord(tttShort):
      Result := InlineShort(Entry.ValueOrOffset, Endian);
    Ord(tttLong):
      Result := Entry.ValueOrOffset;
  else
    raise EDunTifParseError.CreateFmt('DunTif: tag %d has unsupported type %d', [Entry.Tag, Entry.TagType]);
  end;
end;

function ReadUndefinedBytes(R: TDunTifBinReader; const Entry: TTiffIfdEntry): TBytes;
var
  totalBytes: Int64;
  off: Cardinal;
begin
  if (Entry.TagType <> Ord(tttByte)) and (Entry.TagType <> Ord(tttUndefined)) then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d expected BYTE/UNDEFINED', [Entry.Tag]);
  if Entry.Count = 0 then
    Exit(nil);
  totalBytes := Entry.Count;
  if totalBytes > High(Integer) then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d value too large', [Entry.Tag]);
  SetLength(Result, Entry.Count);
  if totalBytes <= 4 then
  begin
  if Entry.Count > 0 then Result[0] := Byte(Entry.ValueOrOffset and $FF);
  if Entry.Count > 1 then Result[1] := Byte((Entry.ValueOrOffset shr 8) and $FF);
  if Entry.Count > 2 then Result[2] := Byte((Entry.ValueOrOffset shr 16) and $FF);
  if Entry.Count > 3 then Result[3] := Byte((Entry.ValueOrOffset shr 24) and $FF);
    Exit;
  end;
  off := Entry.ValueOrOffset;
  R.SeekAbs(off);
  Result := R.ReadBytes(Integer(totalBytes));
end;

function ReadRationalArray(R: TDunTifBinReader; const Entry: TTiffIfdEntry): TDoubleDynArray;
var
  i: Integer;
  totalBytes: Int64;
  off: Cardinal;
  num, den: Cardinal;
begin
  if Entry.TagType <> Ord(tttRational) then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d expected RATIONAL', [Entry.Tag]);
  SetLength(Result, Entry.Count);
  if Entry.Count = 0 then
    Exit;
  totalBytes := Int64(Entry.Count) * 8;
  if totalBytes <= 4 then
    raise EDunTifParseError.CreateFmt('DunTif: tag %d RATIONAL value too small', [Entry.Tag]);
  off := Entry.ValueOrOffset;
  R.SeekAbs(off);
  for i := 0 to Entry.Count - 1 do
  begin
    num := R.ReadU32;
    den := R.ReadU32;
    if den = 0 then
      Result[i] := 0
    else
      Result[i] := num / den;
  end;
end;

procedure ValidateCommonFrame(var Result: TTiffFrame);
var
  i: Integer;
begin
  if (Result.Width = 0) or (Result.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid TIFF dimensions');

  if Result.PlanarConfig <> Ord(tpcChunky) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported planar configuration %d (supports chunky=1)', [Result.PlanarConfig]);

  if Length(Result.BitsPerSample) <> Result.SamplesPerPixel then
  begin
    if (Result.SamplesPerPixel = 1) and (Length(Result.BitsPerSample) = 1) then
    else
      raise EDunTifParseError.CreateFmt('DunTif: BitsPerSample count (%d) does not match SamplesPerPixel (%d)',
        [Length(Result.BitsPerSample), Result.SamplesPerPixel]);
  end;

  for i := 0 to High(Result.BitsPerSample) do
    if Result.BitsPerSample[i] <> 8 then
      raise EDunTifParseError.CreateFmt('DunTif: unsupported BitsPerSample=%d (supports 8-bit only)', [Result.BitsPerSample[i]]);

  if Result.RowsPerStrip = 0 then
    raise EDunTifParseError.Create('DunTif: invalid RowsPerStrip=0');
end;

procedure ValidateBaselineFrame(const Result: TTiffFrame);
var
  i: Integer;
begin
  if (Result.Compression <> Ord(tcNone)) and (Result.Compression <> Ord(tcPackBits)) and
    (Result.Compression <> Ord(tcLZW)) and (Result.Compression <> Ord(tcDeflateAdobe)) and
    (Result.Compression <> Ord(tcDeflate)) then
    raise EDunTifParseError.CreateFmt(
      'DunTif: unsupported compression %d (supports None=1, PackBits=32773, LZW=5, Deflate=8/32946)',
      [Result.Compression]);

  if not ((Result.Photometric = Ord(tpRGB)) or (Result.Photometric = Ord(tpWhiteIsZero)) or
    (Result.Photometric = Ord(tpBlackIsZero))) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported photometric %d (supports RGB/Gray only)', [Result.Photometric]);

  if (Result.SamplesPerPixel <> 1) and (Result.SamplesPerPixel <> 3) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported SamplesPerPixel %d (supports 1 or 3)', [Result.SamplesPerPixel]);

  if (Result.Predictor <> 1) and (Result.Predictor <> 2) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported Predictor %d (supports none=1 or horizontal=2)', [Result.Predictor]);
end;

procedure ValidateJpegFrame(const Result: TTiffFrame);
begin
  if Result.Compression = Ord(tcJpegOldStyle) then
    raise EDunTifParseError.Create('DunTif: old-style JPEG (Compression=6) is not supported; use new JPEG (Compression=7)');

  if Result.Compression <> Ord(tcJpeg) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported compression %d (JPEG reader supports Compression=7 only)', [Result.Compression]);

  if Result.Photometric <> Ord(tpYCbCr) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported photometric %d for JPEG (supports YCbCr=6 only)', [Result.Photometric]);

  if Result.SamplesPerPixel <> 3 then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported SamplesPerPixel %d for JPEG (supports 3)', [Result.SamplesPerPixel]);

  if Result.Predictor <> 1 then
    raise EDunTifParseError.CreateFmt('DunTif: Predictor %d is not valid with JPEG compression', [Result.Predictor]);
end;

function FindEntry(const Entries: array of TTiffIfdEntry; ATag: Word; out Entry: TTiffIfdEntry): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(Entries) do
    if Entries[i].Tag = ATag then
    begin
      Entry := Entries[i];
      Exit(True);
    end;
  Result := False;
end;

class function TDunTifTiffParser.ParseSingleFrame(AStream: TStream): TTiffFrame;
var
  hdr: array[0..1] of AnsiChar;
  endian: TTiffEndian;
  r: TDunTifBinReader;
  magic: Word;
  ifdOff: Cardinal;
  entryCount: Word;
  entries: TTiffIfdEntryArray;
  i: Integer;
  e: TTiffIfdEntry;
  bits: TWordDynArray;
  stripOffsets: TInt64DynArray;
  stripCounts: TInt64DynArray;
  rbw: TDoubleDynArray;
  subs: TWordDynArray;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.YCbCrSubSampling[0] := 2;
  Result.YCbCrSubSampling[1] := 2;
  if AStream = nil then
    raise EDunTifParseError.Create('DunTif: stream is nil');

  AStream.Position := 0;
  AStream.ReadBuffer(hdr[0], 2);
  if (hdr[0] = 'I') and (hdr[1] = 'I') then
    endian := teLittle
  else if (hdr[0] = 'M') and (hdr[1] = 'M') then
    endian := teBig
  else
    raise EDunTifParseError.Create('DunTif: not a TIFF stream (bad byte order mark)');

  r := TDunTifBinReader.Create(AStream, endian);
  try
    magic := r.ReadU16;
    if magic <> 42 then
      raise EDunTifParseError.CreateFmt('DunTif: not a TIFF stream (magic=%d)', [magic]);

    ifdOff := r.ReadU32;
    if ifdOff = 0 then
      raise EDunTifParseError.Create('DunTif: invalid TIFF (IFD offset=0)');

    r.SeekAbs(ifdOff);
    entryCount := r.ReadU16;
    SetLength(entries, entryCount);
    for i := 0 to entryCount - 1 do
    begin
      entries[i].Tag := r.ReadU16;
      entries[i].TagType := r.ReadU16;
      entries[i].Count := r.ReadU32;
      entries[i].ValueOrOffset := r.ReadU32;
      if TagTypeSize(entries[i].TagType) = 0 then
        raise EDunTifParseError.CreateFmt('DunTif: unsupported TIFF tag type %d (tag %d)', [entries[i].TagType, entries[i].Tag]);
    end;

    // nextIFDOffset := r.ReadU32; // ignored (v1: single frame)
    // validate required tags and extract baseline fields

    RequireTag('ImageWidth(256)', FindEntry(entries, TAG_ImageWidth, e));
    if e.TagType = Ord(tttShort) then
      Result.Width := InlineShort(e.ValueOrOffset, endian)
    else if e.TagType = Ord(tttLong) then
      Result.Width := e.ValueOrOffset
    else
      raise EDunTifParseError.Create('DunTif: ImageWidth has unsupported type');

    RequireTag('ImageLength(257)', FindEntry(entries, TAG_ImageLength, e));
    if e.TagType = Ord(tttShort) then
      Result.Height := InlineShort(e.ValueOrOffset, endian)
    else if e.TagType = Ord(tttLong) then
      Result.Height := e.ValueOrOffset
    else
      raise EDunTifParseError.Create('DunTif: ImageLength has unsupported type');

    RequireTag('Compression(259)', FindEntry(entries, TAG_Compression, e));
    if e.TagType = Ord(tttShort) then
      Result.Compression := InlineShort(e.ValueOrOffset, endian)
    else
      raise EDunTifParseError.Create('DunTif: Compression has unsupported type');

    RequireTag('PhotometricInterpretation(262)', FindEntry(entries, TAG_PhotometricInterpretation, e));
    if e.TagType = Ord(tttShort) then
      Result.Photometric := InlineShort(e.ValueOrOffset, endian)
    else
      raise EDunTifParseError.Create('DunTif: PhotometricInterpretation has unsupported type');

    RequireTag('SamplesPerPixel(277)', FindEntry(entries, TAG_SamplesPerPixel, e));
    if e.TagType = Ord(tttShort) then
      Result.SamplesPerPixel := InlineShort(e.ValueOrOffset, endian)
    else
      raise EDunTifParseError.Create('DunTif: SamplesPerPixel has unsupported type');

    RequireTag('BitsPerSample(258)', FindEntry(entries, TAG_BitsPerSample, e));
    if e.TagType <> Ord(tttShort) then
      raise EDunTifParseError.Create('DunTif: BitsPerSample has unsupported type');
    bits := ReadU16Array(r, e, endian);
    SetLength(Result.BitsPerSample, Length(bits));
    for i := 0 to High(bits) do
      Result.BitsPerSample[i] := bits[i];

    RequireTag('RowsPerStrip(278)', FindEntry(entries, TAG_RowsPerStrip, e));
    if e.TagType = Ord(tttShort) then
      Result.RowsPerStrip := InlineShort(e.ValueOrOffset, endian)
    else if e.TagType = Ord(tttLong) then
      Result.RowsPerStrip := e.ValueOrOffset
    else
      raise EDunTifParseError.Create('DunTif: RowsPerStrip has unsupported type');

    { TIFF default: if PlanarConfiguration is omitted, assume chunky (1). }
    if FindEntry(entries, TAG_PlanarConfiguration, e) then
    begin
      if e.TagType = Ord(tttShort) then
        Result.PlanarConfig := InlineShort(e.ValueOrOffset, endian)
      else
        raise EDunTifParseError.Create('DunTif: PlanarConfiguration has unsupported type');
    end
    else
      Result.PlanarConfig := Ord(tpcChunky);

    if FindEntry(entries, TAG_Predictor, e) then
    begin
      if e.TagType = Ord(tttShort) then
        Result.Predictor := InlineShort(e.ValueOrOffset, endian)
      else
        raise EDunTifParseError.Create('DunTif: Predictor has unsupported type');
    end
    else
      Result.Predictor := 1;

    if FindEntry(entries, TAG_TileWidth, e) or FindEntry(entries, TAG_TileLength, e) then
      raise EDunTifParseError.Create('DunTif: tiled TIFF is not supported (TileWidth/TileLength present)');

    if FindEntry(entries, TAG_JpegTables, e) then
      Result.JpegTables := ReadUndefinedBytes(r, e);

    if FindEntry(entries, TAG_JpegInterchangeFormat, e) then
      Result.JpegInterchangeOffset := ReadScalarAsInt64(r, e, endian);
    if FindEntry(entries, TAG_JpegInterchangeFormatLength, e) then
      Result.JpegInterchangeLength := ReadScalarAsInt64(r, e, endian);

    if FindEntry(entries, TAG_YCbCrSubSampling, e) then
    begin
      subs := ReadU16Array(r, e, endian);
      if Length(subs) >= 2 then
      begin
        Result.YCbCrSubSampling[0] := subs[0];
        Result.YCbCrSubSampling[1] := subs[1];
      end
      else if Length(subs) = 1 then
      begin
        Result.YCbCrSubSampling[0] := subs[0];
        Result.YCbCrSubSampling[1] := subs[0];
      end;
    end;

    if FindEntry(entries, TAG_ReferenceBlackWhite, e) then
    begin
      if e.TagType = Ord(tttRational) then
      begin
        rbw := ReadRationalArray(r, e);
        if Length(rbw) >= 6 then
        begin
          for i := 0 to 5 do
            Result.ReferenceBlackWhite[i] := rbw[i];
          Result.HasReferenceBlackWhite := True;
        end;
      end;
    end;

    RequireTag('StripOffsets(273)', FindEntry(entries, TAG_StripOffsets, e));
    stripOffsets := ReadOffsetsAsInt64(r, e, endian);

    RequireTag('StripByteCounts(279)', FindEntry(entries, TAG_StripByteCounts, e));
    stripCounts := ReadOffsetsAsInt64(r, e, endian);

    if Length(stripOffsets) <> Length(stripCounts) then
      raise EDunTifParseError.CreateFmt('DunTif: StripOffsets count (%d) <> StripByteCounts count (%d)',
        [Length(stripOffsets), Length(stripCounts)]);

    SetLength(Result.StripOffsets, Length(stripOffsets));
    SetLength(Result.StripByteCounts, Length(stripCounts));
    for i := 0 to High(stripOffsets) do
    begin
      Result.StripOffsets[i] := stripOffsets[i];
      Result.StripByteCounts[i] := stripCounts[i];
    end;

    Result.Endian := endian;
  finally
    r.Free;
  end;

  ValidateCommonFrame(Result);
  if Result.Compression = Ord(tcJpeg) then
    ValidateJpegFrame(Result)
  else
  begin
    if Result.Compression = Ord(tcJpegOldStyle) then
      raise EDunTifParseError.Create('DunTif: old-style JPEG (Compression=6) is not supported; use new JPEG (Compression=7)');
    ValidateBaselineFrame(Result);
  end;
end;

end.

