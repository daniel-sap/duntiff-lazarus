# DunTif

`DunTif` е пакет за Free Pascal / Lazarus за четене и запис на **TIFF** файлове чрез малък домейн модел (`TDunTifDocument`), базиран на **`TFPMemoryImage`** от **fcl-image** (`FPImage`).

Дългосрочната цел е **чист Pascal TIFF декодер**, имплементиран стъпка по стъпка (първо baseline, после PackBits/LZW/Deflate, после JPEG-in-TIFF / YCbCr).

## Структура на пакета

- `Source/`
  - `DunTif.Model.pas` — модел на документ (`TDunTifDocument`) + опционално `TDunTifMetadata`
  - `DunTif.ModelReader.pas` — зареждане на TIFF поток/файл в `TDunTifDocument`
  - `DunTif.ModelWriter.pas` — запис на `TDunTifDocument` чрез **fcl-image** `TFPWriterTiff`
  - `DunTif.TiffTypes.pas` — общи TIFF типове/records/enums
  - `DunTif.BinReader.pas` — endian-aware бинарни четения + проверки на граници (`EDunTifParseError`)
  - `DunTif.TiffParser.pas` — `ReadFileHeader`, `ParseFrame`, `ParseSingleFrame` (само първи IFD)
  - `DunTif.DecodeRaster8.pas` — общ chunky 8-bit RGB/gray strip writer
  - `DunTif.DecodeBaseline.pas` — некомпресирани strips → `TFPMemoryImage`
  - `DunTif.DecodePackBits.pas` — PackBits (`32773`) strips → `TFPMemoryImage`
  - `DunTif.DecodePredictor.pas` — обратно horizontal predictor (таг 317 = 2)
  - `DunTif.TiffLzw.pas` / `DunTif.DecodeLzw.pas` — TIFF LZW (`5`)
  - `DunTif.DecodeDeflate.pas` — zlib strips (`8`, `32946`) чрез PasZLib (`paszlib`)
  - `DunTif.JpegDecode.pas` — JPEG strip → RGB8 (PasJPEG / `TFPReaderJPEG`)
  - `DunTif.DecodeJpeg.pas` — JPEG-in-TIFF strips (`7`) + `DecodeRaster8`
- `Package/`
  - `DunTif.lpk` / `DunTif.pas`
- `Demo/`
  - малко LCL демо (`DunTifDemo.lpi`) — преглед + показване на metadata
- `Doc/`
  - `README.md` — английска версия
  - `README.bg.md` — този файл (българска версия)
  - `ARCHITECTURE.md` / `ARCHITECTURE.bg.md` — архитектура и поток на данните
  - `TIFF_NOTES.md` / `TIFF_NOTES.bg.md` — тагове/defaults + ограничения на четеца

## Зависимости (Lazarus package)

`DunTif.lpk` изисква:

- `FCL`
- `fcl-image` (за `TFPMemoryImage` и `TFPWriterTiff`)
- **PasZLib** (Pascal zlib за Deflate inflate — без TIFF DLL)

## Публичен API

### Четене

- `TDunTifModelReader.LoadFromStream(AStream: TStream): TDunTifDocument`
- `TDunTifModelReader.LoadFromFile(const AFileName: string): TDunTifDocument`

Грешките се вдигат като `EDunTifError` (външен wrapper). Грешки от парсване/декод могат да започнат като `EDunTifParseError` (наследник на `EDunTifError`).

### Запис

- `TDunTifModelWriter.SaveToStream(AStream: TStream; ADoc: TDunTifDocument)`
- `TDunTifModelWriter.SaveToFile(const AFileName: string; ADoc: TDunTifDocument)`

Записът в момента ползва **fcl-image** `TFPWriterTiff` (не е „чист“ TIFF encoder).

## Модел на данните

### `TDunTifDocument`

- `Image: TFPMemoryImage` — растер за един кадър/страница (обхватът в момента е **един IFD**).
- `Width` / `Height` — удобни свойства върху `Image`.
- `Metadata: TDunTifMetadata` — накратко декодирани TIFF полета за UI/логване:
  - `Compression`, `Photometric`, `SamplesPerPixel`, `BitsPerSample` (текст със запетаи)

## Какво се поддържа днес (четец Milestones 1–4)

Pure Pascal четецът поддържа **strip TIFF** с компресии:

- Един IFD (една страница)
- Само strips (не tiles)
- `Compression` в `{1, 5, 7, 8, 32946, 32773}` — None, LZW, **JPEG**, Adobe Deflate, ZIP/Deflate, PackBits
- `PhotometricInterpretation` в `{0,1,2}` за компресии 1/5/8/32946/32773; за **JPEG (`7`)** — `{6}` (YCbCr → RGB в `TFPMemoryImage`)
- `BitsPerSample = 8`
- `PlanarConfiguration = 1` (chunky). Ако таг **284 липсва**, по конвенция се приема **chunky**.
- `SamplesPerPixel` в `{1,3}`
- `Predictor = 1` или `2`; ако таг **317 липсва** → **1**

Всичко извън този подмножество трябва да завърши с ясна грешка.

## Пътна карта (накратко)

1. Milestone 1: baseline некомпресиран RGB/Gray + strips (pure Pascal четене)
2. Milestone 2: PackBits (`32773`)
3. Milestone 3: LZW (`5`) + zlib Deflate strips (`8` / `32946`) + predictor таг **317**
4. Milestone 4 (текущ четец): JPEG-in-TIFF (`Compression=7`) + `Photometric=6` (YCbCr), таг **347** JPEGTables

Виж също:

- [`ARCHITECTURE.bg.md`](ARCHITECTURE.bg.md)
- [`TIFF_NOTES.bg.md`](TIFF_NOTES.bg.md)
