/**
 * @file scpiInterface.h
 * @brief SCPI interface for the project
 * @author Mattia Consani
 * 
 * This file contains the SCPI parser library implementation for the project.
 * Here the command tree is defined.
 * The SCPI parser object is initialized in the main file.
*/

/*
The SCPI library supports the following macros to optimize RAM usage:
- SCPI_ARRAY_SYZE : Max branches of the command tree and max number of parameters.
- SCPI_MAX_TOKENS : Max number of valid tokens.
- SCPI_MAX_COMMANDS : Max number of registered commands.
- SCPI_MAX_SPECIAL_COMMANDS : Max number of special commands.
- SCPI_BUFFER_LENGTH : Length of the message buffer.
- SCPI_HASH_TYPE : Integer size used for hashes.
*/
#define SCPI_ARRAY_SYZE 4 //Default value = 6
#define SCPI_MAX_TOKENS 24 //Default value = 15
#define SCPI_MAX_COMMANDS 29 //Default value = 20
#define SCPI_MAX_SPECIAL_COMMANDS 0 //Default value = 0
#define SCPI_BUFFER_LENGTH 128 //Default value = 64
#define SCPI_HASH_TYPE uint8_t //Default value = uint8_t

#ifndef SCPIINTERFACE_H
#define SCPIINTERFACE_H


#include <Arduino.h>
#include "Vrekrer_scpi_parser.h"

/*
Command tree with only SCPI Required Commands and IEEE Mandated Commands:
STATus
    :OPERation
        :CONDition?
        :ENABle
        [:EVENt]?
    :QUEStionable
        :CONDition?
        :ENABle
        [:EVENt]?
    :PRESet
SYSTem
    :ERRor
        [:NEXT]?
    :VERSion?
*CLS
*ESE
*ESE?
*ESR?
*IDN?
*OPC
*OPC?
*RST
*SRE
*SRE?
*STB
*TST?
*WAI

Custom commands to operate the Evaluation Board:
CONFigure
    :DAC
        :VOLTage A|B|C|D|E|F|G|H ,<voltage>
        :VOLTage? A|B|C|D|E|F|G|H
    :ACCUrate
        :CHARGE
        :CHARGE?
        :COOLdown
        :COOLdown?
        :RESET
        :RESET?
        :TCHARGE
        :TCHARGE?
        :TINJection
        :TINJection?
        :DISABLE
        :DISABLE?
        :SINGLY
        :SINGLY?
    :SERIal
        :STREAM ON|OFF
        :STREAM?
        :RAW ON|OFF
        :RAW?
*/

/*
Largest branch needed = 3
i.e. STATus:OPERation:ENABle or SYSTem:ERRor:NEXT?
*/
//This also sets the max number of parameters

/*
Valid Tokens: 
01: STATus
02: OPERation
03: CONDition
04: ENABle
05: EVENt
06: QUEStionable
07: PRESet
08: SYSTem
09: ERRor
10: NEXt
11: VERSion
12: *CLS
13: *ESE
14: *ESR
15: *IDN
16: *OPC
17: *RST
18: *SRE
19: *STB
20: *TST
21: *WAI
Total number of valid tokens: 21
*/

/*
Valid Commands:
01: STATus:OPERation:CONDition?
02: STATus:OPERation:ENABle
03: STATus:OPERation?
04: STATus:OPERation:EVENt?
05: STATus:QUEStionable:CONDition?
06: STATus:QUEStionable:ENABle
07: STATus:QUEStionable?
08: STATus:QUEStionable:EVENt?
09: STATus:PRESet
10: SYSTem:ERRor?
11: SYSTem:ERRor:NEXT?
12: SYSTem:VERSion?
13: *CLS
14: *ESE
15: *ESE?
16: *ESR?
17: *IDN?
18: *OPC
19: *OPC?
20: *RST
21: *SRE
22: *SRE?
23: *STB
24: *TST?
25: *WAI
Total number of valid commands: 25
*/

/*
No special commands used
*/

/*
The message buffer should be large enough to fit all the incoming message
For example, the multicommand message
"*RST; *cls; status:operation:enable; status:questionable:enable;\n"
will need at least 67 byte buffer length.
*/

/*
If needed, to avoid hash crashes (two commands have the same hash),
change SCPI_HASH_TYPE to uint16_t or uint32_t.
*/


extern SCPI_Parser my_instrument;

void init_scpiInterface();


#endif // SCPIINTERFACE_H