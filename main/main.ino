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
#include <math.h>

#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"
#include "fpga.h"
#include "config.h"
#include "ltc2471.h"
#include "RTClib.h"
#include "SD.h"

/*
The library is fully implemented in the header file, so in order to avoid multiple
definition during linking, the NO_IMPL flag is defined in all outside one include
statements.
*/
#define VREKRER_SCPI_PARSER_NO_IMPL
#include "scpiInterface.h"

enum ScreenMode screenMode = CURRENT_DISPLAY;
bool oldBtn1Status = 1;
bool newModeFlag = false;
int chargeIntegration = 0;

// Global configuration struct definition
struct confParam conf;

// SCPI parser object definition
SCPI_Parser my_instrument;

// RTL PCF8523 object definition
RTC_PCF8523 rtc;

// SD card object definition
File logFile;

void setup() {
    // Init USB-C serial
    Serial.begin(9600);
    while (!Serial);

    // Init FPGA serial
    Serial1.begin(19200, SERIAL_8N1); // No parity, one stop bit
    Serial1.setTimeout(500);

    // Init I2C
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

    // Init screen and DAC
    ssd1306_init();
    dac7578_init();

    // Init SCPI parser
    init_scpiInterface();

    // Get samd21 UUID
    conf.UUID = getChipUUID();

    // Init RTC
    if (!rtc.begin()) {
        // Serial.println("Couldn't find RTC");
    }
    if (! rtc.initialized() || rtc.lostPower()) {
        // Serial.println("RTC is NOT initialised! Doing it now...");
        // following line sets the RTC to the date & time this sketch was compiled
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    }
    rtc.start();

    // Init SD card
    const int chipSelect = 10;
    pinMode(SD_CHIP_SELECT_PIN, OUTPUT);
    if (!SD.begin(chipSelect)) {
        // Serial.println("Card failed, or not present");
    } else {
        char filename[] = ""; // TODO: implement file naming structure
        logFile = SD.open(filename, FILE_WRITE);
    }

    // For the mu_sweep test
    conf.serial.stream = true;
    conf.serial.rawOutput = true;
}

void loop() {
    // Read data from FPGA
    struct rawDataFPGA rawData;
    rawData = fpga_read_data();

    // Read from PC -> SCPI parser
    my_instrument.ProcessInput(Serial, "\n");

    // Only update display and send out data over serial
    // if there is data available.
    if (rawData.valid) {
        rawData.valid = false;

        // Update the ssd1306 screen
        updateScreen(rawData);

        // Get output string
        String message = getOutputString(rawData);
        // Print over serial
        if (conf.serial.stream) {
            Serial.println(message);
        }
        // Log to SD card
        if (conf.serial.log) {
            logFile.println(message);
        }
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

    // Screen update
    float chargefA = (rawData.charge * DEFAULT_LSB) / 1000;
    switch (screenMode) {
    case CHARGE_DETECTION:
        ssd1306_print_charge(chargefA, temp, humidity, "Single sample");
        break;
    case CHARGE_INTEGRATION:
        if (newModeFlag == true) {
            newModeFlag = false;
            chargeIntegration = 0;
        }
        chargeIntegration += chargefA;
        ssd1306_print_charge(chargeIntegration, temp, humidity, "Integration");
        break;
    case VAR_SEMPLING_TIME:
        // ssd1306_print_transition(screenMode);
        ssd1306_print_charge(rawData.charge , temp, humidity, "Multi sample");
        break;
    case CURRENT_DISPLAY:
        ssd1306_print_current_temp_humidity(current_measurement.convertedCurrent, current_measurement.range, temp, humidity);
    default:
        break;
    }
}


/**
 * @brief Retrieve the 128-bit UUID of the SAMD21 chip
 * @return Pointer to the UUID vector
 * 
 * The UUID is stored in the SAMD21 chip's memory. This function reads the
 * memory at the addresses specified by the vendor and returns the
 * pointer to the UUID vector.
 */
uint32_t * getChipUUID() {
    static uint32_t uuid[4] = {0};
    uuid[0] = *(volatile uint32_t *)0x0080A00C;
    uuid[1] = *(volatile uint32_t *)0x0080A040;
    uuid[2] = *(volatile uint32_t *)0x0080A044;
    uuid[3] = *(volatile uint32_t *)0x0080A048;
    
    return uuid;
}


/**
 * @brief Parse the button status and update the screen mode
 * @param status The status of the buttons and LEDs
 * @param screenMode The current screen mode
 * @return The new screen mode
 *
 * Check if button1 is pressed. If so, cycle to the next screen mode.
 */
enum ScreenMode parseButtons(struct IOstatus status, enum ScreenMode screenMode) {
    enum ScreenMode newState = screenMode;

    // Button is idle high
    if (status.btn1 == 1 && oldBtn1Status == 0) {
        // Set flag to signify that we're entering a new screen mode
        newModeFlag = true;

        switch (screenMode) {
        case CHARGE_DETECTION:
            newState = CHARGE_INTEGRATION;
            break;
        case CHARGE_INTEGRATION:
            newState = VAR_SEMPLING_TIME;
            break;
        case VAR_SEMPLING_TIME:
            newState = CURRENT_DISPLAY;
            break;
        case CURRENT_DISPLAY:
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
    
    // Create timestamp string
    String timestamp = rtc.now().timestamp();

    if (conf.serial.rawOutput) {
        message = uint64ToString(rawData.charge) + "," +
                String(rawData.cp1Count) + "," +
                String(rawData.cp2Count) + "," +
                String(rawData.cp3Count) + "," +
                String(rawData.cp1StartInterval) + "," +
                String(rawData.cp1EndInterval) + "," +
                String(rawData.tempSht41) + "," +
                String(rawData.humidSht41) + "," +
                btnLedStatus.status;
                // + "," + timestamp;timestamp;
    } else {
        // Calculate the time intervals
        float startIntervalTime = (rawData.cp1StartInterval + 1) * 1/ACCURATE_CLK;
        float endIntervalTime = (rawData.cp1EndInterval + 1) * 1/ACCURATE_CLK;

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
                String(startIntervalTime) + "," +
                String(endIntervalTime) + "," +
                String(temp) + "," +
                String(humidity) + "," +
                btnLedStatus.status;
                // + "," + timestamp;
    }
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
