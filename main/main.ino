#include <Arduino.h>
#include <Wire.h>
#include <Time.h>
#include <stdint.h>
#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"
#include "fpga.h"
#include "config.h"
#include "ltc2471.h"

void setup() {
    Serial.begin(9600);
    while (!Serial) {
        ;
    }

    Serial1.begin(9600, SERIAL_8N1); // No parity, one stop bit
    while (!Serial1) {
        ;
    }

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

    ssd1306_init();
    dac7578_init();

    fpga_send_configurations();
    dac7578_i2c_send_all_param();
}

void loop() {
    // To measure current through the FPGA with charge injection, uncomment first line, to measure current with the ADC through the OTA output, uncomment second line.
    // CurrentMeasurement measuredCurrent = fpga_read_current();
    // float measuredCurrent = ltc2471_read_current();

    // ----------------------------
    // TEMPERATURE AND HUMIDITY
    // ----------------------------

    // If J17 is connected to the MCU, uncomment the first line. If it is connected to the FPGA, uncomment the second line.
    TempHumMeasurement measuredTempHum = sht41_read_temp_humidity();
    //TempHumMeasurement measuredTempHum = fpga_read_temp_humidity();

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

    int64_t int_data = 0;

    // Only read and update display if there is data available
    if (Serial1.find(FPGA_CURRENT_ADDRESS)) {
        // Wait for the full payload to be available
        //while (Serial1.available() < FPGA_PAYLOAD_LENGTH);
        // Read the payload
        Serial1.readBytes(chargeRaw, 6);

        // FIXME: THIS IS WRONG. rawCharge is of signed type!! What happens to leading '1's if it is negative?
        // Convert the payload to a 64-bit integer rapresentation
        for (int i = 0; i < 6; i++) {
            int_data |= ((int64_t)chargeRaw[i] << (8 * i));
        }

        // Calculate the current and format it
        float readCurrent = fpga_calc_current(int_data, DEFAULT_LSB, DEFAULT_PERIOD);
        CurrentMeasurement measurement = fpga_format_current(readCurrent);

        Serial1.readBytes(cp1CountRaw, 4);
        uint32_t cp1Count = *(uint32_t*) cp1CountRaw;

        Serial1.readBytes(cp2CountRaw, 4);
        uint32_t cp2Count = *(uint32_t*) cp2CountRaw;

        Serial1.readBytes(cp3CountRaw, 4);
        uint32_t cp3Count = *(uint32_t*) cp3CountRaw;

        Serial1.readBytes(cp3CountRaw, 4);
        uint32_t cp3Count = *(uint32_t*) cp3CountRaw;

        Serial1.readBytes(cp1LastIntervalRaw, 5);
        uint64_t cp1LastInterval = 0;

        for (int i = 0; i < 5; i++) {
            cp1LastInterval |= ((int64_t)cp1LastIntervalRaw[i] << (8 * i));
        }


        // Print the current and update the display
        ssd1306_print_current_temp_humidity(measurement.convertedCurrent, measurement.range, temp + " C", humidity);
        String message = String(measurement.currentInFemtoAmpere) + "," +
                         String(cp1Count) + "," +
                         String(cp2Count) + "," +
                         String(cp3Count) + "," +
                         String(cp1LastInterval) + "," +
                         String(temp) + "," +
                         String(humidity) + "," +
                         btnLedStatus;
        Serial.println(message);

        // Clear the rest of the serial buffer, if not empty
        while (Serial1.available()) {
            Serial1.read();
        }
    }

    // ----------------------------
    // INACCURATE CURRENT MEASUREMENT HAHAHAHAHAHA
    // ----------------------------
    // CurrentMeasurement measurement;
    // measurement.currentInFemtoAmpere = std::nan("1"); // NaN to indicate error
    // measurement.convertedCurrent = std::nan("1");
    // measurement.range = "Error";

    // ssd1306_print_current_temp_humidity(measurement.convertedCurrent, measurement.range, temp + " C", humidity);
    // // String message = String(measurement.currentInFemtoAmpere) + "," + String(temp) + "," + String(humidity) + "," + btnLedStatus;
    // String message = String("1234") + "," + "99.9" + "," + "25.55" + "," + "000000";
    // Serial.println(message);
}

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
