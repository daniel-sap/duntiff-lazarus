# Бележки за TIFF спрямо DunTif (четец Milestones 1–4)

Този документ обобщава какво очаква **pure Pascal** четецът на DunTif днес и как тълкува някои TIFF конвенции.

Това **не е** пълна TIFF спецификация. За пълния стандарт виж официалните TIFF/TIFF6 материали.

## Обхват

Strip четецът поддържа **некомпресиран**, **PackBits**, **LZW**, **zlib Deflate** (Adobe `8` / TIFF `32946`) и **JPEG-in-TIFF** (`7`) при **8-bit chunky** подмножество:

- `Compression` в `{1, 5, 7, 8, 32946, 32773}`
- `PhotometricInterpretation` в `{0,1,2}` (компресии 1/5/8/32946/32773); при **JPEG** — `{6}` (YCbCr)
- `BitsPerSample = 8`
- `SamplesPerPixel` в `{1,3,4}` (`4` = RGBA, само Photometric RGB)
- `PlanarConfiguration = 1` (chunky). Ако таг **284 липсва**, DunTif приема **chunky** по TIFF практика.
- Таг **317 Predictor**: `1` (няма, по подразбиране ако липсва) или `2` (хоризонтална разлика). При `2` DunTif прави обратното след декомпресия на всеки strip.

При **`Compression = 32773`** всяка стойност в `StripByteCounts` е компресираният размер; след PackBits резултатът е суровият raster размер.

При **`Compression = 5`** strip-овете са TIFF **LZW** поток (модерен MSB-first). Много стари „обърнати битове“ файлове може да не се декодират.

При **`Compression = 8` или `32946`** всеки strip е **zlib** поток; inflate през FPC **PasZLib** (`paszlib`).

При **`Compression = 7`** всеки strip е **JPEG** поток (SOI…EOI без таблици в strip, ако има таг **347** `JPEGTables`). DunTif слепва таблиците (без завършващ `FF D9`) със strip тяло (без SOI) и декодира през **PasJPEG** / `TFPReaderJPEG` до RGB8.

Още не се поддържа:

- Tiles (`TileWidth`, `TileLength`, …)
- Old-style JPEG (`Compression=6`)
- YCbCr без JPEG (напр. LZW + `Photometric=6`)
- Палитра (`Photometric=3`), CMYK (`5`), Lab (`8`), …
- ExtraSamples извън RGBA (`SamplesPerPixel=4`, таг **338**)
- Gray+alpha (`SamplesPerPixel=2`), CMYK, палитра, …
- Orientation (`274`) — **не се прилага** (пикселите се четат в запаметения ред)

## Тагове, които DunTif чете (минимум)

| Таг | ID | Бележки |
|-----|---:|---------|
| ImageWidth | 256 | SHORT или LONG |
| ImageLength | 257 | SHORT или LONG |
| BitsPerSample | 258 | SHORT масив; трябва да съответства на `SamplesPerPixel` (с малко изключение за grayscale при някои писачи) |
| Compression | 259 | SHORT; `1`, `5`, `7`, `8`, `32946`, `32773` |
| PhotometricInterpretation | 262 | SHORT; `0`, `1`, `2` (или `6` при JPEG) |
| JPEGTables | 347 | UNDEFINED/BYTE, **по избор**; Huffman/quant таблици за JPEG |
| StripOffsets | 273 | SHORT или LONG масив |
| SamplesPerPixel | 277 | SHORT; `1`, `3` или `4` (RGBA) |
| ExtraSamples | 338 | SHORT масив; по избор; `2` = несвързан alpha |
| RowsPerStrip | 278 | SHORT или LONG; не може да е `0` |
| StripByteCounts | 279 | SHORT или LONG масив; компресирани размери при PackBits/LZW/Deflate |
| PlanarConfiguration | 284 | SHORT, **по избор**; ако липсва → chunky (`1`) |
| Predictor | 317 | SHORT, **по избор**; `1` или `2`; ако липсва → `1` |

## Strip layout — допускания

DunTif изчислява колко реда има във всеки strip чрез:

- `RowsPerStrip`
- височината на изображението

За **`Compression = 1`** всяка стойност в `StripByteCounts` трябва да е **поне** суровият размер:

`редовеВStrip * ширина * байтовеНаПиксел`

където `байтовеНаПиксел` е `SamplesPerPixel` при 8-bit chunky подреждане.

За **PackBits**, **LZW** или **Deflate**, `StripByteCounts` е компресираният размер във файла; след декомпресия (и predictor undo при таг **317 = 2**) трябва да се получи точно суровият raster размер.

## Photometric interpretation (подмножество)

Често срещани стойности:

- `0` WhiteIsZero
- `1` BlackIsZero
- `2` RGB
- `6` YCbCr (поддържано при `Compression=7` JPEG-in-TIFF)

Milestone 4 приема `Photometric=6` само заедно с `Compression=7`.

## Грешки, които може да видиш

- `EDunTifParseError` — невалидна TIFF структура, неподдържан тип на таг, четене извън потока, несъответствие на strip размери.
- `EDunTifError` — външен wrapper от `ModelReader`/`ModelWriter`.

Забележка: `ModelReader` все още има допълнение към съобщения за някои стари текстове от **fcl-image** (`Photometric interpretation not handled …`). При pure Pascal четене тези текстове са рядкост; типичните грешки са валидациите на DunTif.

## Свързани документи

- [`README.bg.md`](README.bg.md)
- [`ARCHITECTURE.bg.md`](ARCHITECTURE.bg.md)
