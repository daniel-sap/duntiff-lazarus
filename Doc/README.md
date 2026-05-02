# DunTif

`DunTif` is a Free Pascal / Lazarus package for reading and writing **TIFF** files using a small domain model (`TDunTifDocument`) backed by **`TFPMemoryImage`** from **fcl-image** (`FPImage`).

The long-term goal is a **pure Pascal TIFF decoder** implemented incrementally (baseline first, then PackBits/LZW/Deflate, then JPEG-in-TIFF / YCbCr).

## Package layout

- `Source/`
  - `DunTif.Model.pas` — document model (`TDunTifDocument`) + optional `TDunTifMetadata`
  - `DunTif.ModelReader.pas` — load TIFF stream/file into `TDunTifDocument`
  - `DunTif.ModelWriter.pas` — save `TDunTifDocument` using **fcl-image** `TFPWriterTiff`
  - `DunTif.TiffTypes.pas` — shared TIFF-ish records/enums
  - `DunTif.BinReader.pas` — endian-aware binary reads + bounds checks (`EDunTifParseError`)
  - `DunTif.TiffParser.pas` — TIFF IFD parsing for Milestones 1–2 (`TDunTifTiffParser.ParseSingleFrame`)
  - `DunTif.DecodeRaster8.pas` — shared chunky 8-bit RGB/gray strip writer
  - `DunTif.DecodeBaseline.pas` — uncompressed strips → `TFPMemoryImage`
  - `DunTif.DecodePackBits.pas` — PackBits (`32773`) strips → `TFPMemoryImage`
- `Package/`
  - `DunTif.lpk` / `DunTif.pas`
- `Demo/`
  - small LCL demo app (`DunTifDemo.lpi`) that loads a TIFF and displays metadata + preview
- `Doc/`
  - `README.md` — this file (English)
  - `README.bg.md` — Bulgarian version
  - `ARCHITECTURE.md` / `ARCHITECTURE.bg.md` — module map + data flow
  - `TIFF_NOTES.md` / `TIFF_NOTES.bg.md` — TIFF tags/defaults + Milestones 1–2 limitations

## Dependencies (Lazarus package)

`DunTif.lpk` requires:

- `FCL`
- `fcl-image` (for `TFPMemoryImage` and `TFPWriterTiff`)

## Public API

### Reader

- `TDunTifModelReader.LoadFromStream(AStream: TStream): TDunTifDocument`
- `TDunTifModelReader.LoadFromFile(const AFileName: string): TDunTifDocument`

Errors are raised as `EDunTifError` (outer wrapper). Parsing/decoding failures may originate as `EDunTifParseError` (derived from `EDunTifError`) from low-level parsing code.

### Writer

- `TDunTifModelWriter.SaveToStream(AStream: TStream; ADoc: TDunTifDocument)`
- `TDunTifModelWriter.SaveToFile(const AFileName: string; ADoc: TDunTifDocument)`

Writing currently uses **fcl-image** `TFPWriterTiff` (not the pure Pascal encoder).

## Data model overview

### `TDunTifDocument`

- `Image: TFPMemoryImage` — raster pixels for one frame/page (current scope is **single IFD** parsing).
- `Width` / `Height` — convenience accessors over `Image`.
- `Metadata: TDunTifMetadata` — small decoded TIFF header fields useful for UI/logging:
  - `Compression`, `Photometric`, `SamplesPerPixel`, `BitsPerSample` (comma-separated text)

## Supported TIFF subset today (Milestones 1–2)

The pure Pascal path supports **strip TIFF** with **none** or **PackBits** compression:

- One IFD (single page)
- Strips only (no tiles)
- `Compression = 1` (none) or `Compression = 32773` (PackBits)
- `PhotometricInterpretation` in `{0,1,2}` (common grayscale / RGB baseline cases handled by validation)
- `BitsPerSample = 8`
- `PlanarConfiguration = 1` (chunky). If tag **284 is missing**, it defaults to **chunky** per TIFF convention.
- `SamplesPerPixel` in `{1,3}`

Anything outside this set should fail fast with a descriptive error.

## Roadmap (high level)

1. Milestone 1: baseline uncompressed RGB/Gray + strips (pure Pascal read path)
2. Milestone 2 (current): PackBits (`32773`) on the same photometric/planar subset as Milestone 1
3. Milestone 3: LZW (`5`) + Deflate (`8` / `32946`)
4. Milestone 4: JPEG-in-TIFF (`Compression=7`) + `Photometric=6` (YCbCr) conversion

See also:

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`TIFF_NOTES.md`](TIFF_NOTES.md)
