using Avalonia.Controls;
using Recast.App.Services;
using Recast.App.ViewModels;

namespace Recast.App.Views;

public partial class EngineSetupWindow : Window
{
    public EngineSetupWindow()
    {
        InitializeComponent();
        Motion.Track(this);
        DataContextChanged += (_, _) =>
        {
            if (DataContext is EngineSetupViewModel vm)
                vm.CloseRequested += (_, _) => Close();
        };
    }
}
