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
#include "sht41.h"

const float CLOCK_PERIOD = 1E8; // ^-1

const float TW = 0.1;

const float DEFAULT_LSB = 39.339; // aC
const int DEFAULT_PERIOD = 100; // ms

const int FPGA_DATA_LENGTH = 8;
const int FPGA_PAYLOAD_LENGTH = FPGA_DATA_LENGTH - 1; // 7 bytes payload + 1 byte address
const uint8_t FPGA_CURRENT_ADDRESS = 0xDD;
const int TEMPHUM_DATA_LENGTH = 7;
const int TEMPHUM_PAYLOAD_LENGTH = TEMPHUM_DATA_LENGTH - 1; // 6 bytes payload + 1 byte address
const uint8_t FPGA_TEMPHUM_ADDRESS = 0xEE;

const uint8_t INIT_CONFIG_ADDRESS = 0x01;
const uint8_t GATE_LENGTH_ADDRESS = 0x02;
const uint8_t RST_DURATION_ADDRESS = 0x03;
const uint8_t VBIAS1_ADDRESS = 0x04;
const uint8_t VBIAS2_ADDRESS = 0x05;
const uint8_t VBIAS3_ADDRESS = 0x06;
const uint8_t VCM_ADDRESS = 0x07;
const uint8_t VCM1_ADDRESS = 0x08;
const uint8_t VTH1_ADDRESS = 0x09;
const uint8_t VTH2_ADDRESS = 0x0A;
const uint8_t VTH3_ADDRESS = 0x0B;
const uint8_t VTH4_ADDRESS = 0x0C;
const uint8_t VTH5_ADDRESS = 0x0D;
const uint8_t VTH6_ADDRESS = 0x0E;
const uint8_t VTH7_ADDRESS = 0x0F;

const uint32_t INIT_CONFIG = 0x4107;
const uint32_t RST_DURATION = 0x0708;
const uint32_t INIT_CONFIG_START = 0x01C007;

// Attempts to read data from the FPGA, returns the current measured or NaN on error.
CurrentMeasurement fpga_read_current();

// Reads temperature and humidity data from the FPGA
TempHumMeasurement fpga_read_temp_humidity();

// Calculates the current based on FPGA data readings, charge injection.
float fpga_calc_current(uint64_t data, float lsb, int period);

// Sends predefined configuration parameters to the FPGA.
void fpga_send_configurations();

// Converts a voltage value to its corresponding DAC value.
extern uint32_t fpga_convert_volt_to_DAC(float voltage);

// Sends a single parameter value to a specified address in the FPGA.
void fpga_send_parameters(uint8_t address, uint32_t value);

// Calculates the gate length based on predefined constants.
uint32_t fpga_calculate_gate_len();

// Prints the current measurement in an appropriate unit (fA, pA, nA, uA).
CurrentMeasurement fpga_format_current(float currentInFemtoAmperes);

#endif /* FPGA_H_ */
