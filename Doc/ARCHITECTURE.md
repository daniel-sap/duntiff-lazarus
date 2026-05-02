# DunTif architecture

This document describes how the DunTif package is structured today and how data flows through the Milestone 1 reader path.

## Module map

| Unit | Responsibility |
|------|------------------|
| `DunTif.Model` | `TDunTifDocument` owns a `TFPMemoryImage` plus `TDunTifMetadata`. Defines `EDunTifError`. |
| `DunTif.BinReader` | Low-level stream reads with endian selection and bounds checks. Raises `EDunTifParseError`. |
| `DunTif.TiffTypes` | Shared enums/records (`TTiffFrame`, compression/photometric enums, etc.). |
| `DunTif.TiffParser` | Parses TIFF header + first IFD into `TTiffFrame` and validates Milestone 1 constraints. |
| `DunTif.DecodeBaseline` | Decodes uncompressed strip samples into `TFPMemoryImage` pixels (RGB or grayscale). |
| `DunTif.ModelReader` | Orchestrates parse + decode; fills `TDunTifDocument.Metadata`. |
| `DunTif.ModelWriter` | Saves using `TFPWriterTiff` (fcl-image). |

## Read path (Milestone 1)

```mermaid
flowchart LR
  tifStream[TStream]
  tiffParser[DunTifTiffParser]
  frame[TTiffFrame]
  baseline[DunTifBaselineDecoder]
  doc[TDunTifDocument]
  fpimg[TFPMemoryImage]

  tifStream --> tiffParser --> frame --> baseline --> fpimg
  doc --> fpimg
```

Details:

1. `TDunTifModelReader.LoadFromStream` calls `TDunTifTiffParser.ParseSingleFrame` which rewinds/parses from position 0 (after seeking internally via `TDunTifBinReader`).
2. `TDunTifBaselineDecoder.DecodeToFPImage` seeks to each strip offset and reads raw uncompressed bytes row-by-row into `TFPMemoryImage.Colors[x,y]` as `TFPColor`.

## Write path (current)

`TDunTifModelWriter` uses fcl-image `TFPWriterTiff` to serialize `TFPMemoryImage` to TIFF. This is independent from the pure Pascal reader stack.

## Exceptions

- `EDunTifError`: generic DunTif failures surfaced from `ModelReader`/`ModelWriter`.
- `EDunTifParseError`: parsing/binary safety failures (`DunTif.BinReader`, `DunTif.TiffParser`).

## Related docs

- [`README.md`](README.md)
- [`TIFF_NOTES.md`](TIFF_NOTES.md)
