unit DunTif.ModelWriter;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  DunTif.Model;

type
  TDunTifModelWriter = class
  public
    class procedure SaveToStream(AStream: TStream; ADoc: TDunTifDocument); static;
    class procedure SaveToFile(const AFileName: string; ADoc: TDunTifDocument); static;
  end;

implementation

uses
  FPImage, FPWriteTiff;

class procedure TDunTifModelWriter.SaveToStream(AStream: TStream; ADoc: TDunTifDocument);
var
  w: TFPWriterTiff;
begin
  if AStream = nil then
    raise EDunTifError.Create('DunTif: stream is nil');
  if ADoc = nil then
    raise EDunTifError.Create('DunTif: document is nil');
  if not ADoc.IsReady then
    raise EDunTifNotInitialized.Create(
      'DunTif: cannot save — document not initialized (call Initialize or load a TIFF first)');
  if ADoc.Image = nil then
    raise EDunTifError.Create('DunTif: document image is nil');

  w := TFPWriterTiff.Create;
  try
    try
      ADoc.Image.SaveToStream(AStream, w);
    except
      on E: Exception do
        raise EDunTifError.CreateFmt('DunTif: failed to write TIFF stream (%s)', [E.Message]);
    end;
  finally
    w.Free;
  end;
end;

class procedure TDunTifModelWriter.SaveToFile(const AFileName: string; ADoc: TDunTifDocument);
var
  fs: TFileStream;
begin
  if ADoc = nil then
    Exit;
  fs := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(fs, ADoc);
  finally
    fs.Free;
  end;
end;

end.
