# Recast

Recast is the file converter inside [Ferrule](../README.md): Ferrule's `build.sh` compiles its command line part
and embeds it in `Ferrule.app`, where Convert uses it. It also builds on its own, as below.

**A free, open-source, fully offline file converter you use by dragging.**
Hold a key (<kbd>Ctrl</kbd>, <kbd>Option</kbd> on macOS), drag files and drop them on a format in the donut that opens
at your cursor.

- **Right at your cursor**: no app window to open. Only the formats that make sense for the files you drag appear.
- **246 formats, no other software**: images, PDF, Word, Excel, PowerPoint, HWP, e-books, archives, fonts, CAD and 3D
  models work without Office or LibreOffice.
- **Stays on your computer**: nothing is uploaded, nothing is tracked, and Recast never goes online by itself.

## Install

Build it yourself (see [Development](#development)), then:

- **macOS 14+** (Apple Silicon or Intel): unpack the `osx-arm64` or `osx-x64` package and run `./install.sh`. It
  copies `Recast.app` to `~/Applications` and adds the `recast` command to `~/.local/bin`. Local builds are ad-hoc
  signed: allow the first start in System Settings → Privacy & Security → **Open Anyway**, then allow Recast under
  Accessibility (gestures) and Finder under Automation (selection shortcut).
- **Windows 10/11**: run `Recast-<version>-win-Setup.exe`, or unzip the portable zip and run `Recast.exe`.
- **Linux x64/ARM64** (Ubuntu 22.04+): unpack the package and run `./install.sh` (no root, needs Python 3).
  Drag gestures need X11. On Wayland, use the drop zone and the file manager's right-click menu.

## Features

- **A donut at the cursor**: hold a key, drag files and drop them on a format. Only formats that fit the files appear.
- **One toolbar per file type**, arranged by drag and drop, with presets for quality, size, DPI, PDF pages and compression,
  video and audio, output folder and file names.
- **Many files at once**, in parallel. Routes with several steps (HWP → HWPX → DOCX) are found automatically.
- **Watch folders** convert every file that lands in them.
- **Other ways in**: the right-click menu, a keyboard shortcut, the drop zone and the [`recast` command](#command-line).
- Light and dark themes, in English, Español, 한국어, 简体中文, Polski and हिन्दी.

## Formats

| From | To |
|---|---|
| **Images**: JPG, PNG, WEBP, AVIF, TIFF, BMP, GIF, APNG, ICO, ICNS, JPEG XL, JPEG 2000, PSD/PSB, TGA, PPM, HEIC, QOI, DDS, PCX, MNG, CUR, …; GIMP XCF, camera RAW (CR2, CR3, NEF, ARW, DNG, …), DICOM, OpenEXR, HDR, JPEG XR (Windows) read | any of these (HEIC⁵), PDF, SVG (traced), resized, grayscale |
| **Vector**: SVG, SVGZ, EMF, WMF, AI · EPS, PS¹ · CDR, VSD, CGM, ODG, FODG² | PDF (vector), PNG and other images, SVG ↔ SVGZ, SVG → DXF/DWG, PDF → EPS/PS¹, SVG → EMF, WMF, ODG² |
| **PDF** | DOCX, HWPX, TXT, PNG, JPG, TIFF, CBZ, PPTX (a picture of each page), SVG²; merge, split, page ranges, compress (smaller PDFs) |
| **Documents**: DOCX, DOCM, DOTX, EML, Outlook MSG · DOC, ODT, FODT, OTT, RTF, WPS, WPD, Pages, ClarisWorks, MacWrite, T602, …² | PDF, DOCX, HWPX, EPUB, TXT, HTML; MSG → EML · ODT, FODT, OTT² |
| **Spreadsheets**: XLSX, XLSM, XLS, XLT, ODS, CSV, TSV · OTS, FODS, Numbers, ET² | PDF, XLSX, ODS, CSV, TSV, JSON, HWPX, HTML · XLT, OTS² |
| **Presentations**: PPTX, PPTM, POTX, PPSX · PPT, ODP, OTP, FODP, Keynote² | PDF, PNG, JPG, DOCX, HWPX · OTP² |
| **HWP**: HWP, HWPX | PDF, PNG, DOCX, HWPX ↔ HWP, TXT, Markdown, HTML |
| **Text**: TXT, Markdown, HTML · reStructuredText, LaTeX, Org, AsciiDoc, Typst, MediaWiki, DocBook, Jupyter, Textile, man, OPML³ | PDF, DOCX, HWPX, EPUB · each other, PPTX slides³ |
| **E-books**: EPUB, KEPUB, MOBI, AZW3, AZW, AZW4, FB2, CBZ, CBR, CB7, HTMLZ, TXTZ · LIT, LRF, CHM, PDB, …⁴ | PDF, EPUB, KEPUB (Kobo), DOCX, TXT, HTML, HWPX · MOBI, AZW3⁴ |
| **Video**⁵: MP4, MOV, MKV, WEBM, AVI, WMV, FLV, MPEG, TS, M2TS, 3GP, OGV, VOB, … | MP4 (H.264, HEVC, AV1), WEBM, MOV, MKV, AVI, GIF, APNG, MP3, M4A, 720p, subtitles (SRT, ASS, WebVTT) |
| **Audio**⁵: MP3, M4A, AAC, WAV, FLAC, OGG, OPUS, WMA, AIFF, AMR, APE, WavPack, TTA, DSD (DSF, DFF), DTS, AC3, E-AC3, … | MP3, M4A (AAC, ALAC), WAV, FLAC, OGG, OPUS, AAC, WavPack, TTA, W64, AC3, E-AC3 |
| **Subtitles**: SRT, ASS/SSA, WebVTT, SAMI (SMI), LRC, TTML, MicroDVD, SCC | each other as UTF-8 (Korean CP949 files read correctly) |
| **Archives**: ZIP, 7Z, RAR, TAR, TAR.GZ, TAR.BZ2, TAR.XZ, GZ, ISO, CAB, DMG, ALZ, EGG, … | extract, ZIP, 7Z, TAR, TAR.GZ; any files → one ZIP |
| **CAD**: DWG, DXF | PDF, SVG, PNG, DWG ↔ DXF |
| **Fonts**: TTF, OTF, WOFF, WOFF2, EOT | each other |
| **Data**: JSON, JSON Lines, YAML, TOML, XML · vCard | each other, CSV and XLSX (tables); vCard ↔ CSV |
| **3D models**: GLB, glTF, STL, OBJ (+ MTL), 3MF, PLY; FBX read | each other, PNG preview |

Unmarked formats work out of the box, without Office, Hancom Office or LibreOffice.
Marked ones need an optional engine, downloaded only when needed: ¹ Ghostscript, ² LibreOffice, ³ Pandoc, ⁴ calibre,
⁵ FFmpeg ([details](docs/ENGINES.md)).

## Command line

The `recast` command uses the same engines and presets as the app (Setup or `install.sh` adds it).

```
recast convert photo.heic --to jpg
recast convert *.png --to webp --quality 80 -o converted
recast watch D:\Inbox --to pdf --move-originals
```

Every command and option: `recast help`.

## Development

Build with the .NET 10 SDK on Windows, macOS or Linux:

```bash
git clone https://github.com/sree-charan/ferrule.git
cd ferrule/Recast
pwsh build/fetch-engines.ps1 -Only rhwp,pandoc   # optional engines
dotnet run --project src/Recast.App
dotnet test
```

[Architecture](docs/ARCHITECTURE.md) · [Engines](docs/ENGINES.md) · [Adding a converter](docs/ADDING-A-CONVERTER.md) ·
[Adding a language](docs/ADDING-A-LANGUAGE.md) · [Contributing](CONTRIBUTING.md)

## Privacy

Recast converts files on your own computer and never uploads them. It collects no usage data, sends no telemetry,
has no update check and no accounts. Settings and logs stay in your user folder (`~/.config/Recast` on macOS and
Linux, `%APPDATA%\Recast` on Windows); set `RECAST_DATA_DIR` to keep them somewhere else.

It connects to the internet only when you press **Download** on the Engines page, which fetches that engine from the
official location pinned in [`engines.json`](src/Recast.Engines/Infrastructure/engines.json) and checks its SHA-256.
To stay fully offline, install engines yourself (for example `brew install ffmpeg pandoc ghostscript`) and Recast uses
them. Links in the app (GitHub, "report an issue") open your browser only when you click them.

## License

MIT, see [LICENSE](LICENSE). Bundled third-party components keep their own licenses, listed in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
