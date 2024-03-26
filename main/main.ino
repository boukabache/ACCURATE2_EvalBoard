#include <Arduino.h>
#include <Wire.h>
#include <Time.h>
#include <stdint.h>
#include "config.h"
#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"
#include "fpga.h"

void setup() {
    Serial1.begin(9600, SERIAL_8N2); // No parity, two stop bits
    while (!Serial1) {
        ;
    }

    Serial.begin(9600);

    Wire.begin();

    ssd1306_init();
    dac7578_init();

    pinMode(PIN_LED_13, OUTPUT);

    sendConfigurations();
}

void loop() {
    readFPGA();
}
