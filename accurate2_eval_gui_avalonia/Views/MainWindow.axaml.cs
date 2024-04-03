using Avalonia.Controls;
using System.IO.Ports;
using Usb.Events;
using System.Linq;
using System.Collections.Generic;
using System;
using Avalonia.Threading;
using accurate2_eval_gui_avalonia.ViewModels;
using MsBox.Avalonia;
using MsBox.Avalonia.Dto;
using MsBox.Avalonia.Models;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Platform.Storage;
using System.Globalization;
using CsvHelper;
using Avalonia.Media;

namespace accurate2_eval_gui_avalonia.Views;

public partial class MainWindow : Window
{
    string[] serialPorts = SerialPort.GetPortNames();
    int clickCount1;
    readonly SerialPort arduinoPort = new();
    readonly DispatcherTimer dispatcherTimer;
    TimeSpan time;
    private UsbEventWatcher usbEventWatcher;

    // Class variables for device communication and tracking.
    private double totalCurrent = 0; // Accumulates current measurements for averaging.
    private int currentReadingsCount = 0; // Tracks the number of readings received.

    // Constants for device communication.
    private const int ReadTimeout = 5000;
    private const int WriteTimeout = 5000;
    private const int BaudRate = 9600;

    // Initializes the main components and sets up event listeners.
    public MainWindow()
    {
        InitializeComponent();

        // Countdown timer init
        time = TimeSpan.FromSeconds(1);
        serialPorts = SerialPort.GetPortNames();
        arduinoPort = new SerialPort();
        dispatcherTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1)
        };
        // Check that dispatcherTimer_Tick is not null and subscribe to it
        dispatcherTimer.Tick += DispatcherTimer_Tick;


        arduinoPort.ReadTimeout = ReadTimeout;
        arduinoPort.WriteTimeout = WriteTimeout;
        arduinoPort.BaudRate = BaudRate;
        arduinoPort.DtrEnable = true;

        DataContextChanged += (o, e) => {
            if (DataContext is MainViewModel)
            {
                var viewModel = DataContext;
                if (DataContext is MainViewModel context)
                {
                    context.OnConnectButtonClicked += ConnectUSB;
                    context.OnExportButtonClicked += ExportData;
                    context.OnResetDataButtonClicked += ResetData;
                }
            }
        };

        Dispatcher.UIThread.InvokeAsync(() => USBEventArrived());
        usbEventWatcher = new UsbEventWatcher();
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
    // Logic to handle USB device connection changes, updating available serial ports.
    public void USBEventArrived()
    {
        serialPorts = SerialPort.GetPortNames();
        ComboBox portComboBox = this.Find<ComboBox>("portComboBox") ?? throw new ArgumentException();
        List<string> serialPortsList = serialPorts.ToList();
        portComboBox.ItemsSource = serialPortsList;
        portComboBox.SelectedIndex = 0;
    }

    // This method is called when the ConnectButton is clicked and handles the connection and disconnection
    // Manages the state and actions of USB connection.
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
                liveCurrent.Content = "N/A fA";
                ConnectButtonLabel.Content = "Connect";

                break;

            case 1:
                if (portComboBox.SelectedValue is not null)
                {
                    string portName = portComboBox.SelectedValue.ToString() ?? throw new ArgumentException();
                    arduinoPort.PortName = portName;
                }
                else
                {
                    MessageBoxError("Please select a valid port.", "Connection Error");
                    return;
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
                            if (arduinoPort.ReadLine() != "")
                            {
                                connectedTime.Content = "Connected";
                                ConnectButtonLabel.Content = "Disconnect";
                                dispatcherTimer.Start();
                                time = TimeSpan.FromSeconds(1);
                                Task.Run(() => ReadDataFromUSB());
                            } 
                        }
                        catch (Exception ex)
                        {
                            Dispatcher.UIThread.InvokeAsync(() => MessageBoxError("Failed to connect to device: " + ex.Message, "Connection Error"));
                            arduinoPort.Close();
                        }
                    }
                }

                catch (Exception ex)
                {
                    Dispatcher.UIThread.InvokeAsync(() => MessageBoxError("Failed to connect to device: " + ex.Message, "Connection Error"));
                }

                break;

        }
    }

    // Asynchronously reads data from USB, handling potential errors and disconnections.
    private async void ReadDataFromUSB()
    {
        while (arduinoPort.IsOpen)
        {
            try
            {
                string data = await Task.Run(() => arduinoPort.ReadLine());
                await Dispatcher.UIThread.InvokeAsync(() => ParseAndSendDataToViewModel(data));
            }
            catch (TimeoutException ex)
            {
                await Dispatcher.UIThread.InvokeAsync(() => MessageBoxError("Device timed out: " + ex.Message, "Connection Error"));
                arduinoPort.Close();
            }
            catch (IOException ex)
            {
                await Dispatcher.UIThread.InvokeAsync(() => MessageBoxError("Device disconnected: " + ex.Message, "Connection Error"));
                arduinoPort.Close();
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                await Dispatcher.UIThread.InvokeAsync(() => MessageBoxError("An error occurred: " + ex.Message, "Error"));
                arduinoPort.Close();
            }
        }
    }

    private void ParseAndSendDataToViewModel(string data)
    {
        // Extracting and converting data from the received string format.
        var parts = data.Split(',');
        if (parts.Length == 4)
        {
            // Assuming the current value received from the device is in femtoamps (fA) and needs conversion to Amperes (A).
            if (double.TryParse(parts[0], out double currentInFemtoAmps) &&
                double.TryParse(parts[1], out double temperature) &&
                double.TryParse(parts[2], out double humidity))
            {
                // Convert the binary string to an integer for button and LED states.
                string btnLedBinaryString = parts[3];
                // Ensure the binary string is correctly padded to the expected length.
                btnLedBinaryString = btnLedBinaryString.PadLeft(6, '0');
                int btnLedStatus = Convert.ToInt32(btnLedBinaryString, 2); // Convert binary string to integer.

                bool btn0Activated = (btnLedStatus & 0x20) != 0; // 0x20 = 0010 0000
                bool btn1Activated = (btnLedStatus & 0x10) != 0; // 0x10 = 0001 0000
                bool btn2Activated = (btnLedStatus & 0x08) != 0; // 0x08 = 0000 1000
                bool led0Activated = (btnLedStatus & 0x04) != 0; // 0x04 = 0000 0100
                bool led1Activated = (btnLedStatus & 0x02) != 0; // 0x02 = 0000 0010
                bool led2Activated = (btnLedStatus & 0x01) != 0; // 0x01 = 0000 0001

                // Convert current from femtoamps to amperes by dividing by 10^15.
                double currentInAmperes = currentInFemtoAmps / 1e15;

                totalCurrent += currentInAmperes; // Accumulate the converted current for averaging.
                currentReadingsCount++;
                SamplesText.Content = currentReadingsCount.ToString() + " samples since first connection";

                double calculatedAverageCurrent = totalCurrent / currentReadingsCount;

                if (DataContext is MainViewModel viewModel)
                {
                    viewModel.UpdateGraphs(currentInAmperes, temperature, humidity);
                    liveCurrent.Content = currentInAmperes.ToString("N2") + " A"; // Display in Amperes with two decimal places.
                    averageCurrent.Content = calculatedAverageCurrent.ToString("N2") + " A"; // Display average in Amperes.
                }

                UpdateButtonAndLedStates(btn0Activated, btn1Activated, btn2Activated, led0Activated, led1Activated, led2Activated);
            }
        }
    }
    // Provides functionality for exporting data to a CSV file, with file saving dialog.
    private async void ExportData(object? sender, EventArgs e)
    {
        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel != null)
        {
            var file = await topLevel.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Save CSV File",
                SuggestedFileName = "Accurate2A_" + DateTime.Now.ToString("yyyyMMdd_HHmmss"),
                DefaultExtension = "csv",
                FileTypeChoices = new List<FilePickerFileType>()
                {
                    new("Comma-separated values (CSV)")
                    {
                        Patterns = new List<string>() { "*.csv" }
                    }
                }
            });

            if (file is not null)
            {
                await using var stream = await file.OpenWriteAsync();
                using var streamWriter = new StreamWriter(stream);
                using var csvWriter = new CsvWriter(streamWriter, CultureInfo.InvariantCulture);

                if (DataContext != null)
                {
                    var viewModel = (MainViewModel)DataContext;

                    // Chain two Zip calls to combine three sequences
                    var combinedData = viewModel.CurrentValues
                        .Zip(viewModel.TemperatureValues, (current, temperature) => new { current, temperature })
                        .Zip(viewModel.HumidityValues, (ct, humidity) => new
                        {
                            Current = ct.current.Value,
                            Temperature = ct.temperature.Value,
                            Humidity = humidity.Value
                        });

                    csvWriter.WriteRecords(combinedData);
                }
            }
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

    public void Dispose()
    {
        if (arduinoPort != null)
        {
            if (arduinoPort.IsOpen)
            {
                arduinoPort.Close();
            }
            arduinoPort.Dispose();
        }

        if (usbEventWatcher != null)
        {
            usbEventWatcher.Dispose();
        }
    }

    private void UpdateButtonAndLedStates(bool btn0Activated, bool btn1Activated, bool btn2Activated, bool led0Activated, bool led1Activated, bool led2Activated)
    {
        Dispatcher.UIThread.InvokeAsync(() =>
        {
            // Update button backgrounds
            btn0.Background = btn0Activated ? Brushes.Black : Brushes.White;
            btn1.Background = btn1Activated ? Brushes.Black : Brushes.White;
            btn2.Background = btn2Activated ? Brushes.Black : Brushes.White;

            // Update LED fills to a brighter yellow when activated, or a dimmer color when not
            led0.Fill = led0Activated ? Brushes.Yellow : Brushes.LightYellow;
            led1.Fill = led1Activated ? Brushes.Yellow : Brushes.LightYellow;
            led2.Fill = led2Activated ? Brushes.Yellow : Brushes.LightYellow;
        });
    }

    private void ResetData(object? sender, EventArgs e)
    {
        Dispatcher.UIThread.InvokeAsync(() =>
        {
            liveCurrent.Content = "N/A fA";
            averageCurrent.Content = "N/A fA";

            btn0.Background = Brushes.White;
            btn1.Background = Brushes.White;
            btn2.Background = Brushes.White;

            led0.Fill = Brushes.LightYellow;
            led1.Fill = Brushes.LightYellow;
            led2.Fill = Brushes.LightYellow;
        });
    }
}
