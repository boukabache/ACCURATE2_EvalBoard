using System;

namespace accurate2_eval_gui_avalonia.ViewModels;

public partial class MainViewModel : ViewModelBase
{

    public event EventHandler OnConnectButtonClicked;

    public void OnClickCommand()
    {
        // Trigger the event
        this.OnConnectButtonClicked.Invoke(this, EventArgs.Empty);
    }
}

