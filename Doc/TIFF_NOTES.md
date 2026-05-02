# TIFF notes for DunTif (Milestones 1–2)

This document summarizes what DunTif’s **pure Pascal** reader expects today and how it interprets a few TIFF conventions.

It is **not** a full TIFF specification. For the complete standard, refer to Adobe TIFF / TIFF 6.0 references.

## Scope

Milestones 1–2 focus on **strip images** with **uncompressed** or **PackBits** sample data:

- `Compression = 1` (none) or `Compression = 32773` (PackBits)
- `PhotometricInterpretation` in `{0,1,2}` (validated)
- `BitsPerSample = 8`
- `SamplesPerPixel` in `{1,3}`
- `PlanarConfiguration = 1` (chunky). If tag **284 is absent**, DunTif assumes **chunky** (default per TIFF practice).

For **`Compression = 32773`**, each `StripByteCounts` entry is the **compressed** byte length for that strip; after PackBits decompression the size must equal `rowsInStrip * width * bytesPerPixel`.

Not supported yet (planned milestones):

- Tiles (`TileWidth`, `TileLength`, …)
- LZW / Deflate / JPEG
- Photometric palette (`3`), CMYK (`5`), YCbCr (`6`), Lab (`8`), …
- ExtraSamples / alpha handling beyond “expand gray/RGB”
- Orientation (`274`) is **ignored** (pixels are read in stored order)

## Tags DunTif reads (minimum set)

These tags are expected for Milestone 1–2 decoding paths:

| Tag | ID | Notes |
|-----|---:|-------|
| ImageWidth | 256 | SHORT or LONG |
| ImageLength | 257 | SHORT or LONG |
| BitsPerSample | 258 | SHORT array; must match `SamplesPerPixel` (with small allowance noted in parser for some grayscale writers) |
| Compression | 259 | SHORT; must be `1` or `32773` |
| PhotometricInterpretation | 262 | SHORT; must be `0`, `1`, or `2` for Milestone 1–2 |
| StripOffsets | 273 | SHORT or LONG array |
| SamplesPerPixel | 277 | SHORT; must be `1` or `3` |
| RowsPerStrip | 278 | SHORT or LONG; must not be `0` |
| StripByteCounts | 279 | SHORT or LONG array; sizes must match strip layout |
| PlanarConfiguration | 284 | SHORT **optional**; if missing → chunky (`1`) |

## Strip layout assumptions

DunTif computes how many rows belong to each strip using:

- `RowsPerStrip`
- image height

For **uncompressed** (`Compression = 1`), each `StripByteCounts` value must be **at least** the raw size:

`rowsInStrip * width * bytesPerPixel`

where `bytesPerPixel` is `SamplesPerPixel` for 8-bit chunky storage.

For **PackBits** (`Compression = 32773`), `StripByteCounts` is the **compressed** size; decompression must yield exactly that raw size.

## Photometric interpretation values (subset)

Common TIFF values:

- `0` WhiteIsZero (min sample is white)
- `1` BlackIsZero (min sample is black)
- `2` RGB
- `6` YCbCr (often paired with JPEG compression in real-world TIFFs)

Milestone 1 accepts `0/1/2` only. Value `6` is expected to fail until the YCbCr/JPEG milestones.

## Errors you may see

- `EDunTifParseError`: invalid TIFF structure, unsupported tag typing for Milestones 1–2, out-of-bounds reads, strip size mismatch.
- `EDunTifError`: outer wrapper from `ModelReader`/`ModelWriter`.

Note: `ModelReader` contains legacy message augmentation for a few **fcl-image** error strings (`Photometric interpretation not handled …`). With the pure Pascal reader, those strings are uncommon; errors are usually DunTif’s own validation messages.

## Related docs

- [`README.md`](README.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
