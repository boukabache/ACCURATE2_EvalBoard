/**
 * @file scpiInterface.h
 * @brief SCPI interface for the project
 * @author Mattia Consani
 * 
 * This file contains the SCPI parser library implementation for the project.
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
#define SCPI_MAX_TOKENS 50 //Default value = 15
#define SCPI_MAX_COMMANDS 50 //Default value = 20
#define SCPI_MAX_SPECIAL_COMMANDS 0 //Default value = 0
#define SCPI_BUFFER_LENGTH 128 //Default value = 64
#define SCPI_HASH_TYPE uint16_t //Default value = uint8_t

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
        :LOG ON|OFF
        :LOG?
*/


/**
 * @brief Error buffer size
 */
#define ERROR_BUFFER_SIZE 15

/**
 * @brief The SCPI parser object
 * 
 * The SCPI_Parser object is defined in the main file.
 */
extern SCPI_Parser my_instrument;

/**
 * @brief Initialize the SCPI interface
 * 
 * Set the parser command tree and other settings. The SCPI_Parser object is
 * defined in the main file.
 */
void init_scpiInterface();


#endif // SCPIINTERFACE_H