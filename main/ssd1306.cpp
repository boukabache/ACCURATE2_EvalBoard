/**
 * @file ssd1306.cpp
 * @brief Source file for the SSD1306 OLED display helper functions.
 * @author Mattia Consani, hliverud
 */

#include "ssd1306.h"

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MathHelpers.h"

char *dtostrf (double val, signed char width, unsigned char prec, char *sout);

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

void ssd1306_init() {
    if (!display.begin(SSD1306_SWITCHCAPVCC, SSD1306_ADDR)) {
        Serial.println(F("SSD1306 allocation failed"));
        for (;;);
    }
    delay(2000);
    display.clearDisplay();
    display.setTextColor(WHITE);
}

void ssd1306_print_current_temp_humidity(float current, String current_range, String temp, String humidity) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(0, 0);
    display.print("Current: ");
    display.setCursor(0, 20);
    display.print(current);
    display.print(" " + current_range);
    display.setCursor(0, 40);
    display.setTextSize(1);
    display.print("T: ");
    display.print(temp);
    display.print(" H: ");
    display.print(humidity);
    display.print(" %");
    display.setCursor(0, 54);
    display.print("Mode: SWAG");
    display.display();
}


void ssd1306_print_charge(float charge, String temp, String humidity, String mode) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(0, 0);
    display.print("Charge[fC]");
    display.setCursor(0, 20);
    if (charge < 10000) {
        display.print(charge);
    } else {
        display.print(sci(charge, 3));
    }
    display.setCursor(0, 40);
    display.setTextSize(1);
    display.print("T: ");
    display.print(temp);
    display.print(" H: ");
    display.print(humidity);
    display.print(" %");
    display.setCursor(0, 54);
    display.print("Mode: " + mode);
    display.display();
}

void ssd1306_print_transition(int screenMode) {
    // Prepare the display
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(0, 0);

    // Print the correct screen mode
    switch (screenMode) {
    case CHARGE_DETECTION:
        display.print("CHARGE_DETECTION");
        break;
    case CHARGE_INTEGRATION:
        display.print("CHARGE_INTEGRATION");
        break;
    case VAR_SEMPLING_TIME:
        display.print("VAR_SEMPLING_TIME");
        break;
    default:
        display.print("Unknown");
        break;
    }

    // Hold it on screen for sec seconds
    delay(TRANSITION_TIME * 1000);
}