#include "scpiInterface.h"
#include "scpiInterfaceCommandTree.h"
#include "config.h"

static void Identify(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void Reset(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void SerialErrorHandler(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void GetLastEror(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void SCPIversion(SCPI_C commands, SCPI_P parameters, Stream& interface);

static void dacSetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void dacGetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface);

static void serialSetStream(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void serialGetStream(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void serialSetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void serialGetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface);

static void accurateSetCharge(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetCharge(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetCooldown(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetCooldown(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetReset(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetReset(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetTCharge(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetTCharge(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetTInjection(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetTInjection(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetDisableCP(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetDisableCP(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateSetSingly(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void accurateGetSingly(SCPI_C commands, SCPI_P parameters, Stream& interface);

static void printHelp(SCPI_C commands, SCPI_P parameters, Stream& interface);
static void DoNothing(SCPI_C commands, SCPI_P parameters, Stream& interface);

void init_scpiInterface() {
    /*
    To fix hash crashes, the hashing magic numbers can be changed before 
    registering commands.
    Use prime numbers up to the SCPI_HASH_TYPE size.
    */
    my_instrument.hash_magic_number = 37; //Default value = 37
    my_instrument.hash_magic_offset = 7;  //Default value = 7

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
        my_instrument.RegisterCommand(F(":VOLTage?"), &dacGetVoltage);
    my_instrument.SetCommandTreeBase(F("CONFigure:ACCUrate"));
        my_instrument.RegisterCommand(F(":CHARGE#"), &accurateSetCharge);
        my_instrument.RegisterCommand(F(":CHARGE?#"), &accurateGetCharge);
        my_instrument.RegisterCommand(F(":COOLdown#"), &accurateSetCooldown);
        my_instrument.RegisterCommand(F(":COOLdown?#"), &accurateGetCooldown);
        my_instrument.RegisterCommand(F(":RESET#"), &accurateSetReset);
        my_instrument.RegisterCommand(F(":RESET?"), &accurateGetReset);
        my_instrument.RegisterCommand(F(":TCHARGE#"), &accurateSetTCharge);
        my_instrument.RegisterCommand(F(":TCHARGE?"), &accurateGetTCharge);
        my_instrument.RegisterCommand(F(":TINJection#"), &accurateSetTInjection);
        my_instrument.RegisterCommand(F(":TINJection?"), &accurateGetTInjection);
        my_instrument.RegisterCommand(F(":DISABLE#"), &accurateSetDisableCP);
        my_instrument.RegisterCommand(F(":DISABLE?#"), &accurateGetDisableCP);
        my_instrument.RegisterCommand(F(":SINGLY#"), &accurateSetSingly);
        my_instrument.RegisterCommand(F(":SINGLY?"), &accurateGetSingly);
    my_instrument.SetCommandTreeBase(F("CONFigure:SERIal"));
        my_instrument.RegisterCommand(F(":STREAM#"), &serialSetStream);
        my_instrument.RegisterCommand(F(":STREAM?"), &serialGetStream);
        my_instrument.RegisterCommand(F(":RAW#"), &serialSetRaw);
        my_instrument.RegisterCommand(F(":RAW?"), &serialGetRaw);
    my_instrument.SetCommandTreeBase(F(""));
    my_instrument.RegisterCommand(F("*IDN?"), &Identify);
    my_instrument.RegisterCommand(F("*RST"), &Reset);
    my_instrument.RegisterCommand(F("HELP?"), &printHelp);


    // my_instrument.PrintDebugInfo(Serial);
    my_instrument.SetErrorHandler(&SerialErrorHandler);
}


// -------------------------------------------------------------------
// ---------------- Functions of implemented commands ----------------
// -------------------------------------------------------------------

static void Identify(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    String outMessage = "CERN, REV1, ";
    for (uint8_t i = 0; i < 4; i++) {
        outMessage += String(( *(conf.UUID+i) ), HEX);
    }
    outMessage += ", 1.4.0";
    interface.println(outMessage);
}

static void Reset(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("Resetting the device...");
    delay(1000);
    /*
    CMSIS (Cortex Microcontroller Software Interface Standard) function
    Set the SYSRESETREQ in the NVIC (Nested Vectored Interrupt Controller),
    causing the MCU to reset.
    */
    NVIC_SystemReset();
}

static void GetLastEror(SCPI_C commands, SCPI_P parameters, Stream& interface) {
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

static void SerialErrorHandler(SCPI_C commands, SCPI_P parameters, Stream& interface) {
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

static void SCPIversion(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("NOT SCPI COMPLIANT");
}

static void dacSetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 2) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = toupper(parameters.First()[0]) - 'A';
    float voltage = atof(parameters.Last());

    conf.dac[channel] = voltage;
}

static void dacGetVoltage(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = toupper(parameters.First()[0]) - 'A';
    interface.println(conf.dac[channel]);
}

static void serialSetStream(SCPI_C commands, SCPI_P parameters, Stream& interface) {
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

static void serialGetStream(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(conf.serial.stream);
}

static void serialSetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface) {
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

static void serialGetRaw(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(conf.serial.rawOutput);
}

static void printHelp(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println(scpiCommandTree);
}

static void accurateParameters(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("Command not implemented");
}

static void accurateSetCharge(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 2) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = atoi(parameters.First());
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    float charge = atoi(parameters.Last());
    conf.acc.chargeQuantaCP[channel - 1] = charge;
}

static void accurateGetCharge(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = atoi(parameters.First());
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    interface.println(conf.acc.chargeQuantaCP[channel - 1]);
}

static void accurateSetCooldown(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 3) {
        interface.println("Invalid number of parameters");
        return;
    }

    String type = String(parameters.First());
    type.toUpperCase();

    uint8_t channel = atoi(parameters[1]); // pick the second element
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    uint32_t time = atoi(parameters.Last());

    if (type == "MIN") {
        conf.acc.cooldownMinCP[channel - 1] = time;
    } else if (type == "MAX") {
        conf.acc.cooldownMaxCP[channel - 1] = time;
    } else {
        interface.println("Invalid type parameter");
    }
}

static void accurateGetCooldown(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 2) {
        interface.println("Invalid number of parameters");
        return;
    }

    String type = String(parameters.First());
    type.toUpperCase();

    uint8_t channel = atoi(parameters.Last());
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    if (type == "MIN") {
        interface.println(conf.acc.cooldownMinCP[channel - 1]);
    } else if (type == "MAX") {
        interface.println(conf.acc.cooldownMaxCP[channel - 1]);
    } else {
        interface.println("Invalid type parameter");
    }
}

static void accurateSetReset(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t reset = atoi(parameters.First());
    if (reset != 0 && reset != 1) {
        interface.println("Invalid parameter");
        return;
    }

    conf.acc.resetOTA = reset;
}

static void accurateGetReset(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 0) {
        interface.println("Invalid number of parameters");
        return;
    }

    interface.println(conf.acc.resetOTA);
}

static void accurateSetTCharge(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t time = atoi(parameters.First());
    if (time <= 0) {
        time = 1;
    }

    conf.acc.tCharge = time;
}

static void accurateGetTCharge(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 0) {
        interface.println("Invalid number of parameters");
        return;
    }

    interface.println(conf.acc.tCharge);
}

static void accurateSetTInjection(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t time = atoi(parameters.First());
    if (time <= 0) {
        time = 1;
    }

    conf.acc.tInjection = time;
}

static void accurateGetTInjection(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 0) {
        interface.println("Invalid number of parameters");
        return;
    }

    interface.println(conf.acc.tInjection);
}

static void accurateSetDisableCP(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 2) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = atoi(parameters.First());
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    uint8_t disable = atoi(parameters.Last());
    if (disable != 0 && disable != 1) {
        interface.println("Invalid parameter");
        return;
    }

    conf.acc.disableCP[channel - 1] = disable;
}

static void accurateGetDisableCP(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t channel = atoi(parameters.First());
    if (channel < 1 || channel > 3) {
        interface.println("Invalid channel number");
        return;
    }

    interface.println(conf.acc.disableCP[channel - 1]);
}

static void accurateSetSingly(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 1) {
        interface.println("Invalid number of parameters");
        return;
    }

    uint8_t activate = atoi(parameters.First());
    if (activate != 0 && activate != 1) {
        interface.println("Invalid parameter");
        return;
    }

    conf.acc.singlyCPActivation = activate;
}

static void accurateGetSingly(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    if (parameters.Size() != 0) {
        interface.println("Invalid number of parameters");
        return;
    }

    interface.println(conf.acc.singlyCPActivation);
}

static void DoNothing(SCPI_C commands, SCPI_P parameters, Stream& interface) {
    interface.println("Command not implemented");
}
