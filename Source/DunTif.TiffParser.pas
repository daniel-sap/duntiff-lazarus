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
begin
  FillChar(Result, SizeOf(Result), 0);
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

  // baseline validations (Milestone 1)
  if (Result.Width = 0) or (Result.Height = 0) then
    raise EDunTifParseError.Create('DunTif: invalid TIFF dimensions');

  if Result.Compression <> Ord(tcNone) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported compression %d (Milestone 1 supports only None=1)', [Result.Compression]);

  if not ((Result.Photometric = Ord(tpRGB)) or (Result.Photometric = Ord(tpWhiteIsZero)) or (Result.Photometric = Ord(tpBlackIsZero))) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported photometric %d (Milestone 1 supports RGB/Gray only)', [Result.Photometric]);

  if Result.PlanarConfig <> Ord(tpcChunky) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported planar configuration %d (Milestone 1 supports chunky=1)', [Result.PlanarConfig]);

  if (Result.SamplesPerPixel <> 1) and (Result.SamplesPerPixel <> 3) then
    raise EDunTifParseError.CreateFmt('DunTif: unsupported SamplesPerPixel %d (Milestone 1 supports 1 or 3)', [Result.SamplesPerPixel]);

  if Length(Result.BitsPerSample) <> Result.SamplesPerPixel then
  begin
    // allow BitsPerSample=8 for grayscale even if array length differs (some writers)
    if (Result.SamplesPerPixel = 1) and (Length(Result.BitsPerSample) = 1) then
    else
      raise EDunTifParseError.CreateFmt('DunTif: BitsPerSample count (%d) does not match SamplesPerPixel (%d)',
        [Length(Result.BitsPerSample), Result.SamplesPerPixel]);
  end;

  for i := 0 to High(Result.BitsPerSample) do
    if Result.BitsPerSample[i] <> 8 then
      raise EDunTifParseError.CreateFmt('DunTif: unsupported BitsPerSample=%d (Milestone 1 supports 8-bit only)', [Result.BitsPerSample[i]]);

  if Result.RowsPerStrip = 0 then
    raise EDunTifParseError.Create('DunTif: invalid RowsPerStrip=0');
end;

end.

