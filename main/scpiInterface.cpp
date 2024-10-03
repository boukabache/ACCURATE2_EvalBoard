#include "scpiInterface.h"
#include "scpiInterfaceCommandTree.h"
#include "config.h"

void Identify(SCPI_C commands, SCPI_P parameters, Stream& interface);
void Reset(SCPI_C commands, SCPI_P parameters, Stream& interface);
void SerialErrorHandler(SCPI_C commands, SCPI_P parameters, Stream& interface);
void GetLastEror(SCPI_C commands, SCPI_P parameters, Stream& interface);
void SCPIversion(SCPI_C commands, SCPI_P parameters, Stream& interface);

void dacSetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface);
void dacGetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface);

void serialSetStream(SCPI_C commands, SCPI_P parameters, Stream& interface);
void serialGetStream(SCPI_C commands, SCPI_P parameters, Stream& interface);
void serialSetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface);
void serialGetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface);


void printHelp(SCPI_C commands, SCPI_P parameters, Stream& interface);
void DoNothing(SCPI_C commands, SCPI_P parameters, Stream& interface);

void init_scpiInterface() {
    /*
    To fix hash crashes, the hashing magic numbers can be changed before 
    registering commands.
    Use prime numbers up to the SCPI_HASH_TYPE size.
    */
    my_instrument.hash_magic_number = 37; //Default value = 37
    my_instrument.hash_magic_offset = 7;  //Default value = 7

    /*
    Timeout time can be changed even during program execution
    */
    my_instrument.timeout = 10; //value in miliseconds. Default value = 10


    my_instrument.SetCommandTreeBase(F("STATus:OPERation"));
        my_instrument.RegisterCommand(F(":CONDition?"), &DoNothing);
        my_instrument.RegisterCommand(F(":ENABle"), &DoNothing);
        my_instrument.RegisterCommand(F(":EVENt?"), &DoNothing);
    my_instrument.SetCommandTreeBase(F("STATus:QUEStionable"));
        my_instrument.RegisterCommand(F(":CONDition?"), &DoNothing);
        my_instrument.RegisterCommand(F(":ENABle"), &DoNothing);
        my_instrument.RegisterCommand(F(":EVENt?"), &DoNothing);
    my_instrument.SetCommandTreeBase(F("STATus"));
        my_instrument.RegisterCommand(F(":OPERation?"), &DoNothing);
        my_instrument.RegisterCommand(F(":QUEStionable?"), &DoNothing);
        my_instrument.RegisterCommand(F(":PRESet"), &DoNothing);
    my_instrument.SetCommandTreeBase(F(""));
    my_instrument.RegisterCommand(F("*CLS"), &DoNothing);
    my_instrument.RegisterCommand(F("*ESE"), &DoNothing);
    my_instrument.RegisterCommand(F("*ESE?"), &DoNothing);
    my_instrument.RegisterCommand(F("*ESR"), &DoNothing);
    my_instrument.RegisterCommand(F("*OPC"), &DoNothing);
    my_instrument.RegisterCommand(F("*OPC?"), &DoNothing);
    my_instrument.RegisterCommand(F("*SRE"), &DoNothing);
    my_instrument.RegisterCommand(F("*SRE?"), &DoNothing);
    my_instrument.RegisterCommand(F("*STB"), &DoNothing);
    my_instrument.RegisterCommand(F("*TST?"), &DoNothing);
    my_instrument.RegisterCommand(F("*WAI"), &DoNothing);
    
    // ---------------- Implemented commands ----------------
    my_instrument.SetCommandTreeBase(F("SYSTem"));
        my_instrument.RegisterCommand(F(":ERRor?"), &GetLastEror);
        my_instrument.RegisterCommand(F(":ERRor:NEXT?"), &GetLastEror);
        my_instrument.RegisterCommand(F(":VERSion?"), &SCPIversion);
    my_instrument.SetCommandTreeBase(F("CONFigure:DAC"));
        my_instrument.RegisterCommand(F(":VOLTage#"), &dacSetVoltage);
        my_instrument.RegisterCommand(F(":VOLTage?"), &DoNothing);
    my_instrument.SetCommandTreeBase(F("CONFigure:SERIal"));
        my_instrument.RegisterCommand(F(":STREAM#"), &DoNothing);
        my_instrument.RegisterCommand(F(":STREAM?"), &DoNothing);
        my_instrument.RegisterCommand(F(":RAW#"), &DoNothing);
        my_instrument.RegisterCommand(F(":RAW?"), &DoNothing);
    my_instrument.SetCommandTreeBase(F(""));
    my_instrument.RegisterCommand(F("*IDN?"), &Identify);
    my_instrument.RegisterCommand(F("*RST"), &Reset);
    my_instrument.RegisterCommand(F("HELP?"), &printHelp);


    my_instrument.PrintDebugInfo(Serial);
    my_instrument.SetErrorHandler(&SerialErrorHandler);
}


