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
    Wire.begin();
    ssd1306_init();
    dac7578_init();

    pinMode(PIN_LED_13, OUTPUT);

    Serial.begin(9600);
    while (!Serial);
}

void loop() {
    digitalWrite(PIN_LED_13, HIGH);
    delay(1000);
    digitalWrite(PIN_LED_13, LOW);
    delay(1000);

    int ranPercent = random(0, 100);
    int ranTemp = random(0, 100);
    int ranCurrentFemto = random(0, 100);
    ssd1306_print_currentmA_temp_humidity(ranCurrentFemto, "fA", ranTemp, ranPercent);
}
