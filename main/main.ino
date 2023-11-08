#include <Arduino.h>
#include <Wire.h>
#include <Time.h>
#include <stdint.h>
#include "config.h"
#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"

void setup() {
    Wire.begin();

    Serial.begin(9600);
    while (!Serial);

    dac7578_init(DAC_ADDRESS);
    dac7578_i2c_send_all_param();
}

void loop() {
    digitalWrite(PIN_LED_13, HIGH);
    delay(1000);
    digitalWrite(PIN_LED_13, LOW);
    delay(1000);
}