// -------------------------------------------------------------------
// ---------------- Functions of implemented commands ----------------
// -------------------------------------------------------------------

void Identify(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    String outMessage = "CERN, REV1, ";
    for (uint8_t i = 0; i < 4; i++) {
        outMessage += String(( *(conf.UUID+i) ), HEX);
    }
    outMessage += ", 1.4.0";
    interface.println(outMessage);
}

void Reset(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("Resetting the device...");
    delay(1000);
    /*
    CMSIS (Cortex Microcontroller Software Interface Standard) function
    Set the SYSRESETREQ in the NVIC (Nested Vectored Interrupt Controller),
    causing the MCU to reset.
    */
    NVIC_SystemReset();
}

void GetLastEror(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    switch(my_instrument.last_error){
        case my_instrument.ErrorCode::BufferOverflow: 
        interface.println(F("-100, Buffer overflow error"));
        break;
        case my_instrument.ErrorCode::Timeout:
        interface.println(F("-100, Communication timeout error"));
        break;
        case my_instrument.ErrorCode::UnknownCommand:
        interface.println(F("-102, Unknown command received"));
        break;
        case my_instrument.ErrorCode::NoError:
        interface.println(F("0, No Error"));
        break;
    }
    my_instrument.last_error = my_instrument.ErrorCode::NoError;
}

void SerialErrorHandler(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    // This function is called every time an error occurs

    /* For BufferOverflow errors, the rest of the message, still in the interface
    buffer or not yet received, will be processed later and probably 
    trigger another kind of error.
    Here we flush the incoming message*/
    if (my_instrument.last_error == SCPI_Parser::ErrorCode::BufferOverflow) {
        delay(2);
        while (interface.available()) {
        delay(2);
        interface.read();
        }
    }
}

void SCPIversion(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("NOT SCPI COMPLIANT");
}

void dacSetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 2) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = toupper(parameters.First()[0]) - 'A';
    float voltage = atof(parameters.Last());

    conf.dac[channel] = voltage;
}

void dacGetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = toupper(parameters.First()[0]) - 'A';
    interface.println(conf.dac[channel]);
}

void serialSetStream(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    String first_parameter = String(parameters.First());
    first_parameter.toUpperCase();

    if (first_parameter == "ON") {
        conf.serial.stream = true;
    } else if (first_parameter == "OFF") {
        conf.serial.stream = false;
    } else {
        interface.println("Invalid parameter");
    }
}

void serialGetStream(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(conf.serial.stream);
}

void serialSetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    String first_parameter = String(parameters.First());
    first_parameter.toUpperCase();

    if (first_parameter == "ON") {
        conf.serial.rawOutput = true;
    } else if (first_parameter == "OFF") {
        conf.serial.rawOutput = false;
    } else {
        interface.println("Invalid parameter");
    }
}

void serialGetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(conf.serial.rawOutput);
}

void printHelp(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(scpiCommandTree);
}

void DoNothing(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("Command not implemented");
}