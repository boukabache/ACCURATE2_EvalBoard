# Accurate2 Eval GUI Avalonia

## Description
Accurate2 Eval GUI is an Avalonia-based application designed for real-time monitoring and analysis of sensor data from the ACCURATE 2A Evaluation Board. It provides a user-friendly interface for connecting to USB devices, visualizing current, temperature, and humidity data, and exporting this data for further analysis.
The application is based on Avalonia UI together with .NET 8.0 to allow for cross platform compatibility.
The charting is done using LiveCharts2.
The project is made using Visual Studio 2022.

## Features
- **Real-time Data Visualization**: Live charts display current, temperature, and humidity readings.
- **USB Device Integration**: Connect and disconnect to USB devices with ease.
- **Data Export**: Export sensor data to CSV files for external use.

## App Installation
1. Go to [releases](https://gitlab.cern.ch/AIGROUP-crome-support/accurate2_eval_gui_avalonia/-/releases) and download the executable for your machine.

### Windows
2. Run the .exe file

### Mac
2. Unzip the file.
3. Open a terminal in the same folder as the .app file and run
```
xattr -cr "ACCURATE 2A Evaluation Software.app"
 ```

 4. Open the file.

 ### Linux
 2. Open a terminal in the same folder as the file and run

```
rpm -i "ACCURATE 2A Evaluation Software.rpm"
 ```

## Project Installation
To install the Accurate2 Eval GUI, clone this repository and open it with Visual Studio 2022 or above. Make sure to install all necessary NuGet packages.

## Usage
1. **Connect a USB Device**: Select a port and click the "Connect" button to start receiving data from your USB device.
2. **View Real-Time Data**: Observe the live updates on the charts for current, temperature, and humidity.
3. **Export Data**: Click the "Export CSV" button to save the data in a CSV format.

## Publishing
### Windows x64
1. Right-click accurate2_eval_gui_avalonia.Desktop in Visual Studio 2022 and press "Publish"
2. Select a target location
3. Set the Configuration to Release
4. Set Target Framework to net8.0
5. Set Target Runtime to win-x64
6. Select Deployment mode to Self-contained
7. Press "Publish"

### Mac Arm64
1. In the accurate2_eval_gui_avalonia.Desktop folder, run
```
dotnet restore -r osx-arm64

dotnet msbuild -t:BundleApp -p:RuntimeIdentifier=osx-arm64 -property:Configuration=Release-p:CFBundleShortVersionString=1.1.2 -p:SelfContained=true -p:CFBundleIconFile="../../../../CERN-logo.icns"
 ```
This will create a .app file in bin>Release>net8.0>osx-arm64>publish.

To publish properly (which has not yet been done):
2. Sign the Mac app using a valid Apple Developer ID certificate on a Mac. This requires a subscription for being an Apple Developer. This must be done on a Mac. Sign it by running

```
codesign --force --timestamp --options=runtime --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP_NAME"
 ```

3. Make a Dmg by going into Disk Image, pressing "File>New Diskfile" and choose the app.
4. Sign the Mac Dmg file as with the .app.
5. Notarize the Dmg by following the guide [here](https://docs.avaloniaui.net/docs/deployment/macOS#notarizing-your-software).

### Linux x64 Rpm
In the accurate2_eval_gui_avalonia.Desktop folder, run

```
dotnet restore -r linux-x64

dotnet msbuild -t:CreateRpm -p:RuntimeIdentifier=linux-x64 -property:Configuration=Release -p:CFBundleShortVersionString=1.X.X -p:UseAppHost=true -p:CFBundleIconFile="../../../../CERN-logo.png"
```

This will create a .rpm file in bin>Release>net8.0>linux-x64.

## Contributing
Contributions to the Accurate2 Eval GUI are welcome. Please fork the repository and submit a pull request with your changes.

## License
This project is licensed under the [GNU General Public License v3.0](LICENSE.md).

## Contact
For any queries or contributions, please contact [haakon.liverud@cern.ch](mailto:haakon.liverud@cern.ch).
