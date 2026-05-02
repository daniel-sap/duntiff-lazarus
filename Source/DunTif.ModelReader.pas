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
  FPReadTiff;

class function TDunTifModelReader.LoadFromStream(AStream: TStream): TDunTifDocument;
begin
  if AStream = nil then
    raise EDunTifError.Create('DunTif: stream is nil');

  Result := TDunTifDocument.Create;
  try
    Result.Image.LoadFromStream(AStream);
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDunTifError.CreateFmt('DunTif: failed to read TIFF stream (%s)', [E.Message]);
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
