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
 * @brief Print the screen mode to the display for sec seconds.
 * 
 * @param screenMode The screen mode to print.
 * 
 * @warning This function contains a delay call! It will block the
 * execution for sec seconds.
 */
void ssd1306_print_transition(int screenMode);