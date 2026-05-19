unit DunTif.TiffTypes;

{$mode delphi}

interface

uses
  SysUtils;

type
  TTiffEndian = (teLittle, teBig);

  TTiffTagType = (
    tttByte = 1,
    tttAscii = 2,
    tttShort = 3,
    tttLong = 4,
    tttRational = 5,
    tttSByte = 6,
    tttUndefined = 7,
    tttSShort = 8,
    tttSLong = 9,
    tttSRational = 10
  );

  TTiffCompression = (
    tcNone = 1,
    tcCCITTRLE = 2,
    tcCCITTFax3 = 3,
    tcCCITTFax4 = 4,
    tcLZW = 5,
    tcJpegOldStyle = 6,
    tcJpeg = 7,
    tcDeflateAdobe = 8,
    tcPackBits = 32773,
    tcDeflate = 32946
  );

  TTiffPhotometric = (
    tpWhiteIsZero = 0,
    tpBlackIsZero = 1,
    tpRGB = 2,
    tpPalette = 3,
    tpTransparencyMask = 4,
    tpCMYK = 5,
    tpYCbCr = 6,
    tpCIELab = 8
  );

  TTiffPlanarConfiguration = (
    tpcChunky = 1,
    tpcPlanar = 2
  );

  TTiffIfdEntry = record
    Tag: Word;
    TagType: Word;
    Count: Cardinal;
    ValueOrOffset: Cardinal;
  end;

  { First 8 bytes of a TIFF stream (byte order, magic 42, offset of first IFD). }
  TTiffFileHeader = record
    Endian: TTiffEndian;
    FirstIfdOffset: Cardinal;
  end;

  { One IFD / one image page: metadata and strip pointers for decoders (no pixel data). }
  TTiffFrame = record
    Endian: TTiffEndian;
    Width: Cardinal;
    Height: Cardinal;
    Compression: Word;
    Photometric: Word;
    SamplesPerPixel: Word;
    BitsPerSample: array of Word;
    RowsPerStrip: Cardinal;
    PlanarConfig: Word;
    StripOffsets: array of Int64;
    StripByteCounts: array of Int64;
    { Tag 317; 1 = none, 2 = horizontal differencing (applied after LZW/Deflate). Default 1 if absent. }
    Predictor: Word;
    { JPEG-in-TIFF (tags 513/514/530/532); meaningful when Compression = 7. }
    JpegInterchangeOffset: Int64;
    JpegInterchangeLength: Int64;
    JpegTables: TBytes;
    YCbCrSubSampling: array[0..1] of Word;
    ReferenceBlackWhite: array[0..5] of Double;
    HasReferenceBlackWhite: Boolean;
  end;

implementation

end.

