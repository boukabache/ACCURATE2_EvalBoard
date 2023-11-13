/*
 * ssd1306.h
 *
 * Created: 10/11/2023 15:08:51 AM
 *  Author: hliverud
 */

#include <stdint.h>
#include <Arduino.h>

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

void ssd1306_init(uint8_t addr);

void ssd1306_print_currentmA_temp_humidity(float current, String current_range, float temp, float humidity);
