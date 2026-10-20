// Recast is fully offline: there is no update check and no in-app updater. This service only answers "which version
// is this" and where the source lives; nothing here touches the network. Newer versions are installed by hand.

using System.Reflection;
using CommunityToolkit.Mvvm.ComponentModel;

namespace Recast.App.Services;

/// <summary>Where an in-app update stands. Recast never updates itself, so it stays <see cref="Idle"/>.</summary>
public enum UpdateStep
{
    Idle,
    Downloading,
    Installing,
    Failed,
    Cancelled,
}

public sealed partial class UpdateService : ObservableObject
{
    /// <summary>Source repository from Directory.Build.props (RecastRepositoryUrl).</summary>
    public static string RepositoryUrl =>
        typeof(UpdateService).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .FirstOrDefault(a => a.Key == "RepositoryUrl")?.Value ?? "https://github.com/sree-charan/ferrule";

    public static string CurrentVersion =>
        typeof(UpdateService).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion.Split('+')[0]
        ?? typeof(UpdateService).Assembly.GetName().Version?.ToString(3) ?? "0.0.0";

    /// <summary>The repository's "new issue" page. Opened only when the user clicks.</summary>
    public static string NewIssueUrl => RepositoryUrl.TrimEnd('/') + "/issues/new/choose";

    public static string LatestReleaseUrl => RepositoryUrl.TrimEnd('/') + "/releases/latest";

    /// <summary>True when this copy was installed by Setup (Inno Setup puts its uninstaller next to Recast.exe).</summary>
    public static bool IsInstalled { get; } = OperatingSystem.IsWindows()
                                              && File.Exists(Path.Combine(AppContext.BaseDirectory, "unins000.exe"));

    /// <summary>
    /// True for published builds (<c>-p:RecastRelease=true</c>), false when running from source. Keeps development
    /// builds out of the registry.
    /// </summary>
    public static bool IsReleaseBuild =>
        typeof(UpdateService).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .Any(a => a.Key == "RecastRelease" && a.Value == "true");

    /// <summary>Always null: nothing is checked. Settable so tests can render the update UI.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsUpdateAvailable))]
    private string? _latestVersion;

    public bool IsUpdateAvailable => LatestVersion is not null;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Level), nameof(IsRequired), nameof(IsOptional))]
    private IReadOnlyList<ReleaseNote> _notes = [];

    public UpdateLevel Level => ReleaseNotes.Highest(Notes);

    public bool IsRequired => Level == UpdateLevel.Required;
    public bool IsOptional => Level == UpdateLevel.Optional;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsBusy))]
    private UpdateStep _step;

    [ObservableProperty] private int _downloadPercent;

    public bool IsBusy => Step is UpdateStep.Downloading or UpdateStep.Installing;

    /// <summary>Never raised: there is no update check.</summary>
    public event EventHandler<string>? UpdateFound { add { } remove { } }

    /// <summary>Never raised: there is no in-app updater.</summary>
    public event EventHandler? UpdateFailed { add { } remove { } }

    /// <summary>Offline: always null.</summary>
    public Task<string?> CheckAsync(CancellationToken cancellationToken = default) => Task.FromResult<string?>(null);

    /// <summary>Offline: does nothing.</summary>
    public void StartPeriodicChecks(Func<bool> enabled, TimeSpan firstDelay)
    {
    }

    /// <summary>Offline: does nothing.</summary>
    public Task UpdateAsync() => Task.CompletedTask;

    /// <summary>Offline: does nothing.</summary>
    public void OpenDownloadPage()
    {
    }

    /// <summary>True when release tag <paramref name="tag"/> ("v1.2.0") is a higher version than <paramref name="current"/>.</summary>
    internal static bool IsNewer(string? tag, string current) =>
        TryParse(tag, out var latest) && TryParse(current, out var installed) && latest > installed;

    /// <summary>"v1.2" / "1.2.0-beta+abc" → 1.2.0 (missing parts are 0, suffixes ignored).</summary>
    internal static bool TryParse(string? text, out Version version)
    {
        version = new Version(0, 0, 0);
        if (string.IsNullOrWhiteSpace(text))
            return false;
        var core = text.Trim().TrimStart('v', 'V').Split('-', '+')[0];
        if (!Version.TryParse(core.Contains('.') ? core : core + ".0", out var parsed))
            return false;
        version = new Version(parsed.Major, parsed.Minor, Math.Max(0, parsed.Build));
        return true;
    }
}
