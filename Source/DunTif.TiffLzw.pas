unit DunTif.TiffLzw;

{$mode delphi}

interface

uses
  SysUtils;

function DunTifTiffLzwDecompress(const Src: TBytes; ADstLen: Integer): TBytes;

implementation

uses
  DunTif.BinReader;

const
  CODE_CLEAR = 256;
  CODE_EOI = 257;
  CODE_FIRST = 258;

function DunTifTiffLzwDecompress(const Src: TBytes; ADstLen: Integer): TBytes;
type
  TSmallIntArray8192 = array[0..8191] of SmallInt;
var
  Prefix: TSmallIntArray8192;
  Suffix: array[0..8191] of Byte;
  bp: Integer;
  nextdata: UInt64;
  nextbits: Integer;
  nbits: Integer;
  nbitsmask: Cardinal;
  next_free: Word;
  old_code: Word;
  new_code: Word;
  di: Integer;
  i: Integer;
  sp: Integer;
  stk: array[0..8191] of Byte;
  x: Word;
  fc: Byte;
  compatMode: Boolean;

  procedure ResetTable;
  var
    j: Integer;
  begin
    next_free := CODE_FIRST;
    nbits := 9;
    nbitsmask := (Cardinal(1) shl nbits) - 1;
    for j := CODE_FIRST to High(Prefix) do
      Prefix[j] := -1;
  end;

  function NextCode: Word;
  var
    code: UInt64;
  begin
    if compatMode then
    begin
      { Old TIFF / libtiff compat: bits accumulate LSB-first (GetNextCodeCompat). }
      while nextbits < nbits do
      begin
        if bp >= Length(Src) then
          raise EDunTifParseError.Create('DunTif: LZW truncated input');
        nextdata := nextdata or (UInt64(Src[bp]) shl nextbits);
        Inc(bp);
        Inc(nextbits, 8);
      end;
      code := nextdata and UInt64(nbitsmask);
      nextdata := nextdata shr nbits;
      Dec(nextbits, nbits);
      Result := Word(code);
    end
    else
    begin
      while nextbits < nbits do
      begin
        if bp >= Length(Src) then
          raise EDunTifParseError.Create('DunTif: LZW truncated input');
        nextdata := (nextdata shl 8) or Src[bp];
        Inc(bp);
        Inc(nextbits, 8);
      end;
      code := (nextdata shr (nextbits - nbits)) and UInt64(nbitsmask);
      Dec(nextbits, nbits);
      Result := Word(code);
    end;
  end;

  function FirstByteFromCode(code: Word): Byte;
  var
    t: Word;
  begin
    t := code;
    while t > 255 do
    begin
      if (t > High(Prefix)) or (Prefix[t] < 0) then
        raise EDunTifParseError.Create('DunTif: LZW corrupted prefix chain');
      t := Word(Prefix[t]);
    end;
    Result := Byte(t);
  end;

  procedure EmitChain(code: Word);
  begin
    sp := -1;
    x := code;
    while x > 255 do
    begin
      if (x > High(Suffix)) or (Prefix[x] < 0) then
        raise EDunTifParseError.Create('DunTif: LZW corrupted chain');
      Inc(sp);
      if sp > High(stk) then
        raise EDunTifParseError.Create('DunTif: LZW stack overflow');
      stk[sp] := Suffix[x];
      x := Word(Prefix[x]);
    end;
    Inc(sp);
    stk[sp] := Byte(x);
    while sp >= 0 do
    begin
      if di >= ADstLen then
        Exit;
      Result[di] := stk[sp];
      Inc(di);
      Dec(sp);
    end;
  end;

  procedure GrowCodeWidth;
  begin
    if next_free >= (Word(1) shl nbits) then
    begin
      Inc(nbits);
      if nbits > 12 then
        nbits := 12;
      nbitsmask := (Cardinal(1) shl nbits) - 1;
    end;
  end;

begin
  SetLength(Result, ADstLen);
  if ADstLen = 0 then
    Exit;

  compatMode := (Length(Src) >= 2) and (Src[0] = 0) and ((Src[1] and 1) <> 0);

  for i := 0 to High(Prefix) do
    Prefix[i] := -1;
  for i := 0 to 255 do
    Suffix[i] := Byte(i);

  bp := 0;
  nextdata := 0;
  nextbits := 0;
  ResetTable;

  di := 0;

  new_code := NextCode;
  while new_code = CODE_CLEAR do
    new_code := NextCode;
  if new_code = CODE_EOI then
    raise EDunTifParseError.Create('DunTif: LZW empty (EOI)');
  if new_code > 255 then
    raise EDunTifParseError.Create('DunTif: LZW first code must be literal');

  Result[di] := Byte(new_code);
  Inc(di);
  old_code := new_code;

  while di < ADstLen do
  begin
    new_code := NextCode;

    if new_code = CODE_CLEAR then
    begin
      ResetTable;
      new_code := NextCode;
      while new_code = CODE_CLEAR do
        new_code := NextCode;
      if new_code = CODE_EOI then
        Break;
      if new_code > 255 then
        raise EDunTifParseError.Create('DunTif: LZW invalid code after CLEAR');
      Result[di] := Byte(new_code);
      Inc(di);
      old_code := new_code;
      Continue;
    end;

    if new_code = CODE_EOI then
      Break;

    if new_code >= next_free then
    begin
      fc := FirstByteFromCode(old_code);
      EmitChain(old_code);
      if di >= ADstLen then
        Break;
      Result[di] := fc;
      Inc(di);
      if next_free > High(Prefix) then
        raise EDunTifParseError.Create('DunTif: LZW table overflow');
      Prefix[next_free] := SmallInt(old_code);
      Suffix[next_free] := fc;
      Inc(next_free);
      GrowCodeWidth;
      old_code := new_code;
      Continue;
    end;

    EmitChain(new_code);
    fc := FirstByteFromCode(new_code);

    if next_free > High(Prefix) then
      raise EDunTifParseError.Create('DunTif: LZW table overflow');
    Prefix[next_free] := SmallInt(old_code);
    Suffix[next_free] := fc;
    Inc(next_free);
    GrowCodeWidth;

    old_code := new_code;
  end;

  if di <> ADstLen then
    raise EDunTifParseError.CreateFmt('DunTif: LZW decoded length mismatch (%d vs %d)', [di, ADstLen]);
end;

end.
