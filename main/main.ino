#include <Arduino.h>
#include <Wire.h>
#include <Time.h>
#include <stdint.h>
#include "config.h"
#include "sht41.h"
#include "dac7578.h"
#include "ssd1306.h"

void setup() {
    pinMode(LED_ALIVE_PIN, OUTPUT);
    digitalWrite(LED_ALIVE_PIN, HIGH);

    pinMode(LED_1_PIN, OUTPUT);
    digitalWrite(LED_1_PIN, HIGH);

    dac7578_init(DAC_ADDRESS);
    dac7578_i2c_send_all_param();

    delay(200);
    digitalWrite(LED_1_PIN, LOW);

    sht41_meas_enable = true;
    sht41_start_t = true;
    sht41_start_rh = true;
    sht41_i2c_read_temp();
	sht41_i2c_read_rh();

    ssd1306_init(SSD1306_ADDR);
}

void loop() {
    if (sht41_meas_enable) {
        if (sht41_start_t) {
            sht41_i2c_read_temp();
        }
        else if (sht41_start_rh) {
            sht41_i2c_read_rh();
        }
    }
}
