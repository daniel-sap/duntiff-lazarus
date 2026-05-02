# Бележки за TIFF спрямо DunTif (Milestone 1)

Този документ обобщава какво очаква **pure Pascal** четецът на DunTif днес и как тълкува някои TIFF конвенции.

Това **не е** пълна TIFF спецификация. За пълния стандарт виж официалните TIFF/TIFF6 материали.

## Обхват

Milestone 1 е насочен към **baseline некомпресирани strip изображения**:

- `Compression = 1` (none)
- `PhotometricInterpretation` в `{0,1,2}` (валидирано)
- `BitsPerSample = 8`
- `SamplesPerPixel` в `{1,3}`
- `PlanarConfiguration = 1` (chunky). Ако таг **284 липсва**, DunTif приема **chunky** по TIFF практика.

Още не се поддържа (следващи милстоуни):

- Tiles (`TileWidth`, `TileLength`, …)
- Компресии PackBits / LZW / Deflate / JPEG
- Палитра (`Photometric=3`), CMYK (`5`), YCbCr (`6`), Lab (`8`), …
- ExtraSamples / алфа канал извън простото разширяване до RGB
- Orientation (`274`) — **не се прилага** (пикселите се четат в запаметения ред)

## Тагове, които DunTif чете (минимум за Milestone 1)

| Таг | ID | Бележки |
|-----|---:|---------|
| ImageWidth | 256 | SHORT или LONG |
| ImageLength | 257 | SHORT или LONG |
| BitsPerSample | 258 | SHORT масив; трябва да съответства на `SamplesPerPixel` (с малко изключение за grayscale при някои писачи) |
| Compression | 259 | SHORT; трябва да е `1` |
| PhotometricInterpretation | 262 | SHORT; за Milestone 1 трябва да е `0`, `1` или `2` |
| StripOffsets | 273 | SHORT или LONG масив |
| SamplesPerPixel | 277 | SHORT; `1` или `3` |
| RowsPerStrip | 278 | SHORT или LONG; не може да е `0` |
| StripByteCounts | 279 | SHORT или LONG масив; трябва да отговаря на strip layout |
| PlanarConfiguration | 284 | SHORT, **по избор**; ако липсва → chunky (`1`) |

## Strip layout — допускания

DunTif изчислява колко реда има във всеки strip чрез:

- `RowsPerStrip`
- височината на изображението

След това проверява дали всеки strip има достатъчно байтове за:

`редовеВStrip * ширина * байтовеНаПиксел`

където `байтовеНаПиксел` е `SamplesPerPixel` при 8-bit chunky подреждане.

## Photometric interpretation (подмножество)

Често срещани стойности:

- `0` WhiteIsZero
- `1` BlackIsZero
- `2` RGB
- `6` YCbCr (често с JPEG-in-TIFF в реални файлове)

Milestone 1 приема само `0/1/2`. Стойност `6` ще отпадне до милстоуните за JPEG/YCbCr.

## Грешки, които може да видиш

- `EDunTifParseError` — невалидна TIFF структура, неподдържан тип на таг за Milestone 1, четене извън потока, несъответствие на strip размери.
- `EDunTifError` — външен wrapper от `ModelReader`/`ModelWriter`.

Забележка: `ModelReader` все още има допълнение към съобщения за някои стари текстове от **fcl-image** (`Photometric interpretation not handled …`). При pure Pascal четене тези текстове са рядкост; типичните грешки са валидациите на DunTif.

## Свързани документи

- [`README.bg.md`](README.bg.md)
- [`ARCHITECTURE.bg.md`](ARCHITECTURE.bg.md)
