using LiveChartsCore.SkiaSharpView;
using LiveChartsCore;
using System;
using LiveChartsCore.SkiaSharpView.Painting;
using System.Collections.Generic;

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

    public ISeries[] CurrentSeries { get; set; }
    = new ISeries[]
    {
                new LineSeries<double>
                {
                     Values = new double[] { 1e-6, 1e-9, 1e-12, 1e-15, 1e-18},
                     GeometrySize = 0,
                     GeometryStroke = null,
                     Stroke = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) {StrokeThickness = 3},
                     Fill = null,
                     LineSmoothness = 0,
                }
    };

    public ISeries[] TemperatureAndHumiditySeries { get; set; }
        = new ISeries[]
        {
            new LineSeries<double>
            {
                Values = new double[] { 20, 22, 24, 22, 26},
                GeometrySize = 0,
                GeometryStroke = null,
                Stroke = new SolidColorPaint(new SkiaSharp.SKColor(0, 51, 160)) {StrokeThickness = 3},
                Fill = null,
                LineSmoothness = 0,
                ScalesYAt = 0,
            },
            new LineSeries<double>
            {
                Values = new double[] { 0, 25, 50, 75, 100 },
                GeometrySize = 0,
                GeometryStroke = null,
                Fill = null,
                LineSmoothness = 0,
                ScalesYAt = 1,
            }
};

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
}




