# Script that receive from serial port the voltageChangeIntervalxDO value
# from the FPGA and calculate the correspective current.
# The communication format is the following:
# 1B of header (0xDD) + 6B of data (coming from LSB to MSB)
# Of the 48 bits of data, the first 39 are used. The rest is just zero padding.

import typer
import serial
import serial.tools.list_ports
from typing_extensions import Annotated
import datetime
from typing import Optional

# For formatted output
from rich.console import Console
from rich.live import Live
from rich.text import Text

# For plotting
import matplotlib.pyplot as plt

# For Keithley control
import pyvisa


app = typer.Typer(
    help="Command Line Interface for the ACCURATE2 evaluation board.",
    epilog="",
    add_completion=False
)

default_period = 100 # ms
default_lsb = 39.339 # aC
default_log_file = "output.log"
DAC_address = {'A': 0x00, 'B': 0x01, 'C': 0x02, 'D': 0x03, 'E': 0x04, 'F': 0x05, 'G': 0x06, 'H': 0x07}


@app.command()
def list_ports():
    '''
    List all the serial ports currently available.
    '''

    ports = serial.tools.list_ports.comports()
    for port in ports:
        print(port.device)


@app.command()
def open_serial(
    port: Annotated[
        str, typer.Argument(
            help="Serial port where the FPGA is connected.",
            envvar="SERIAL_PORT"
        )
    ],
    baudrate: Annotated[
        int, typer.Option(
            "-b", "--baudrate",
            help="Baudrate for the serial communication."
        )
    ] = 9600
):
    '''
    Open a serial connection with the FPGA. \n
    PORT accepts also the environment variable SERIAL_PORT.
    '''

    with serial.Serial(port, baudrate, timeout=1) as ser:
        print(f"Serial port {port} opened at {baudrate} baudrate.")
        while True:
            try:
                data = ser.read(1)
                print(data, end=' ', flush=True)
            except KeyboardInterrupt:
                print(f"\nSerial port {port} closed.")
                raise typer.Exit()


