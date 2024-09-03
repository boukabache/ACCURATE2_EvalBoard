/**
 * @file serialComPC.h
 * @brief Header file for the serial communication functions between MCU and PC.
 * 
 * Hanldes the serial communication between the MCU and the PC. It reads the serial input,
 * that is expected to follow a certain structure, and parses it to the correct variable.
 * 
 * Structure of the input: COMMAND+ADDRESS+VALUE
 * Example for setting the INIT_CONFIG (address 0x04) to 0x01: SET0401
*/

#ifndef SERIALCOMPC_H
#define SERIALCOMPC_H

#include <Arduino.h>


/**
 * @brief Manage the serial communication with the PC.
 * 
 * @warning It is not implemented yet. There is just the structure and a showcase
 * of how it could be implemented via serial prints.
 * 
 * This function reads the serial input from the PC and parses it to the correct
 * variable. A reply is sent back to the PC.
 */
void serialReadFromPC();



#endif // SERIALCOMPC_H