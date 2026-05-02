# Бележки за TIFF спрямо DunTif (четец Milestones 1–3)

Този документ обобщава какво очаква **pure Pascal** четецът на DunTif днес и как тълкува някои TIFF конвенции.

Това **не е** пълна TIFF спецификация. За пълния стандарт виж официалните TIFF/TIFF6 материали.

## Обхват

Strip четецът поддържа **некомпресиран**, **PackBits**, **LZW** или **zlib Deflate** (Adobe `8` / TIFF `32946`) при същото **8-bit chunky RGB/gray** подмножество:

- `Compression` в `{1, 5, 8, 32946, 32773}`
- `PhotometricInterpretation` в `{0,1,2}` (валидирано)
- `BitsPerSample = 8`
- `SamplesPerPixel` в `{1,3}`
- `PlanarConfiguration = 1` (chunky). Ако таг **284 липсва**, DunTif приема **chunky** по TIFF практика.
- Таг **317 Predictor**: `1` (няма, по подразбиране ако липсва) или `2` (хоризонтална разлика). При `2` DunTif прави обратното след декомпресия на всеки strip.

При **`Compression = 32773`** всяка стойност в `StripByteCounts` е компресираният размер; след PackBits резултатът е суровият raster размер.

При **`Compression = 5`** strip-овете са TIFF **LZW** поток (модерен MSB-first). Много стари „обърнати битове“ файлове може да не се декодират.

При **`Compression = 8` или `32946`** всеки strip е **zlib** поток; inflate през FPC **PasZLib** (`paszlib`).

Още не се поддържа:

- Tiles (`TileWidth`, `TileLength`, …)
- JPEG / TIFF JPEG извън обхвата на този четец
- Палитра (`Photometric=3`), CMYK (`5`), YCbCr (`6`), Lab (`8`), …
- ExtraSamples / алфа канал извън простото разширяване до RGB
- Orientation (`274`) — **не се прилага** (пикселите се четат в запаметения ред)

## Тагове, които DunTif чете (минимум)

| Таг | ID | Бележки |
|-----|---:|---------|
| ImageWidth | 256 | SHORT или LONG |
| ImageLength | 257 | SHORT или LONG |
| BitsPerSample | 258 | SHORT масив; трябва да съответства на `SamplesPerPixel` (с малко изключение за grayscale при някои писачи) |
| Compression | 259 | SHORT; `1`, `5`, `8`, `32946`, `32773` |
| PhotometricInterpretation | 262 | SHORT; `0`, `1` или `2` |
| StripOffsets | 273 | SHORT или LONG масив |
| SamplesPerPixel | 277 | SHORT; `1` или `3` |
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
- `6` YCbCr (често с JPEG-in-TIFF в реални файлове)

Milestone 1 приема само `0/1/2`. Стойност `6` ще отпадне до милстоуните за JPEG/YCbCr.

## Грешки, които може да видиш

- `EDunTifParseError` — невалидна TIFF структура, неподдържан тип на таг, четене извън потока, несъответствие на strip размери.
- `EDunTifError` — външен wrapper от `ModelReader`/`ModelWriter`.

Забележка: `ModelReader` все още има допълнение към съобщения за някои стари текстове от **fcl-image** (`Photometric interpretation not handled …`). При pure Pascal четене тези текстове са рядкост; типичните грешки са валидациите на DunTif.

## Свързани документи

- [`README.bg.md`](README.bg.md)
- [`ARCHITECTURE.bg.md`](ARCHITECTURE.bg.md)
