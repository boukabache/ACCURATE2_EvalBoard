# Script that receive from serial port the voltageChangeIntervalxDO value
# from the FPGA and calculate the correspective current.
# The communication format is the following:
# 1B of header (0xAB) + 5B of data (coming from LSB to MSB)
# Of the 40 bits of data, the first 39 are used. The rest is just zero padding.

import typer
import serial
import serial.tools.list_ports
from typing_extensions import Annotated

app = typer.Typer(
    help="Command line interface for the ACCURATE2 evaluation board.",
    epilog="",
    add_completion=False
)

default_period = 100 # ms
default_lsb = 39.339 # aC


@app.command()
def list_ports():
    '''
    List all the serial ports currently available.
    '''

    ports = serial.tools.list_ports.comports()
    for port in ports:
        print(port.device)


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
            "-p", "--period",
            help="Sampling period in ms."
        )
    ] = default_period,
    lsb: Annotated[
        float, typer.Option(
            "-l", "--lsb",
            help="Least significant bit value in aC."
        )
    ] = default_lsb,
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

    with serial.Serial(port, baudrate, timeout=1) as ser:
        try:
            while True:
                # Check header
                header = ser.read()
                if header != 0xAB:
                    continue

                # Read data
                ser_data = ser.read(5)
                # Extract data
                data = int.from_bytes(ser_data, byteorder='little')
                if verbose:
                    # Print ser_data and data
                    print(f"Serial data: {ser_data}", end='\r')
                    print(f"Integer representation: {data}", end='\r')

                # Calculate current
                charge = data * lsb
                current = charge / period

                # Print current
                print(f"Current: {current:.2f} A", end='\r')
        except KeyboardInterrupt:
            # Ctrl+C pressed, exit
            raise typer.Exit()
        

@app.command()
def hello():
    '''
    Print a welcome message.
    '''
    try:
        while True:
            print("Hello world!  Hello europapa!", end='\r')
    except KeyboardInterrupt:
        # Ctrl+C pressed, exit
        print("\nGoodbye!")
        raise typer.Exit()



if __name__ == "__main__":
    app()