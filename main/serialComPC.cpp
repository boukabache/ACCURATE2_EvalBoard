/**
 * @file serial.cpp
 * @brief Source file for the serial communication functions between MCU and PC.
 * @author Mattia Consani
 * 
 * Contains the implementation of logic to receive data from the computer and
 * parse it to the correct variable.
*/

#include "serialComPC.h"


void serialReadFromPC() {
    if (Serial.available() >= 3) {
        char command[3];
        Serial.readBytes(command, 3);

        // ----------------- SET command -----------------
        if (String(command) == "SET") {
            Serial.println("SET command received");

            if (Serial.available() >= 2) {
                char address[2];
                Serial.readBytes(address, 2);

                if (String(address) == "01") {
                    Serial.println("SET INIT_CONFIG command received");

                    if (Serial.available() >= 1) {
                        char value[1];
                        Serial.readBytes(value, 1);

                        Serial.print("Value: ");
                        Serial.println(value);
                    }
                } else if (String(address) == "02") {
                    Serial.println("SET GATE_LENGTH command received");

                    if (Serial.available() >= 1) {
                        char value[1];
                        Serial.readBytes(value, 1);

                        Serial.print("Value: ");
                        Serial.println(value);
                    }
                } else if (String(address) == "03") {
                    Serial.println("SET RST_DURATION command received");

                    if (Serial.available() >= 1) {
                        char value[1];
                        Serial.readBytes(value, 1);

                        Serial.print("Value: ");
                        Serial.println(value);
                    }
                } else if (String(address) == "04") {
                    Serial.println("SET VBIAS1 command received");

                    if (Serial.available() >= 1) {
                        char value[1];
                        Serial.readBytes(value, 1);

                        Serial.print("Value: ");
                        Serial.println(value);
                    }
                }
            }
        }

        // ----------------- DEFAULT command -----------------
        if (String(command) == "DEF") {
            Serial.println("DEFAULT command received");

            if (Serial.available() >= 2) {
                char address[2];
                Serial.readBytes(address, 2);

                if (String(address) == "01") {
                    Serial.println("DEFAULT INIT_CONFIG command received");
                } else if (String(address) == "02") {
                    Serial.println("DEFAULT GATE_LENGTH command received");
                } else if (String(address) == "03") {
                    Serial.println("DEFAULT RST_DURATION command received");
                } else if (String(address) == "04") {
                    Serial.println("DEFAULT VBIAS1 command received");
                }
            }
        }

        // Clear the rest of the serial buffer, if not already empty.
        while (Serial.available()) {
            Serial.read();
        }
    }
}
