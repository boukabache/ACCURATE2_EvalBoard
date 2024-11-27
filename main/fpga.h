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

/** 
 * @defgroup fpga_addresses FPGA configuration register addresses
 * @{
 */
// DAC configuration voltages
#define FPGA_DAC_VOUTA_ADDR 0x00 /** DAC output A address */
#define FPGA_DAC_VOUTB_ADDR 0x01 /** DAC output B address */
#define FPGA_DAC_VOUTC_ADDR 0x02 /** DAC output C address */
#define FPGA_DAC_VOUTD_ADDR 0x03 /** DAC output D address */
#define FPGA_DAC_VOUTE_ADDR 0x04 /** DAC output E address */
#define FPGA_DAC_VOUTF_ADDR 0x05 /** DAC output F address */
#define FPGA_DAC_VOUTG_ADDR 0x06 /** DAC output G address */
#define FPGA_DAC_VOUTH_ADDR 0x07 /** DAC output H address */

// ACCURATE configuration
#define FPGA_ACC_CHARGE_QUANTA_CP1_ADDR 0x08 /** Charge quanta CP1 address */
#define FPGA_ACC_CHARGE_QUANTA_CP2_ADDR 0x09 /** Charge quanta CP2 address */
#define FPGA_ACC_CHARGE_QUANTA_CP3_ADDR 0x0A /** Charge quanta CP3 address */
#define FPGA_ACC_COOLDOWN_MIN_CP1_ADDR 0x0B /** Cooldown minimum CP1 address */
#define FPGA_ACC_COOLDOWN_MAX_CP1_ADDR 0x0C /** Cooldown maximum CP1 address */
#define FPGA_ACC_COOLDOWN_MIN_CP2_ADDR 0x0D /** Cooldown minimum CP2 address */
#define FPGA_ACC_COOLDOWN_MAX_CP2_ADDR 0x0E /** Cooldown maximum CP2 address */
#define FPGA_ACC_COOLDOWN_MIN_CP3_ADDR 0x0F /** Cooldown minimum CP3 address */
#define FPGA_ACC_COOLDOWN_MAX_CP3_ADDR 0x10 /** Cooldown maximum CP3 address */
#define FPGA_ACC_RESET_OTA_ADDR 0x11 /** Reset OTA address */
#define FPGA_ACC_TCHARGE_ADDR 0x12 /** Charge time address */
#define FPGA_ACC_TINJECTION_ADDR 0x13 /** Injection time address */
#define FPGA_ACC_DISABLE_CP1_ADDR 0x14 /** Disable CP1 address */
#define FPGA_ACC_DISABLE_CP2_ADDR 0x15 /** Disable CP2 address */
#define FPGA_ACC_DISABLE_CP3_ADDR 0x16 /** Disable CP3 address */
#define FPGA_ACC_SINGLY_CP_ACTIVATION_ADDR 0x17 /** Singly CP activation address */

// UART management
#define FPGA_UART_MANAGEMENT_ADDR 0x18 /** UART management address, not to be confused with conf.serial.stream */
/** @} */

/**
 * @defgroup fpga_uart FPGA's UART constant
 * @{
 */
#define FPGA_UART_PAYLOAD_LENGTH 6 /** Length of the payload in bytes */
#define FPGA_UART_START_BYTE_TX 0xDD /** Start byte for the UART communication when tx*/
/** @} */

const uint8_t FPGA_CURRENT_ADDRESS = 0xDD; // WTF is this?


/**
 * @brief Struct containing the raw data coming from the FPGA.
 */
struct rawDataFPGA {
    uint64_t charge; // Detected charge in LSB
    uint32_t cp1Count; // Number of activations of CP1
    uint32_t cp2Count; // Number of activations of CP2
    uint32_t cp3Count; // Number of activations of CP3
    uint32_t cp1StartInterval; // Number of cycles -1 between start of sampling and
                               // first activation
    uint32_t cp1EndInterval; // Number of cycles - 1 between last activation and
                             // enf of sampling
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


/**
 * @brief Reads data from the FPGA and returns it in a struct.
 * @return rawDataFPGA struct containing the raw data.
 */
struct rawDataFPGA fpgaReadData();

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


// Calculates the current based on FPGA data readings, charge injection.
float fpga_calc_current(uint64_t data, float lsb, int period);

// Converts a voltage value to its corresponding DAC value.
extern uint32_t fpga_convert_volt_to_DAC(float voltage);

// Prints the current measurement in an appropriate unit (fA, pA, nA, uA).
CurrentMeasurement fpga_format_current(float currentInFemtoAmperes);

/**
 * @brief Sends a single parameter value to a specified address in the FPGA.
 * @param address The address of the parameter to be set (8-bit).
 * @param value The value to be set (32-bit).
 * 
 * The value is sent LSB first. Before sending the address, a start byte is sent.
 */
void sendToFPGA(uint8_t address, uint32_t value);

/**
 * @brief Update all FPGA parameters.
 * 
 * @note This function is called every time a new configuration parameter is set
 * via the SCPI interface. It's unefficient (as all the other parameters remains
 * the same) but keeps the code clean.
 */
void fpgaUpdateAllParam();

/**
 * @brief Checks the FPGA response after a write operation.
 * 
 * @return True if response is ack, false otherwise.
 * 
 * Response is contained in the last 4 bits of the message, as follow:
 * - 0b0000: ACK
 * - 0b0001: Generic error
 * - 0b0010: Transaction timeout
 * - 0b0100: Header error
 * - 0b1000: Message invalid
 * 
 * @warning This function assume that the fpga is in a state that allows
 * a response to be sent. It is not in charge to set the this state.
 */
bool fpgaCheckResponse();

#endif /* FPGA_H_ */
