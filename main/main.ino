/**
 * @file main.ino
 * @brief Main file for the project. Contains Arduino setup and loop functions.
 * @author Mattia Consani, hliverud
 *
*/

#include <Arduino.h>
#include <Wire.h>
#include <TimeLib.h>
#include <stdint.h>
#include <inttypes.h>

#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"
#include "fpga.h"
#include "config.h"
#include "ltc2471.h"

enum ScreenMode screenMode = CHARGE_DETECTION;
bool oldBtn1Status = 1;


void setup() {
    Serial.begin(9600);
    while (!Serial);

    Serial1.begin(19200, SERIAL_8N1); // No parity, one stop bit
    Serial1.setTimeout(500);
    Wire.begin();

    // Init LEDs and buttons and set LEDs to off
    pinMode(PIN_BUTTON, INPUT_PULLUP);
    pinMode(PIN_BUTTON2, INPUT_PULLUP);
    pinMode(PIN_BUTTON3, INPUT_PULLUP);
    pinMode(PIN_LED, OUTPUT);
    pinMode(PIN_LED2, OUTPUT);
    pinMode(PIN_LED3, OUTPUT);
    pinMode(LED_ALIVE, OUTPUT);
    digitalWrite(LED_ALIVE, HIGH);
    // Turn off LEDs
    digitalWrite(PIN_LED, HIGH);
    digitalWrite(PIN_LED2, HIGH);
    digitalWrite(PIN_LED3, HIGH);

#ifdef DEBUG
    Serial.println("Debug mode is ON");
#endif

    // Init screen and DAC
    ssd1306_init();
    dac7578_init();

    // Send configuration to FPGA and DAC
    // delay(1000); // Wait for the FPGA to boot up
    // fpga_send_configurations();
    // dac7578_i2c_send_all_param();
}

#include <math.h>

void loop() {
    struct rawDataFPGA rawData;
    rawData = fpga_read_data();

    // Only read and update display if there is data available
    if (rawData.valid) {
        rawData.valid = false;

        // Update the oled screen
        updateScreen(rawData);

        // Get and print the output string
        String message;
        message = getOutputString(rawData);
        Serial.println(message);
    }
}


/**
 * @brief Update the screen mode
 * @param rawData The raw data coming from the FPGA
 * @return void
 *
 * Calculate the cahrge value based on the current screen mode and print it
 * to display. Check if button 1 got pressed, if so cycle to the next screen
 * mode.
 */
void updateScreen(struct rawDataFPGA rawData) {
    IOstatus status = getPinStatus();
    screenMode = parseButtons(status, screenMode);

    // Calculate the current and format it
    float readCurrent = fpga_calc_current(rawData.charge, DEFAULT_LSB, DEFAULT_PERIOD);
    CurrentMeasurement current_measurement = fpga_format_current(readCurrent); 

    // Calculate temperature and humidity from raw data
    TempHumMeasurement measuredTempHum;
    sht41_calculate(rawData.tempSht41, rawData.humidSht41, &measuredTempHum);
    String temp = String(measuredTempHum.temperature, 2);
    String humidity = String(measuredTempHum.humidity, 2);

    Serial.println(screenMode);


    // Screen update
    switch (screenMode) {
    case CHARGE_DETECTION:
        // ssd1306_print_transition(screenMode);
        ssd1306_print_charge(rawData.charge , temp, humidity, "Single sample");
        break;
    case CHARGE_INTEGRATION:
        // ssd1306_print_transition(screenMode);
        ssd1306_print_charge(rawData.charge , temp, humidity, "Integration");
        break;
    case VAR_SEMPLING_TIME:
        // ssd1306_print_transition(screenMode);
        ssd1306_print_charge(rawData.charge , temp, humidity, "Multi sample");
        break;
    default:
        break;
    }
}


/**
 * @brief Parse the button status and update the screen mode
 * @param status The status of the buttons and LEDs
 * @param screenMode The current screen mode
 * @return screenMode The new screen mode
 *
 * Check if button1 is pressed. If so, cycle to the next screen mode.
 */
enum ScreenMode parseButtons(struct IOstatus status, enum ScreenMode screenMode) {
    enum ScreenMode newState = screenMode;

    // Button is idle high
    if (status.btn1 == 1 && oldBtn1Status == 0) {
        switch (screenMode) {
        case CHARGE_DETECTION:
            newState = CHARGE_INTEGRATION;
            break;
        case CHARGE_INTEGRATION:
            newState = VAR_SEMPLING_TIME;
            break;
        case VAR_SEMPLING_TIME:
            newState = CHARGE_DETECTION;
            break;
        default:
            break;
        }
    }
    oldBtn1Status = status.btn1;

    return newState;
}


/**
 * @brief Get the output string to print
 * @param rawData The raw data from the FPGA
 * @return The output string
 * 
 * @note It uses the global flag RAW_OUTPUT, defined in the file config.h,
 * to decide if the output should be raw or formatted.
 */
String getOutputString(struct rawDataFPGA rawData) {
    String message;
    struct IOstatus btnLedStatus = getPinStatus();

#ifdef RAW_OUTPUT
    message = uint64ToString(rawData.charge) + "," +
            String(rawData.cp1Count) + "," +
            String(rawData.cp2Count) + "," +
            String(rawData.cp3Count) + "," +
            String(rawData.cp1LastInterval) + "," +
            String(rawData.tempSht41) + "," +
            String(rawData.humidSht41) + "," +
            btnLedStatus.status;
#else
    // Calculate the last activation time
    float lastActivationTime = (rawData.cp1LastInterval + 1) * 1/ACCURATE_CLK;

    // Calculate temperature and humidity
    TempHumMeasurement measuredTempHum;
    sht41_calculate(rawData.tempSht41, rawData.humidSht41, &measuredTempHum);
    String temp = String(measuredTempHum.temperature, 2);
    String humidity = String(measuredTempHum.humidity, 2);

    // Calculate the current and format it
    float readCurrent = fpga_calc_current(rawData.charge, DEFAULT_LSB, DEFAULT_PERIOD);
    CurrentMeasurement current_measurement = fpga_format_current(readCurrent); 

    message = String(current_measurement.currentInFemtoAmpere) + "," +
            String(rawData.cp1Count) + "," +
            String(rawData.cp2Count) + "," +
            String(rawData.cp3Count) + "," +
            String(lastActivationTime) + "," +
            String(temp) + "," +
            String(humidity) + "," +
            btnLedStatus.status;
#endif
    return message;
}


/**
 * @brief Convert a uint64_t to a string
 * @param input The input value
 * @return The string representation of the input value
 * 
 * Especially useful for printing on serial 64-bit values.
 */
String uint64ToString(uint64_t val) {
    char buffer[21]; //maximum value for uint64_t is 20 digits
    char* ndx = &buffer[sizeof(buffer) - 1];
    *ndx = '\0';
    do {
        *--ndx = val % 10 + '0';
        val = val  / 10;
    } while (val != 0);

    return ndx;
}