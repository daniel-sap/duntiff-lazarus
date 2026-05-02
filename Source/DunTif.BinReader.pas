unit DunTif.BinReader;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  DunTif.Model,
  DunTif.TiffTypes;

type
  EDunTifParseError = class(EDunTifError);

  TDunTifBinReader = class
  private
    FStream: TStream;
    FEndian: TTiffEndian;
    FSize: Int64;
    FHasSize: Boolean;
    procedure RequireReadable(ACount: Int64);
  public
    constructor Create(AStream: TStream; AEndian: TTiffEndian);
    property Stream: TStream read FStream;
    property Endian: TTiffEndian read FEndian write FEndian;
    property HasSize: Boolean read FHasSize;
    property Size: Int64 read FSize;
  public
    function Position: Int64;
    procedure SeekAbs(AOffset: Int64);
    function ReadBytes(ACount: Integer): TBytes;
    procedure ReadBuffer(var Buffer; ACount: Integer);
    function ReadU16: Word;
    function ReadU32: Cardinal;
  end;

implementation

constructor TDunTifBinReader.Create(AStream: TStream; AEndian: TTiffEndian);
begin
  inherited Create;
  if AStream = nil then
    raise EDunTifParseError.Create('DunTif: stream is nil');
  FStream := AStream;
  FEndian := AEndian;
  try
    FSize := FStream.Size;
    FHasSize := True;
  except
    FSize := -1;
    FHasSize := False;
  end;
end;

function TDunTifBinReader.Position: Int64;
begin
  Result := FStream.Position;
end;

procedure TDunTifBinReader.RequireReadable(ACount: Int64);
begin
  if ACount < 0 then
    raise EDunTifParseError.Create('DunTif: negative read size');
  if not FHasSize then
    Exit;
  if (FStream.Position < 0) or (FStream.Position + ACount > FSize) then
    raise EDunTifParseError.CreateFmt('DunTif: read out of bounds (pos=%d count=%d size=%d)',
      [FStream.Position, ACount, FSize]);
end;

procedure TDunTifBinReader.SeekAbs(AOffset: Int64);
begin
  if AOffset < 0 then
    raise EDunTifParseError.CreateFmt('DunTif: negative seek offset (%d)', [AOffset]);
  if FHasSize and (AOffset > FSize) then
    raise EDunTifParseError.CreateFmt('DunTif: seek out of bounds (off=%d size=%d)', [AOffset, FSize]);
  FStream.Position := AOffset;
end;

procedure TDunTifBinReader.ReadBuffer(var Buffer; ACount: Integer);
begin
  RequireReadable(ACount);
  if ACount <= 0 then
    Exit;
  FStream.ReadBuffer(Buffer, ACount);
end;

function TDunTifBinReader.ReadBytes(ACount: Integer): TBytes;
begin
  if ACount < 0 then
    raise EDunTifParseError.Create('DunTif: negative read size');
  SetLength(Result, ACount);
  if ACount = 0 then
    Exit;
  ReadBuffer(Result[0], ACount);
end;

function TDunTifBinReader.ReadU16: Word;
var
  b: array[0..1] of Byte;
begin
  ReadBuffer(b[0], 2);
  if FEndian = teLittle then
    Result := Word(b[0]) or (Word(b[1]) shl 8)
  else
    Result := Word(b[1]) or (Word(b[0]) shl 8);
end;

function TDunTifBinReader.ReadU32: Cardinal;
var
  b: array[0..3] of Byte;
begin
  ReadBuffer(b[0], 4);
  if FEndian = teLittle then
    Result := Cardinal(b[0]) or (Cardinal(b[1]) shl 8) or (Cardinal(b[2]) shl 16) or (Cardinal(b[3]) shl 24)
  else
    Result := Cardinal(b[3]) or (Cardinal(b[2]) shl 8) or (Cardinal(b[1]) shl 16) or (Cardinal(b[0]) shl 24);
end;

end.

