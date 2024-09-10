/**
 * @file ssd1306.h
 * @brief Header file for the SSD1306 OLED display helper functions.
 * @author Mattia Consani, hliverud
 * 
 * Contains the init function and the print to oled functions.
 * 
 */

#include <stdint.h>
#include <Arduino.h>
#include "config.h"


/**
 * @brief Enum to define the different screen modes.
 */
enum ScreenMode {
    CHARGE_DETECTION,
    CHARGE_INTEGRATION,
    VAR_SEMPLING_TIME
};


#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

#define SSD1306_ADDR 0x3C

void ssd1306_init();

void ssd1306_print_current_temp_humidity(float current, String current_range, String temp, String humidity);


/**
 * @brief Print the charge value to the display.
 * @param charge The charge value to print [aC].
 * @param temp The temperature value to print [°C].
 * @param humidity The humidity value to print [%].
 * @param mode The current screen mode.
 */
void ssd1306_print_charge(float charge, String temp, String humidity, String mode);