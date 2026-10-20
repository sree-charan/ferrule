// System.Text.Json source generation for everything Recast persists. Reflection-free and trim-safe.

using System.Text.Json.Serialization;
using Recast.Core.History;
using Recast.Core.Presets;
using Recast.Core.Profiles;

namespace Recast.Core.Settings;

[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    UseStringEnumConverter = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    ReadCommentHandling = System.Text.Json.JsonCommentHandling.Skip,
    AllowTrailingCommas = true)]
[JsonSerializable(typeof(AppSettings))]
[JsonSerializable(typeof(List<Preset>))]
[JsonSerializable(typeof(List<ToolbarProfile>))]
[JsonSerializable(typeof(PresetBundle))]
[JsonSerializable(typeof(List<HistoryEntry>))]
internal sealed partial class RecastJsonContext : JsonSerializerContext;

/// <summary>File format used to import / export presets and profiles.</summary>
public sealed class PresetBundle
{
    public int SchemaVersion { get; set; } = 1;
    public List<Preset> Presets { get; set; } = [];
    public List<ToolbarProfile> Profiles { get; set; } = [];
}
