# Архитектура на DunTif

Този документ описва как е организиран пакетът DunTif и как минава потокът от данни при Milestones 1–2 (четене).

## Карта на модулите

| Unit | Отговорност |
|------|-------------|
| `DunTif.Model` | `TDunTifDocument` притежава `TFPMemoryImage` и `TDunTifMetadata`. Дефинира `EDunTifError`. |
| `DunTif.BinReader` | Ниско ниво четене от поток с endian и проверки на граници. Вдига `EDunTifParseError`. |
| `DunTif.TiffTypes` | Общи enums/records (`TTiffFrame`, compression/photometric и др.). |
| `DunTif.TiffParser` | Парсва TIFF header + първи IFD към `TTiffFrame` и валидира ограниченията за Milestones 1–2. |
| `DunTif.DecodeRaster8` | Записва декодирани chunky 8-bit strip проби в `TFPMemoryImage` (общо за декодерите). |
| `DunTif.DecodeBaseline` | Чете некомпресирани strip байтове и подава към `DecodeRaster8`. |
| `DunTif.DecodePackBits` | Разкомпресира PackBits strips и подава към `DecodeRaster8`. |
| `DunTif.ModelReader` | Оркестрира parse + decode; попълва `TDunTifDocument.Metadata`. |
| `DunTif.ModelWriter` | Запис чрез `TFPWriterTiff` (fcl-image). |

## Път при четене (Milestones 1–2)

```mermaid
flowchart LR
  tifStream[TStream]
  tiffParser[DunTifTiffParser]
  frame[TTiffFrame]
  decode{Compression}
  baseline[DunTifBaselineDecoder]
  packbits[DunTifPackBitsDecoder]
  doc[TDunTifDocument]
  fpimg[TFPMemoryImage]

  tifStream --> tiffParser --> frame --> decode
  decode -->|1| baseline --> fpimg
  decode -->|32773| packbits --> fpimg
  doc --> fpimg
```

Подробности:

1. `TDunTifModelReader.LoadFromStream` извиква `TDunTifTiffParser.ParseSingleFrame`, който парсва TIFF от началото на потока (вътрешно през `TDunTifBinReader`).
2. Според `TTiffFrame.Compression` се извиква или `TDunTifBaselineDecoder`, или `TDunTifPackBitsDecoder`, които попълват `TFPMemoryImage` чрез `TDunTifRaster8.WriteChunkyStrip` (`Colors[x,y]` като `TFPColor`).

## Път при запис (текущ)

`TDunTifModelWriter` сериализира `TFPMemoryImage` към TIFF чрез fcl-image `TFPWriterTiff`. Това е независимо от pure Pascal четенето.

## Изключения

- `EDunTifError` — общи грешки от reader/writer.
- `EDunTifParseError` — грешки при парсване/безопасност на четене (`DunTif.BinReader`, `DunTif.TiffParser`).

## Свързани документи

- [`README.bg.md`](README.bg.md)
- [`TIFF_NOTES.bg.md`](TIFF_NOTES.bg.md)
