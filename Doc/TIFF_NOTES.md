# TIFF notes for DunTif (reader milestones 1–4)

This document summarizes what DunTif’s **pure Pascal** reader expects today and how it interprets a few TIFF conventions.

It is **not** a full TIFF specification. For the complete standard, refer to Adobe TIFF / TIFF 6.0 references.

## Scope

The strip reader supports **uncompressed**, **PackBits**, **LZW**, **zlib-wrapped Deflate** (Adobe `8` / TIFF `32946`), and **JPEG-in-TIFF** (`7`) on the same **8-bit chunky** subset:

- `Compression` in `{1, 5, 7, 8, 32946, 32773}`
- `PhotometricInterpretation` in `{0,1,2}` for non-JPEG; **`6` (YCbCr)** with `Compression=7`
- `BitsPerSample = 8`
- `SamplesPerPixel` in `{1,3}`
- `PlanarConfiguration = 1` (chunky). If tag **284 is absent**, DunTif assumes **chunky** (default per TIFF practice).
- `Predictor` tag **317**: `1` (none, default if absent) or `2` (horizontal differencing). For `2`, DunTif undoes differencing **after** decompressing each strip.

For **`Compression = 32773`**, each `StripByteCounts` entry is the **compressed** byte length for that strip; after PackBits decompression the size must equal `rowsInStrip * width * bytesPerPixel`.

For **`Compression = 5`**, strips contain TIFF **LZW** bitstreams (modern MSB-first packing). Old “bit-reversed” LZW files may not decode.

For **`Compression = 8` or `32946`**, each strip is a **zlib** stream (`CMF`/`FLG` + deflate + Adler); inflate uses FPC **PasZLib** (`paszlib`), not an external libtiff DLL.

For **`Compression = 7`**, each strip is a **JPEG** bitstream (tables often in tag **347** `JPEGTables`). DunTif merges tables (without trailing `FF D9`) with strip body (without SOI) and decodes via **PasJPEG** / `TFPReaderJPEG` to RGB8.

Not supported yet:

- Tiles (`TileWidth`, `TileLength`, …)
- Old-style JPEG (`Compression=6`)
- YCbCr without JPEG (e.g. LZW + `Photometric=6`)
- Photometric palette (`3`), CMYK (`5`), Lab (`8`), …
- ExtraSamples / alpha handling beyond “expand gray/RGB”
- Orientation (`274`) is **ignored** (pixels are read in stored order)

## Tags DunTif reads (minimum set)

These tags are used by the baseline strip decoding paths:

| Tag | ID | Notes |
|-----|---:|-------|
| ImageWidth | 256 | SHORT or LONG |
| ImageLength | 257 | SHORT or LONG |
| BitsPerSample | 258 | SHORT array; must match `SamplesPerPixel` (with small allowance noted in parser for some grayscale writers) |
| Compression | 259 | SHORT; `1`, `5`, `7`, `8`, `32946`, or `32773` |
| PhotometricInterpretation | 262 | SHORT; `0`, `1`, `2` (or `6` for JPEG) |
| JPEGTables | 347 | UNDEFINED/BYTE, **optional**; quantization/Huffman tables for JPEG |
| StripOffsets | 273 | SHORT or LONG array |
| SamplesPerPixel | 277 | SHORT; must be `1` or `3` |
| RowsPerStrip | 278 | SHORT or LONG; must not be `0` |
| StripByteCounts | 279 | SHORT or LONG array; compressed sizes for PackBits/LZW/Deflate |
| PlanarConfiguration | 284 | SHORT **optional**; if missing → chunky (`1`) |
| Predictor | 317 | SHORT **optional**; `1` or `2`; if missing → `1` |

## Strip layout assumptions

DunTif computes how many rows belong to each strip using:

- `RowsPerStrip`
- image height

For **uncompressed** (`Compression = 1`), each `StripByteCounts` value must be **at least** the raw size:

`rowsInStrip * width * bytesPerPixel`

where `bytesPerPixel` is `SamplesPerPixel` for 8-bit chunky storage.

For **PackBits**, **LZW**, or **Deflate**, `StripByteCounts` is the **compressed** strip size in the file; after decompression (and predictor undo when tag **317 = 2**) the raster must match `rowsInStrip * width * bytesPerPixel` raw bytes.

## Photometric interpretation values (subset)

Common TIFF values:

- `0` WhiteIsZero (min sample is white)
- `1` BlackIsZero (min sample is black)
- `2` RGB
- `6` YCbCr (often paired with JPEG compression in real-world TIFFs)

Milestone 4 accepts `Photometric=6` only together with `Compression=7` (JPEG-in-TIFF).

## Errors you may see

- `EDunTifParseError`: invalid TIFF structure, unsupported tag typing, out-of-bounds reads, strip size mismatch.
- `EDunTifError`: outer wrapper from `ModelReader`/`ModelWriter`.

Note: `ModelReader` contains legacy message augmentation for a few **fcl-image** error strings (`Photometric interpretation not handled …`). With the pure Pascal reader, those strings are uncommon; errors are usually DunTif’s own validation messages.

## Related docs

- [`README.md`](README.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
