#include <Arduino.h>
#include <Wire.h>
#include <Time.h>
#include <stdint.h>
#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"
#include "fpga.h"
#include "config.h"

void setup() {
    Serial1.begin(9600, SERIAL_8N2); // No parity, two stop bits
    while (!Serial1) {
        ;
    }

    Serial.begin(9600);

#ifdef DEBUG
    Serial.println("Debug mode is ON");
#endif

    Wire.begin();



    ssd1306_init();
    dac7578_init();

    sendConfigurations();
    dac7578_i2c_send_all_param();
}

void loop() {
    CurrentMeasurement measuredCurrent = readFPGA();
    String btnLedStatus = getPinStatus();
    TempHumMeasurement measuredTempHum = sht41_i2c_read();
    String temp;
    String humidity;

    if (measuredTempHum.status == SHT41_OK) {
        temp = String(measuredTempHum.temperature, 2) + "C";
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

    ssd1306_print_current_temp_humidity(measuredCurrent.convertedCurrent, measuredCurrent.range, temp, humidity);
    // Write to computer using Serial in the format (current[A], temp, humidity, btnLedStatus(btn0,btn1,btn2,led0,led1,led2 in binary))
    String message = "(" + String(measuredCurrent.currentInFemtoAmpere) + "," + String(temp) + "," + String(humidity) + "," + btnLedStatus + ")";
}

String getPinStatus() {
    String status = "";

    // Read button states (HIGH means pressed if using pull-up resistors)
    status += digitalRead(BTN_0_PIN) == HIGH ? "1" : "0";
    status += digitalRead(BTN_1_PIN) == HIGH ? "1" : "0";
    status += digitalRead(BTN_2_PIN) == HIGH ? "1" : "0";

    // Assuming HIGH means LED is ON. Adjust if your logic is inverted.
    status += digitalRead(LED_0_PIN) == HIGH ? "1" : "0";
    status += digitalRead(LED_1_PIN) == HIGH ? "1" : "0";
    status += digitalRead(LED_2_PIN) == HIGH ? "1" : "0";

    return status;
}
