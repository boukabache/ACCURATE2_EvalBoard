/*
 * fpga.h
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#ifndef FPGA_H_
#define FPGA_H_

#include <Arduino.h>
#include <cmath>
#include "config.h"

#define DOWNSCALING_FACTOR 10E14

const float CLOCK_PERIOD = 1E8; // ^-1
const float TW = 0.1;

const float Cf = 5e-12 * DOWNSCALING_FACTOR;
const float Tw = 0.1;

const float VINT1 = (VTH2_DEC - VTH1_DEC) * 0.9;

const float C1 = 454e-15 * DOWNSCALING_FACTOR;
const float C2 = 1060e-15 * DOWNSCALING_FACTOR;
const float C3 = 3950e-15 * DOWNSCALING_FACTOR;

const float Qref1 = C1 * (VTH7_DEC - VTH6_DEC);
const float Qref2 = C2 * (VTH7_DEC - VTH6_DEC);
const float Qref3 = C3 * (VTH7_DEC - VTH6_DEC);

const uint32_t INIT_CONFIG_ADDRESS = 0x01;
const uint32_t GATE_LENGTH_ADDRESS = 0x02;
const uint32_t RST_DURATION_ADDRESS = 0x03;
const uint32_t VBIAS1_ADDRESS = 0x04;
const uint32_t VBIAS2_ADDRESS = 0x05;
const uint32_t VBIAS3_ADDRESS = 0x06;
const uint32_t VCM_ADDRESS = 0x07;
const uint32_t VCM1_ADDRESS = 0x08;
const uint32_t VTH1_ADDRESS = 0x09;
const uint32_t VTH2_ADDRESS = 0x0A;
const uint32_t VTH3_ADDRESS = 0x0B;
const uint32_t VTH4_ADDRESS = 0x0C;
const uint32_t VTH5_ADDRESS = 0x0D;
const uint32_t VTH6_ADDRESS = 0x0E;
const uint32_t VTH7_ADDRESS = 0x0F;

const uint32_t INIT_CONFIG = 0x4107;
const uint32_t RST_DURATION = 0x0708;
const uint32_t INIT_CONFIG_START = 0x01C007;

// Attempts to read data from the FPGA, returns the current measured or NaN on error.
float readFPGA();

// Reads a 32-bit unsigned integer from the Serial1 buffer.
uint32_t readUInt32();

// Calculates the current based on FPGA data readings, both charge injection and direct slope.
float calculateCurrent(uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3, uint32_t data4);

// Attempts to resynchronize the data stream from the FPGA in case of errors.
void attemptResynchronization();

// Sends predefined configuration parameters to the FPGA.
void sendConfigurations();

// Converts a voltage value to its corresponding DAC value.
extern uint32_t convertVoltageToDAC(float voltage);

// Sends a single parameter value to a specified address in the FPGA.
void sendParam(uint32_t address, uint32_t value);

// Calculates the gate length based on predefined constants.
uint32_t calculateGateLength();

// Prints the current measurement in an appropriate unit (fA, pA, nA, uA).
void printCurrentInAppropriateUnit(float currentInFemtoAmperes);

#endif /* FPGA_H_ */
