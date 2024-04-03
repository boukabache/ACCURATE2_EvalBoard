using LiveChartsCore.SkiaSharpView;
using LiveChartsCore;
using System;
using LiveChartsCore.SkiaSharpView.Painting;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using LiveChartsCore.Defaults;
using Avalonia.Threading;

namespace accurate2_eval_gui_avalonia.ViewModels;

public partial class MainViewModel : ViewModelBase
{

    // Events to enable communication with the View for specific button actions.
    public event EventHandler ?OnConnectButtonClicked;
    public event EventHandler ?OnExportButtonClicked;
    // Collections to dynamically store and update measurement data.
    public ObservableCollection<ObservableValue> CurrentValues = new ObservableCollection<ObservableValue>();
    public ObservableCollection<ObservableValue> TemperatureValues = new ObservableCollection<ObservableValue>();
    public ObservableCollection<ObservableValue> HumidityValues = new ObservableCollection<ObservableValue>();

    public MainViewModel()
    {
        Initialize();
    }

    // Initializes chart series with specific visual configurations.
    private void Initialize()
    {
        // Setup for Current Series - defining visual aspects like color, thickness, etc.
        CurrentSeries = new ISeries[]
        {
            new LineSeries<ObservableValue>
            {
                Values = CurrentValues,
                GeometrySize = 0,
                GeometryStroke = null,
                Stroke = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) { StrokeThickness = 3 },
                Fill = null,
                LineSmoothness = 0,
            }
        };

        // Setup for Temperature and Humidity Series - similar setup, but for two different data sets.
        TemperatureAndHumiditySeries = new ISeries[]
        {
            new LineSeries<ObservableValue>
            {
                Values = TemperatureValues,
                GeometrySize = 0,
                GeometryStroke = null,
                Stroke = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) {StrokeThickness = 3},
                Fill = null,
                LineSmoothness = 0,
                ScalesYAt = 0,
            },
            new LineSeries<ObservableValue>
            {
                Values = HumidityValues,
                GeometrySize = 0,
                GeometryStroke = null,
                Fill = null,
                LineSmoothness = 0,
                ScalesYAt = 1,
            }
        };
    }

    // Resetting chart axes to default values, useful for recalibrating the view.
    public void OnConnectClickCommand()
    {
        // Trigger the event so that OnConnectButtonClicked in MainWindow.axaml.cs is called
        OnConnectButtonClicked?.Invoke(this, EventArgs.Empty);
    }

    public void OnExportClickCommand()
    {
        OnExportButtonClicked?.Invoke(this, EventArgs.Empty);
    }

    public void OnResetViewClickCommand()
    {
        // Reset Current Chart X and Y Axes
        foreach (var axis in CurrentXAxis)
        {
            axis.MinLimit = null;
            axis.MaxLimit = null;
        }

        foreach (var axis in CurrentYAxis)
        {
            axis.MinLimit = null;
            axis.MaxLimit = null;
        }

        // Reset Temperature and Humidity Chart X and Y Axes
        foreach (var axis in TemperatureAndHumidityXAxis)
        {
            axis.MinLimit = null;
            axis.MaxLimit = null;
        }

        foreach (var axis in TemperatureAndHumidityYAxis)
        {
            axis.MinLimit = null;
            axis.MaxLimit = null;
        }

        // Notify the view to update the axes
        OnPropertyChanged(nameof(CurrentXAxis));
        OnPropertyChanged(nameof(CurrentYAxis));
        OnPropertyChanged(nameof(TemperatureAndHumidityXAxis));
        OnPropertyChanged(nameof(TemperatureAndHumidityYAxis));
    }

    public void OnResetDataClickCommand()
    {
        CurrentValues.Clear();
        TemperatureValues.Clear();
        HumidityValues.Clear();

        OnResetViewClickCommand();
    }

    public ISeries[]? CurrentSeries { get; set; }

    public ISeries[]? TemperatureAndHumiditySeries { get; set; }

    private static string FormatLabel(double val)
    {
        if (val >= 1e-3)
        {
            return val.ToString("N2") + "mA";
        }
        else if (val >= 1e-6)
        {
            return (val * 1e6).ToString("N2") + "µA";
        }
        else if (val >= 1e-9)
        {
            return (val * 1e9).ToString("N2") + "nA";
        }
        else if (val >= 1e-12)
        {
            return (val * 1e12).ToString("N2") + "pA";
        }
        else if (val >= 1e-15)
        {
            return (val * 1e15).ToString("N2") + "fA";
        }
        else
        {
            return (val * 1e18).ToString("N2") + "aA";
        }
    }

    public List<Axis> CurrentXAxis { get; set; } =
    new List<Axis>
    {
            new Axis
            {
                CrosshairPaint = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) { StrokeThickness = 1 },
            }
    };

    public List<Axis> TemperatureAndHumidityXAxis { get; set; } =
    new List<Axis>
    {
            new Axis
            {
                CrosshairPaint = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) { StrokeThickness = 1 },
            }
    };

    public List<Axis> CurrentYAxis { get; set; } =
        new List<Axis>
        {
            new Axis
            {
                MinLimit = 1e-18,
                Labeler = (val) => FormatLabel(val),
            }
        };

    public List<Axis> TemperatureAndHumidityYAxis { get; set; } =
    new List<Axis>
    {
            new Axis
            {
                MinStep = 0.1,
                Labeler = (val) => val.ToString() + "°C",
            },
            new Axis
            {
                MinLimit = 0,
                MinStep = 1,
                Labeler = (val) => val.ToString() + "%",
            }
    };

    // Method to update graphs with new measurements, ensuring thread safety with UI thread.
    public void UpdateGraphs(double current, double temperature, double humidity)
    {
        Dispatcher.UIThread.Invoke(() =>
        {
            CurrentValues.Add(new(current));
            TemperatureValues.Add(new(temperature));
            HumidityValues.Add(new(humidity));
        });
    }
}
