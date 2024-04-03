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

    Wire.begin();

    pinMode(LED_0_PIN, OUTPUT);
    pinMode(LED_1_PIN, OUTPUT);
    pinMode(LED_2_PIN, OUTPUT);

    pinMode(BTN_0_PIN, INPUT);
    pinMode(BTN_1_PIN, INPUT);
    pinMode(BTN_2_PIN, INPUT);

    ssd1306_init();
    dac7578_init();

    pinMode(PIN_LED_13, OUTPUT);

    sendConfigurations();
    dac7578_i2c_send_all_param();
}

void loop() {
    CurrentMeasurement measuredCurrent = readFPGA();
    float measuredTemperature = sht41_i2c_read_temp();
    float measuredHumidity = sht41_i2c_read_rh();
    String btnLedStatus = getPinStatus();

    // Write to computer using Serial in the format (current[A], temp, humidity, btnLedStatus(btn0,btn1,btn2,led0,led1,led2 in binary))
    String message = "(" + String(measuredCurrent.currentInFemtoAmpere) + "," + String(measuredTemperature) + "," + String(measuredHumidity) + "," + btnLedStatus + ")";

    ssd1306_print_current_temp_humidity(measuredCurrent.convertedCurrent, measuredCurrent.range, measuredTemperature, measuredHumidity);
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
