/**
 * @file serialComPC.h
 * @brief Header file for the serial communication functions between MCU and PC.
 * 
 * Hanldes the serial communication between the MCU and the PC. It reads the serial input,
 * that is expected to follow a certain structure, and parses it to the correct variable.
 * 
 * Structure of the input: COMMAND[3B] + ADDRESS[2B] + VALUE[2B to 10B]
 * Example for setting the INIT_CONFIG (address 0x04) to 0x01: SET04435.321\n
 * 
 * The address map is as follows:
 * 0x00 - 0x07: DAC configuration voltages
 * |-> 0x00: vOutA
 * |-> 0x01: vOutB
 * |-> 0x02: vOutC
 * |-> 0x03: vOutD
 * |-> 0x04: vOutE
 * |-> 0x05: vOutF
 * |-> 0x06: vOutG
 * |-> 0x07: vOutH
 * 0x08 - 0x17: ACCURATE configuration
 * |-> 0x08: chargeQuantaCP1
 * |-> 0x09: chargeQuantaCP2
 * |-> 0x0A: chargeQuantaCP3
 * |-> 0x0B: cooldownMinCP1
 * |-> 0x0C: cooldownMaxCP1
 * |-> 0x0D: cooldownMinCP2
 * |-> 0x0E: cooldownMaxCP2
 * |-> 0x0F: cooldownMinCP3
 * |-> 0x10: cooldownMaxCP3
 * |-> 0x11: resetOTA
 * |-> 0x12: tCharge
 * |-> 0x13: tInjection
 * |-> 0x14: disableCP1
 * |-> 0x15: disableCP2
 * |-> 0x16: disableCP3
 * |-> 0x17: singlyCPActivation
 * 0x18 - 0x18: uart management
 * |-> 0x18: if '1', allow streaming of data, disallow (n)ack to rx requests
*/

#ifndef SERIALCOMPC_H
#define SERIALCOMPC_H

#include <Arduino.h>
#include "config.h"

/**
 * @brief Manage the serial communication with the PC.
 * @param conf* The configuration parameters struct pointer.
 * 
 * @warning Only DAC voltages are implemented at the moment.
 * @bug If it receive less than three characters it will not clean the serial buffer, 
 * hence even if the next command is correct it will fail. This will trigger the clearing
 * of the serial buffer and bring the system back to a stable state.
 * 
 * This function reads the serial input from the PC and parses it to the correct
 * variable. A reply is sent back to the PC.
 */
// void serialReadFromPC(struct confParam *conf);



#endif // SERIALCOMPC_H