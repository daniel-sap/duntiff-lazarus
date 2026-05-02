{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit DunTif;

{$warn 5023 off : no warning about unused units}
interface

uses
  DunTif.Model, DunTif.TiffTypes, DunTif.BinReader, DunTif.TiffParser, 
  DunTif.DecodeRaster8, DunTif.DecodeBaseline, DunTif.DecodePackBits, 
  DunTif.ModelReader, DunTif.ModelWriter, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('DunTif', @Register);
end.
