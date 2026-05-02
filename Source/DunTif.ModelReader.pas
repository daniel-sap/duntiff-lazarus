unit DunTif.ModelReader;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  DunTif.Model;

type
  TDunTifModelReader = class
  public
    class function LoadFromStream(AStream: TStream): TDunTifDocument; static;
    class function LoadFromFile(const AFileName: string): TDunTifDocument; static;
  end;

implementation

uses
  DunTif.TiffTypes,
  DunTif.TiffParser,
  DunTif.DecodeBaseline,
  DunTif.DecodePackBits;

function FormatTiffReadFailure(const E: Exception): string;
var
  msg: string;
begin
  msg := E.Message;
  { FPReadTiff does not decode PhotometricInterpretation 6 (YCbCr), common with JPEG-in-TIFF. }
  if Pos('Photometric interpretation not handled (6)', msg) > 0 then
    Exit(msg + ' — FPReadTiff (fcl-image) does not support PhotometricInterpretation 6 (YCbCr), often used with JPEG-in-TIFF. Re-export as RGB TIFF or PNG.');
  if Pos('Photometric interpretation not handled', msg) > 0 then
    Exit(msg + ' — This photometric mode is not implemented in FPReadTiff; try RGB or grayscale TIFF.');
  Result := msg;
end;

class function TDunTifModelReader.LoadFromStream(AStream: TStream): TDunTifDocument;
var
  frame: TTiffFrame;
  bitsText: string;
  i: Integer;
  md: TDunTifMetadata;
begin
  if AStream = nil then
    raise EDunTifError.Create('DunTif: stream is nil');

  Result := TDunTifDocument.Create;
  try
    frame := TDunTifTiffParser.ParseSingleFrame(AStream);
    case frame.Compression of
      Ord(tcNone):
        TDunTifBaselineDecoder.DecodeToFPImage(AStream, frame, Result.Image);
      Ord(tcPackBits):
        TDunTifPackBitsDecoder.DecodeToFPImage(AStream, frame, Result.Image);
    else
      raise EDunTifError.CreateFmt('DunTif: unsupported compression %d', [frame.Compression]);
    end;

    bitsText := '';
    for i := 0 to High(frame.BitsPerSample) do
    begin
      if bitsText <> '' then
        bitsText := bitsText + ',';
      bitsText := bitsText + IntToStr(frame.BitsPerSample[i]);
    end;

    md.Compression := frame.Compression;
    md.Photometric := frame.Photometric;
    md.SamplesPerPixel := frame.SamplesPerPixel;
    md.BitsPerSample := bitsText;
    Result.Metadata := md;
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDunTifError.CreateFmt('DunTif: failed to read TIFF stream (%s)', [FormatTiffReadFailure(E)]);
    end;
  end;
end;

class function TDunTifModelReader.LoadFromFile(const AFileName: string): TDunTifDocument;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(fs);
  finally
    fs.Free;
  end;
end;

end.
