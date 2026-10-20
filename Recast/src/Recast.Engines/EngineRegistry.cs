// THE place where conversion engines are registered. Adding an engine = one line in CreateAll.

using Recast.Core.Conversion;
using Recast.Engines.Archives;
using Recast.Engines.Cad;
using Recast.Engines.Data;
using Recast.Engines.Ebooks;
using Recast.Engines.Email;
using Recast.Engines.Fonts;
using Recast.Engines.Hwp;
using Recast.Engines.Hwp.Hwpx;
using Recast.Engines.Icns;
using Recast.Engines.Infrastructure;
using Recast.Engines.Magick;
using Recast.Engines.Media;
using Recast.Engines.Models3D;
using Recast.Engines.Office;
using Recast.Engines.Pdf;
using Recast.Engines.Subtitles;
using Recast.Engines.Text;
using Recast.Engines.Vector;
using Recast.Engines.Wic;
using Microsoft.Extensions.Logging;

namespace Recast.Engines;

/// <summary>Creates every built-in converter.</summary>
public static class EngineRegistry
{
    /// <summary>
    /// Instantiates all converters. Order only matters as a tie-breaker when no priority is set, so it mirrors
    /// AppSettings.EnginePriority: built-in engines first, the optional downloads last. Software installed on the
    /// system (Microsoft Office, a system-wide LibreOffice) is never used.
    /// </summary>
    /// <param name="loggers">
    /// The app's log; FFmpeg writes which hardware encoders work and when one failed, LibreOffice when a file needed
    /// its container repacked.
    /// </param>
    public static IReadOnlyList<IConverter> CreateAll(EngineEnvironment env, ILoggerFactory? loggers = null) =>
    [
        new MagickImageConverter(),
        new PdfSharpConverter(),
        new PdfiumConverter(),
        new RhwpConverter(),
        new UnhwpConverter(),
        new MarkdownConverter(),
        new SpreadsheetConverter(),
        new OoxmlConverter(),
        new HwpxConverter(),
        new ArchiveConverter(),
        new VectorConverter(),
        new IcnsConverter(),
        new FontConverter(),
        new DocxWriterConverter(),
        new PdfTextConverter(),
        new PdfSlidesConverter(),
        new EmlConverter(),
        new DataConverter(),
        new SubtitleConverter(),
        new WicImageConverter(),
        new FfmpegConverter(loggers?.CreateLogger<FfmpegConverter>()),
        new CadConverter(),
        new ModelConverter(),
        new EbookConverter(),
        new PandocConverter(),
        new GhostscriptConverter(),
        new CalibreConverter(),
        new LibreOfficeConverter(env, loggers?.CreateLogger<LibreOfficeConverter>()),
    ];

    /// <summary>Finds the PDF merger among the converters.</summary>
    public static IPdfMerger? FindPdfMerger(IEnumerable<IConverter> converters) =>
        converters.OfType<IPdfMerger>().FirstOrDefault();

    /// <summary>Finds the engine that writes several pages into one multi-page TIFF.</summary>
    public static ITiffMerger? FindTiffMerger(IEnumerable<IConverter> converters) =>
        converters.OfType<ITiffMerger>().FirstOrDefault();

    /// <summary>Finds the engine that packs several files into one archive ("Compress into one archive").</summary>
    public static IFileCombiner? FindFileCombiner(IEnumerable<IConverter> converters) =>
        converters.OfType<IFileCombiner>().FirstOrDefault();
}
