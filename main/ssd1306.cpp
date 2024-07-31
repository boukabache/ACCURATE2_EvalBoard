/*
 * ssd1306.cpp
 *
 * Created: 10/11/2023 15:08
 *  Author: hliverud
 */


#include "ssd1306.h"

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

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
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("Current: ");
  display.setCursor(0, 10);
  display.print(current);
  display.print(" " + current_range);
  display.setCursor(0, 20);
  display.print("Temperature: ");
  display.print(temp);
  display.setCursor(0, 30);
  display.print("Humidity: ");
  display.print(humidity);
  display.print(" %");
  display.display();
}
