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
using MsBox.Avalonia.Dto;
using MsBox.Avalonia.Models;

namespace accurate2_eval_gui_avalonia.Views;

public partial class MainWindow : Window
{

    string[] serialPorts = SerialPort.GetPortNames();
    int clickCount1;
    readonly SerialPort arduinoPort = new();
    readonly DispatcherTimer dispatcherTimer;
    TimeSpan time;


    public MainWindow()
    {
        InitializeComponent();

        // Countdown timer init
        time = TimeSpan.FromSeconds(1);
        dispatcherTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1)
        };
        // Check that dispatcherTimer_Tick is not null and subscribe to it
        dispatcherTimer.Tick += DispatcherTimer_Tick;


        arduinoPort.ReadTimeout = 1000;
        arduinoPort.WriteTimeout = 1000;

        DataContextChanged += (o, e) => {
            if (DataContext is MainViewModel)
            {
                var viewModel = DataContext;
                if (DataContext is MainViewModel context)
                {
                    context.OnConnectButtonClicked += ConnectUSB;
                }
            }
        };

        Dispatcher.UIThread.InvokeAsync(() => USBEventArrived());
        UsbEventWatcher usbEventWatcher = new();
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
    private void ConnectUSB(object? sender, EventArgs e)
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

                dispatcherTimer.Stop();
                connectedTime.Content = "Disconnected";
                ConnectButton.Content = "Connect";

                break;

            case 1:
                onButton.IsEnabled = true;
                offButton.IsEnabled = false;
                if (portComboBox.SelectedValue is not null)
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
                        try
                        {
                            // Check if Arduino is sending data by sending a command and waiting for a response and test WriteTimeout
                            arduinoPort.WriteLine("Hello");
                            if (arduinoPort.ReadLine() == "Hello")
                            {
                                connectedTime.Content = "Connected";
                                ConnectButton.Content = "Disconnect";
                                onButton.IsEnabled = true;
                                offButton.IsEnabled = true;
                                dispatcherTimer.Start();
                            }
                            else
                            {
                                MessageBoxError("Failed to connect to device, wrong response received.", "Connection Error");
                                arduinoPort.Close();
                            }   
                        }
                        catch
                        {
                            MessageBoxError("Failed to connect to device, no response received.", "Connection Error");
                            arduinoPort.Close();
                        }
                    }
                }

                catch
                {
                    MessageBoxError("Failed to connect to device.", "Connection Error");
                }

                break;
        }
    }

    // Device connection timekeeping
    private void DispatcherTimer_Tick(object? sender, EventArgs e)
    {
        if (time == TimeSpan.Zero) dispatcherTimer.Stop();
        else
        {
            time = time.Add(TimeSpan.FromSeconds(+1));
            string timeString = "Connected for " + time.ToString("c");
            connectedTime.Content = timeString;
        }
    }

    public static async void MessageBoxError(string message, string title)
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

        await messageBox.ShowAsync();
        return;
    }
}
