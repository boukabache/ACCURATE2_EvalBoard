/**
 * @file fpga.h
 * @brief Header file for the FPGA helper functions.
 * @author Mattia Consani, hliverud
 */
#ifndef FPGA_H_
#define FPGA_H_

#include <Arduino.h>
#include <cmath>
#include "config.h"
#include "sht41.h"

/**
 * @brief Struct containing the raw data coming from the FPGA.
 */
struct rawDataFPGA {
    uint64_t charge; // Detected charge in LSB
    uint32_t cp1Count; // Number of activations of CP1
    uint32_t cp2Count; // Number of activations of CP2
    uint32_t cp3Count; // Number of activations of CP3
    uint32_t cp1LastInterval; // Time between last two CP1 activations
    uint16_t tempSht41; // Temperature data from SHT41
    uint16_t humidSht41; // Humidity data from SHT41
    bool valid; // Flag to indicate if the data is valid
};

/**
 * @brief Structure to hold the current status of buttons and LEDs.
 */
struct IOstatus {
    bool btn1; // Button 1
    bool btn2; // Button 2
    bool btn3; // Button 3
    bool led1; // LED 1
    bool led2; // LED 2
    bool led3; // LED 3
    String status; // Status string
};



const float CLOCK_PERIOD = 1E8; // ^-1

const float TW = 0.1;

const float DEFAULT_LSB = 39.339; // aC
const int DEFAULT_PERIOD = 100; // ms

const int FPGA_DATA_LENGTH = 7;
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


/**
 * @brief Reads data from the FPGA and returns it in a struct.
 * @return rawDataFPGA struct containing the raw data.
 */
struct rawDataFPGA fpga_read_data();

/**
 * @brief Get the current status of the buttons and LEDs
 * @return PinStatus The status of the buttons and LEDs + string encoding
 *
 * The status is encoded as follows:
 * - The first three characters represent the status of the buttons.
 *   Order is BUTTON1, BUTTON2, BUTTON3. 1 means pressed, 0 means not pressed.
 * - The last three characters represent the status of the LEDs.
 *   Order is LED1, LED2, LED3. 1 means ON, 0 means OFF.
 */
struct IOstatus getPinStatus();


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
