/**
 * @file serial.cpp
 * @brief Source file for the serial communication functions between MCU and PC.
 * @author Mattia Consani
 * 
 * Contains the implementation of logic to receive data from the computer and
 * parse it to the correct variable.
*/

#include "serialComPC.h"


void serialReadFromPC(struct confParam *conf) {
    String outMessage = "ERROR!";
    if (Serial.available() >= 3) {
        char command[3];
        Serial.readBytes(command, 3);

        // ----------------- SET command -----------------
        if (String(command) == "SET") {
            outMessage = "SET command received -> ";

            if (Serial.available() >= 2) {
                char address[2];
                Serial.readBytes(address, 2);

                if (String(address) == "00") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutA = atof(value);

                        outMessage += "vOutA: " + String(conf->dac.vOutA);
                    }
                } else if (String(address) == "01") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutB = atof(value);

                        outMessage += "vOutB: " + String(conf->dac.vOutB);
                    }
                } else if (String(address) == "02") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutC = atof(value);

                        outMessage += "vOutC: " + String(conf->dac.vOutC);
                    }
                } else if (String(address) == "03") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutD = atof(value);

                        outMessage += "vOutD: " + String(conf->dac.vOutD);
                    }
                } else if (String(address) == "04") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutE = atof(value);

                        outMessage += "vOutE: " + String(conf->dac.vOutE);
                    }
                } else if (String(address) == "05") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutF = atof(value);

                        outMessage += "vOutF: " + String(conf->dac.vOutF);
                    }
                } else if (String(address) == "06") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutG = atof(value);

                        outMessage += "vOutG: " + String(conf->dac.vOutG);
                    }
                } else if (String(address) == "07") {
                    if (Serial.available() > 0) {
                        char value[10];
                        Serial.readBytesUntil('\n', value, 10);
                        conf->dac.vOutH = atof(value);

                        outMessage += "vOutH: " + String(conf->dac.vOutH);
                    }
                }
            }
        }

        // ----------------- DEFAULT command -----------------
        if (String(command) == "DEF") {
            outMessage = "DEFAULT command received -> ";

            if (Serial.available() >= 2) {
                char address[2];
                Serial.readBytes(address, 2);

                if (String(address) == "00") {
                    conf->dac.vOutA = DEFAULT_VOUTA;
                    outMessage += "vOutA: " + String(conf->dac.vOutA);
                } else if (String(address) == "01") {
                    conf->dac.vOutB = DEFAULT_VOUTB;
                    outMessage += "vOutB: " + String(conf->dac.vOutB);
                } else if (String(address) == "02") {
                    conf->dac.vOutC = DEFAULT_VOUTC;
                    outMessage += "vOutC: " + String(conf->dac.vOutC);
                } else if (String(address) == "03") {
                    conf->dac.vOutD = DEFAULT_VOUTD;
                    outMessage += "vOutD: " + String(conf->dac.vOutD);
                } else if (String(address) == "04") {
                    conf->dac.vOutE = DEFAULT_VOUTE;
                    outMessage += "vOutE: " + String(conf->dac.vOutE);
                } else if (String(address) == "05") {
                    conf->dac.vOutF = DEFAULT_VOUTF;
                    outMessage += "vOutF: " + String(conf->dac.vOutF);
                } else if (String(address) == "06") {
                    conf->dac.vOutG = DEFAULT_VOUTG;
                    outMessage += "vOutG: " + String(conf->dac.vOutG);
                } else if (String(address) == "07") {
                    conf->dac.vOutH = DEFAULT_VOUTH;
                    outMessage += "vOutH: " + String(conf->dac.vOutH);
                }
            }
        }

        // Print the out message
        Serial.println(outMessage);

        // Clear the rest of the serial buffer, if not already empty.
        while (Serial.available()) {
            Serial.read();
        }
    }
}
