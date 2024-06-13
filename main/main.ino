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

    Serial1.begin(9600, SERIAL_8N2); // No parity, two stop bits
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
    CurrentMeasurement measuredCurrent = fpga_read();
    //float current = ltc2471_read_current();
    String btnLedStatus = getPinStatus();
    TempHumMeasurement measuredTempHum = sht41_i2c_read();
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

    ssd1306_print_current_temp_humidity(measuredCurrent.convertedCurrent, measuredCurrent.range, temp + " C", humidity);
    String message = String(measuredCurrent.currentInFemtoAmpere) + "," + String(temp) + "," + String(humidity) + "," + btnLedStatus;
    Serial.println(message);
    delay(50);
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
