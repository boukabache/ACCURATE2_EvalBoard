/**
 * @file main.ino
 * @brief Main file for the project. Contains Arduino setup and loop functions.
 * @author Mattia Consani, hliverud
 * 
 * 
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

void setup() {
    Serial.begin(9600);
    while (!Serial);

    Serial1.begin(9600, SERIAL_8N1); // No parity, one stop bit
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
    // ----------------------------
    // TEMPERATURE AND HUMIDITY (from sensor)
    // ----------------------------

    // If J17 is connected to the MCU, uncomment the first line. If it is connected to the FPGA, uncomment the second line.
    TempHumMeasurement measuredTempHum;
    uint8_t sht_data[6];
    measuredTempHum = sht41_read_temp_humidity();

    // ----------------------------
    // TEMPERATURE AND HUMIDITY (from FPGA)
    // ----------------------------

    // TODO: timeout message if FPGA_TEMPHUM_ADDRESS never found
    // Check if data is available
    if (Serial1.find(FPGA_TEMPHUM_ADDRESS)) {
        // Wait for the full payload to be available
        while (Serial1.available() < TEMPHUM_PAYLOAD_LENGTH);
        // Read the payload
        Serial1.readBytes(sht_data, TEMPHUM_PAYLOAD_LENGTH);

        // Validate CRC
        if (crc8(sht_data, 2) != sht_data[2] || crc8(sht_data + 3, 2) != sht_data[5]) {
            measuredTempHum.status = SHT41_ERR_CRC;
        } else {
            uint16_t rawTemperature = (sht_data[1] << 8) | sht_data[0];
            uint16_t rawHumidity = (sht_data[3] << 8) | sht_data[2];

            sht41_calculate(rawTemperature, rawHumidity, &measuredTempHum);
        }
        
        // Clear the rest of the serial buffer, if not already empty
        while (Serial1.available()) {
            Serial1.read();
        }
    }

    String btnLedStatus = getPinStatus();

    String temp;
    String humidity;

    if (measuredTempHum.status == SHT41_OK) {
        temp = String(measuredTempHum.temperature, 2);
        humidity = String(measuredTempHum.humidity, 2);
    }
    else {
        switch (measuredTempHum.status) {
        case SHT41_ERR_I2C:
            temp = "I2C_ERR";
            humidity = "I2C_ERR";
            break;
        case SHT41_ERR_CRC:
            temp = "CRC_ERR";
            humidity = "CRC_ERR";
            break;
        case SHT41_ERR_MEASUREMENT:
            temp = "MEAS_ERR";
            humidity = "MEAS_ERR";
            break;
        default:
            temp = "UNK_ERR";
            humidity = "UNK_ERR";
            break;
        }
    }

    // ----------------------------
    // ACCURATE CURRENT MEASUREMENT
    // ----------------------------

    char chargeRaw[6];
    char cp1CountRaw[4];
    char cp2CountRaw[4];
    char cp3CountRaw[4];
    char cp1LastIntervalRaw[5];

    uint64_t int_data = 0;

    char buffer[27];
    // Only read and update display if there is data available
    if (Serial1.find(FPGA_CURRENT_ADDRESS)) {
        // Wait for the full payload to be available
        //while (Serial1.available() < FPGA_PAYLOAD_LENGTH);
        // Read the payload
        Serial1.readBytes(chargeRaw, 6);

        // FIXME: THIS IS WRONG. rawCharge is of signed type!! What happens to leading '1's if it is negative?
        // Convert the payload to a 64-bit integer rapresentation
        for (int i = 0; i < 6; i++) {
            int_data |= ((uint64_t)chargeRaw[i] << (8 * i));
        }

        // Calculate the current and format it
        float readCurrent = fpga_calc_current(int_data, DEFAULT_LSB, DEFAULT_PERIOD);
        CurrentMeasurement current_measurement = fpga_format_current(readCurrent);

        Serial1.readBytes(cp1CountRaw, 4);
        uint32_t cp1Count = *(uint32_t*) cp1CountRaw;

        Serial1.readBytes(cp2CountRaw, 4);
        uint32_t cp2Count = *(uint32_t*) cp2CountRaw;

        Serial1.readBytes(cp3CountRaw, 4);
        uint32_t cp3Count = *(uint32_t*) cp3CountRaw;

        Serial1.readBytes(cp1LastIntervalRaw, 5);
        int64_t cp1LastInterval = 0;

        for (int i = 0; i < 5; i++) {
            cp1LastInterval |= ((int64_t)cp1LastIntervalRaw[i] << (8 * i));
        }

        char  buffer[21]; //maximum value for uint64_t is 20 digits
        sprintf(buffer, "%" PRId64, cp1LastInterval);
        // Print the current and update the display
        ssd1306_print_current_temp_humidity(current_measurement.convertedCurrent, current_measurement.range, temp + " C", humidity);
        
        String message = String(current_measurement.currentInFemtoAmpere) + "," +
                         String(cp1Count) + "," +
                         String(cp2Count) + "," +
                         String(cp3Count) + "," +
                         String(buffer)+ "," +
                         String(temp) + "," +
                         String(humidity) + "," +
                         btnLedStatus;
        Serial.println(message);

        // TODO: Move back to function implementation to make the main loop more readable
        // ssd1306_print_current_temp_humidity(current_measurement.convertedCurrent, current_measurement.range, temp + " C", humidity);
        // String message = String(current_measurement.currentInFemtoAmpere) + "," + String(temp) + "," + String(humidity) + "," + btnLedStatus;
        // Serial.println(message);
        
        // Clear the rest of the serial buffer, if not already empty
        while (Serial1.available()) {
            Serial1.read();
        }
    }
}


/**
 * @brief Get the current status of the buttons and LEDs
 * @return String The status of the buttons and LEDs encoded in a string
 * 
 * The status is encoded as follows:
 * - The first three characters represent the status of the buttons.
 *   Order is BUTTON, BUTTON2, BUTTON3. 1 means pressed, 0 means not pressed.
 * - The last three characters represent the status of the LEDs.
 *   Order is LED, LED2, LED3. 1 means ON, 0 means OFF.
 */
String getPinStatus() {
    String status = "";

    // Read button states (HIGH means pressed if using pull-up resistors)
    status += digitalRead(PIN_BUTTON) == LOW ? "1" : "0";
    status += digitalRead(PIN_BUTTON2) == LOW ? "1" : "0";
    status += digitalRead(PIN_BUTTON3) == LOW ? "1" : "0";

    // Assuming HIGH means LED is ON.
    status += digitalRead(PIN_LED) == LOW ? "1" : "0";
    status += digitalRead(PIN_LED2) == LOW ? "1" : "0";
    status += digitalRead(PIN_LED3) == LOW ? "1" : "0";

    return status;
}
