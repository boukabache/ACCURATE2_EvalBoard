# Script that receive from serial port the voltageChangeIntervalxDO value
# from the FPGA and calculate the correspective current.
# The communication format is the following:
# 1B of header (0xAB) + 5B of data (coming from LSB to MSB)
# Of the 40 bits of data, the first 39 are used. The rest is just zero padding.

import typer
import serial
import serial.tools.list_ports
from typing_extensions import Annotated
import datetime

app = typer.Typer(
    help="Command line interface for the ACCURATE2 evaluation board.",
    epilog="",
    add_completion=False
)

default_period = 100 # ms
default_lsb = 39.339 # aC
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
    average: Annotated[
        bool, typer.Option(
            "-a", "--average",
            help="Print average current instead of instantaneous."
        )
    ] = False,
    log: Annotated[
        bool, typer.Option(
            "-l", "--log",
            help="Log the values to file. If average is enabled, it will log both instant and average current."
        )
    ] = False,
    verbose: Annotated[
        bool, typer.Option(
            "-v", "--verbose",
            help="Enable verbose output."
        )
    ] = False
):
    '''
    Get the measured current from ACCURATE. \n
    To exit, press Ctrl+C. \n
    PORT accepts also the environment variable SERIAL_PORT.
    '''
    if average:
        pico_current_avg = 0
        count = 0

    if log:
        with open("valuess.log", "w") as f:
            if average:
                f.write("Timestamp, Instantaneous current (pA), Average current (pA)\n")
            else:
                f.write("Timestamp, Instantaneous current (pA)\n")
            f.write("Start time: " + datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\n")
            f.write("-----------------------------\n")

    with serial.Serial(port, baudrate, timeout=1) as ser:
        try:
            while True:
                # Check header
                header = ser.read()
                if header[0] != 0xAB:
                    continue

                # Read data
                ser_data = ser.read(6)
                # Extract data
                data = int.from_bytes(ser_data, byteorder='little')
                if verbose:
                    # Print ser_data and data
                    print(f"Serial data: 0x{ser_data.hex()}", end=' ')
                    print(f"Integer representation: {data}", end=' - ')

                # Instantaneous current
                charge = data * lsb
                atto_current = charge / (period * 1e-3)
                pico_current = atto_current * 1e-6

                # Average current
                if average:
                    pico_current_avg += pico_current
                    count += 1

                # Log to file instant and average current in CSV format
                if log:
                    with open("values.log", "a") as f:
                        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        if average:
                            f.write(f"{timestamp}, {pico_current:.2f}, {pico_current_avg/count:.2f}\n")
                        else:
                            f.write(f"{timestamp}, {pico_current:.2f}\n")


                # Print current
                if average:
                    print(f"Average current: {(pico_current_avg/count):.2f} pA", end='\r', flush=True)
                else:
                    print(f"Instantaneous current: {pico_current:.2f} pA", end='\r', flush=True)
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


if __name__ == "__main__":
    app()