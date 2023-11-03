using Avalonia.Controls;
using System.IO.Ports;
using Usb.Events;
using System.Linq;
using System.Collections.Generic;
using System;
using Avalonia.Threading;
using accurate2_eval_gui_avalonia.ViewModels;
using MsBox.Avalonia.Enums;
using MsBox.Avalonia;
using Avalonia.Styling;
using MsBox.Avalonia.Dto;
using System.Threading.Tasks;
using MsBox.Avalonia.Models;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace accurate2_eval_gui_avalonia.Views;

public partial class MainWindow : Window
{

    string[] serialPorts = SerialPort.GetPortNames();
    int clickCount1;
    readonly SerialPort arduinoPort = new SerialPort();


    public MainWindow()
    {
        InitializeComponent();

        DataContextChanged += (o, e) => {
            if (DataContext is MainViewModel)
            {
                var viewModel = DataContext;
                var context = DataContext as MainViewModel;
                if (context != null)
                {
                    context.OnConnectButtonClicked += ConnectUSB;
                }
            }
        };

        Dispatcher.UIThread.InvokeAsync(() => USBEventArrived());
        UsbEventWatcher usbEventWatcher = new UsbEventWatcher();
        usbEventWatcher.UsbDeviceAdded += (sender, args) =>
        {
            Dispatcher.UIThread.InvokeAsync(() => USBEventArrived());
        };

        usbEventWatcher.UsbDeviceRemoved += (sender, args) =>
        {
            Dispatcher.UIThread.InvokeAsync(() => USBEventArrived());
        };

    }

    // This method is called when the USBEventWatcher detects a USB device has been added or removed
    // from the system and updates the portComboBox with the new list of available ports
    public void USBEventArrived()
    {
        serialPorts = SerialPort.GetPortNames();
        ComboBox portComboBox = this.Find<ComboBox>("portComboBox") ?? throw new ArgumentException();
        List<string> serialPortsList = serialPorts.ToList();
        portComboBox.ItemsSource = serialPortsList;
        portComboBox.SelectedIndex = 0;
    }

    // This method is called when the ConnectButton is clicked and handles the connection and disconnection
    private async void ConnectUSB(object? sender, EventArgs e)
    {

        if (!(clickCount1 == 1))
        {
            clickCount1 = 1;
        }
        else
        {
            clickCount1 = 0;
        }

        switch (clickCount1)
        {
            case 0:
                onButton.IsEnabled = false;
                offButton.IsEnabled = false;
                try
                {
                    if (arduinoPort.IsOpen == true)
                    {
                        arduinoPort.Close();
                    }
                }
                catch
                {
                    MessageBoxError("Failed to disconnect device.", "Connection Error");
                }

                //dispatcherTimer.Stop();
                connectedTime.Content = "Disconnected";
                ConnectButton.Content = "Connect";

                break;

            case 1:
                onButton.IsEnabled = true;
                offButton.IsEnabled = false;
                if (portComboBox.SelectedValue != null)
                {
                    string portName = portComboBox.SelectedValue.ToString() ?? throw new ArgumentException();
                    arduinoPort.PortName = portName;
                }
                else
                {
                    MessageBoxError("Please select a valid port.", "Connection Error");
                }

                try
                {
                    if (arduinoPort.IsOpen == false)
                    {
                        arduinoPort.Open();
                    }
                }

                catch
                {
                    MessageBoxError("Failed to connect to device.", "Connection Error");
                }
                //dispatcherTimer.Start();
                ConnectButton.Content = "Disconnect";

                break;
        }
    }

    public async void MessageBoxError(string message, string title, ButtonEnum buttons = ButtonEnum.Ok)
    {
        var messageBox = MessageBoxManager.GetMessageBoxCustom(
            new MessageBoxCustomParams
            {
                ButtonDefinitions = new List<ButtonDefinition>
                {
            new ButtonDefinition { Name = "Ok", },
                },
                ContentTitle = title,
                ContentMessage = message,
                Icon = MsBox.Avalonia.Enums.Icon.Error,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false,
                MaxWidth = 500,
                MaxHeight = 800,
                SizeToContent = SizeToContent.WidthAndHeight,
                ShowInCenter = true,
                Topmost = false,
            });

        var result = await messageBox.ShowAsync();

    }
}