@app.command()
def get_current(
    port: Annotated[
        str, typer.Argument(
            help="Serial port where the FPGA is connected.",
            envvar="SERIAL_PORT"
        )
    ],
    baudrate: Annotated[
        int, typer.Option(
            "-b", "--baudrate",
            help="Baudrate for the serial communication."
        )
    ] = 9600,
    period: Annotated[
        int, typer.Option(
            "--period",
            help="Sampling period in ms."
        )
    ] = default_period,
    lsb: Annotated[
        float, typer.Option(
            "--lsb",
            help="Least significant bit value in aC."
        )
    ] = default_lsb,
    log: Annotated[
        Optional[str], typer.Option(
            "-l", "--log",
            help="Log the values to specified file.",
            show_default=False
        )
    ] = None,
    verbose: Annotated[
        bool, typer.Option(
            "-v", "--verbose",
            help="Enable verbose output."
        )
    ] = False,
    plot: Annotated[
        bool, typer.Option(
            "-p", "--plot",
            help="Enable real time plotting."
        )
    ] = False
):
    '''
    Get the measured current from ACCURATE. \n
    To exit, press Ctrl+C. \n
    PORT accepts also the environment variable SERIAL_PORT.
    '''

    # Initialize variables
    femto_current_avg = 0
    femto_current = 0
    count = 0
    timestamps = []
    instantaneous_currents = []
    average_currents = []
    previous_current = 0
    # Initialize the console
    console = Console()
    # Initialize and write header to file
    if log is not None:
        with open(log, "w") as f:
            f.write("Timestamp, Instantaneous current (fA), Average current (fA)")
            if verbose:
                f.write(", Serial data, Integer representation")
            f.write("\nStart time: " + datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\n")
            f.write("-----------------------------")

    with serial.Serial(port, baudrate, timeout=1) as ser:
        try:
            with Live(console=console, refresh_per_second=4) as live:
                while True:
                    # Check header
                    header = ser.read()
                    if header[0] != 0xDD:
                        continue

                    # Read data
                    ser_data = ser.read(6)
                    # Extract data
                    data = int.from_bytes(ser_data, byteorder='little')

                    # Save the previous current measurement
                    previous_current =  femto_current

                    # Instantaneous current
                    charge = data * lsb
                    atto_current = charge / (period * 1e-3)
                    femto_current = atto_current * 1e-3
                    # Average currents
                    # If a difference of at least a decate in the current is detected,
                    # reset the average current as it is likely a new measurement.
                    # TODO: implement this logic
                    
                    femto_current_avg += femto_current
                    count += 1
                    # Format current
                    scale_factor, unit = format_current(femto_current)

                    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")

                    # Log to file in CSV format
                    if log is not None:
                        with open(log, "a") as f:
                            f.write(f"\n{timestamp}, {femto_current:.2f}, {femto_current_avg/count:.2f}")
                            if verbose:
                                f.write(f", 0x{ser_data.hex()}, {data}")

                    # Create a text object with the current values
                    text = Text()
                    text.append("Live data:", style="bold")
                    text.append(f"\nInstantaneous current: {femto_current*scale_factor:.2f} {unit}")
                    text.append(f" - Average current: {(femto_current_avg*scale_factor/count):.2f} {unit} ({count})")
                    if verbose:
                        text.append(f"\nDebug Data:", style="bold dim")
                        text.append(f"\nSerial data: 0x{ser_data.hex()} - ", style="dim")
                        text.append(f"Integer representation: {data}", style="dim")
                    # Update the live display with the new text
                    live.update(text)


                    # Plot the current values
                    if plot:
                        # Append current values to the lists
                        timestamps.append(timestamp)
                        instantaneous_currents.append(femto_current)
                        average_currents.append(femto_current_avg)

                        # plt.ion()  # Turn on interactive mode
                        plt.plot(timestamps, instantaneous_currents*scale_factor, 'o', markersize=2, color='red', label='Instantaneous current')
                        plt.plot(timestamps, average_currents*scale_factor/count, 'o', markersize=2, color='blue', label='Average current')
                        # plt.xticks([]) # Do not print x-axis values
                        plt.xlabel('Time [s]')
                        plt.ylabel(f'Current [{unit}]')
                        plt.legend()
                        # plt.draw()
                        plt.pause(0.001)
                        # plt.clf()  # Clear the current figure

        except KeyboardInterrupt:
            # Ctrl+C pressed, exit
            raise typer.Exit()
        

@app.command()
def set_dac(
    port: Annotated[
        str, typer.Argument(
            help="Serial port where the FPGA is connected.",
            envvar="SERIAL_PORT"
        )
    ],
    channel: Annotated[
        str, typer.Argument(
            help="DAC channel to set [A-H]."
        )
    ],
    voltage: Annotated[
        float, typer.Argument(
            help="Voltage to set in volts."
        )
    ],
    baudrate: Annotated[
        int, typer.Option(
            "-b", "--baudrate",
            help="Baudrate for the serial communication."
        )
    ] = 9600,
):
    '''
    Set the DAC's channel voltages.
    '''
    # Convert voltage to DAC Din value
    Din = (voltage * 4096) // 3 # Vref = 3V, 12-bit DAC
    Din_binary = bin(int(Din))[2:].zfill(32)

    # Send data to FPGA
    with serial.Serial(port, baudrate, timeout=1) as ser:
        # Send address
        ser.write(DAC_address[channel].to_bytes())
        # Send data
        ser.write(Din_binary)
    
    print(f"Channel {channel} set to {voltage}V - ({Din_binary})")
    raise typer.Exit()


@app.command()
def set_keithley(
    address: Annotated[
        str, typer.Argument(
            help="Keithley address."
        )
    ],
    current : Annotated[
        float, typer.Argument(
            help="Current to set in uA."
        )
    ],
    verbose: Annotated[
        bool, typer.Option(
            "-v", "--verbose",
            help="Enable verbose output."
        )
    ] = False,
):
    '''
    Set the Keithley's current.
    '''
    # Connect to the Keithley
    rm = pyvisa.ResourceManager()
    keithley = rm.open_resource(address)
    # Set the current
    keithley.write(":SOUR:FUNC CURR")  # Set to current source mode
    keithley.write(f":SOUR:CURR {current}")  # Set current to
    keithley.write(":OUTP ON") # Turn on the output
    # Read the current
    read = keithley.query("READ?")
    # Close the connection
    keithley.close()
    rm.close()




###################
# UTILITY FUNCTIONS
###################

def format_current(femto_current):
    """
    Formats the given femto current, by picking a more appropriate unit.

    Args:
        femto_current (float): The femto current to be formatted.

    Returns:
        scale_factor (float): The scale factor to be applied to the current.
        unit (str): The unit of the current.
    """
    
    if femto_current < 1e3:
        return 1, "fA"
    elif femto_current < 1e6:
        return 1e-3, "pA"
    elif femto_current < 1e9:
        return 1e-6, "nA"
    else:
        return 1e-9, "uA"
    


if __name__ == "__main__":
    app()