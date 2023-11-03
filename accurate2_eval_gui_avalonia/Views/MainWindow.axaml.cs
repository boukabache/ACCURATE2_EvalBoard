using Avalonia.Controls;
using System.IO.Ports;
using Usb.Events;
using System.Linq;
using System.Collections.Generic;
using System;
using Avalonia.Threading;
using accurate2_eval_gui_avalonia.ViewModels;

namespace accurate2_eval_gui_avalonia.Views;

public partial class MainWindow : Window
{

    string[] serialPorts = SerialPort.GetPortNames();
    int clickCount1;
    readonly SerialPort arduinoPort = new SerialPort();


    public MainWindow()
    {
        InitializeComponent();


        // Check if the DataContext is the correct ViewModel type and subscribe to the OnConnectButtonClicked event
        DataContextChanged += (o, e) => {
            if (DataContext is MainViewModel)
            {
                var viewModel = DataContext;
                (DataContext as MainViewModel).OnConnectButtonClicked += ConnectUSB;
            }
        };

        // Subscribe to OnConnectButtonClicked event from MainViewModel and call ConnectMe method when event is raised
        // Select the already made instance of MainViewModel


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

    public void USBEventArrived()
    {
        serialPorts = SerialPort.GetPortNames();
        // USe Dispatcher.UIThread.Invoke to update UI


        ComboBox portComboBox = this.Find<ComboBox>("portComboBox") ?? throw new ArgumentException();
        List<string> serialPortsList = serialPorts.ToList();
        portComboBox.ItemsSource = serialPortsList;
        portComboBox.SelectedIndex = 0;


    }

    private void ConnectUSB(object? sender, EventArgs e)
    {
        ComboBox portComboBox = this.Find<ComboBox>("portComboBox") ?? throw new ArgumentException();


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
                    //MessageBox.Show("Failed to disconnect device.", "Connection Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }

                //dispatcherTimer.Stop();
                connectedTime.Content = "Disconnected";
                ConnectButton.Content = "Connect";

                break;

            case 1:
                onButton.IsEnabled = true;
                offButton.IsEnabled = false;
                /*if (portComboBox.SelectedValue != null)
                {
                    string portName = portComboBox.SelectedValue.ToString() ?? throw new ArgumentException();
                    arduinoPort.PortName = portName;
                }
                else
                {
                    //MessageBox.Show("Please select a valid port.", "Connection Error", MessageBoxButton.OK, MessageBoxImage.Error);
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
                    //MessageBox.Show("Failed to connect to device.", "Connection Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }*/

                //dispatcherTimer.Start();
                ConnectButton.Content = "Disconnect";

                break;
        }
    }
}
