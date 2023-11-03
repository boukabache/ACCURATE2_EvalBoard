using System;

namespace accurate2_eval_gui_avalonia.ViewModels;

public partial class MainViewModel : ViewModelBase
{

    // Make an EventHandler OnConnectButtonClicked that MainWindow.axaml.cs can subscribe to
    public event EventHandler ?OnConnectButtonClicked;

    public void OnClickCommand()
    {
        // Trigger the event so that OnConnectButtonClicked in MainWindow.axaml.cs is called
        OnConnectButtonClicked?.Invoke(this, EventArgs.Empty);
    }
}

