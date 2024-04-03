/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"

float readFPGA() {
    while (Serial1.available() >= 4 * 7) {
        uint32_t data[7];
        String dataString = "";

        for (int i = 0; i < 7; i++) {
            data[i] = readUInt32();
            dataString += " Data[" + String(i) + "]: " + String(data[i], HEX);
        }

        if (data[6] == 0x5A) { // Stop bit
            Serial.print(dataString + " - OK");
            Serial.print(" - Measured Current: ");
            float readCurrent = calculateCurrentChInj(data[1], data[2], data[3]);
            printCurrentInAppropriateUnit(readCurrent);
            return readCurrent;
        }
        else {
            //Serial.println("Error");
            Serial.println(dataString + " - Error");

            attemptResynchronization();
            return std::nan("1");
        }
    }
}

void attemptResynchronization() {
    bool foundMarker = false;
    while (Serial1.available() && !foundMarker) {
        if (Serial1.peek() == 0x5A) {
            if (Serial1.available() >= 4 * 6) {
                foundMarker = true;
                // Discard bytes up to the marker, effectively starting from the next packet in the next loop iteration
                for (int i = 0; i < 4; i++) Serial1.read(); // Discard the bytes of the misaligned 0x5A
            }
            else {
                // Not enough data for a full packet; break to avoid blocking
                break;
            }
        }
        else {
            Serial1.read(); // Discard the current byte and move to the next one
        }
    }
}

void sendConfigurations() {
    delay(5000);
    Serial.println("");
    sendParam(INIT_CONFIG_ADDRESS, INIT_CONFIG);
    Serial.println("INIT Config sent");
    sendParam(GATE_LENGTH_ADDRESS, calculateGateLength());
    Serial.println("GATE sent");
    delay(20);
    sendParam(RST_DURATION_ADDRESS, RST_DURATION);
    Serial.println("RST DURATION sent");
    delay(20);
    sendParam(VBIAS1_ADDRESS, convertVoltageToDAC(VBIAS1_DEC));
    sendParam(VBIAS2_ADDRESS, convertVoltageToDAC(VBIAS2_DEC));
    delay(20);
    sendParam(VBIAS3_ADDRESS, convertVoltageToDAC(VBIAS3_DEC));
    Serial.println("VBIAS Sent");
    sendParam(VCM_ADDRESS, convertVoltageToDAC(VCM_DEC));
    delay(20);
    sendParam(VCM1_ADDRESS, convertVoltageToDAC(VCM_DEC));
    Serial.println("VCM Sent");
    sendParam(VTH1_ADDRESS, convertVoltageToDAC(VTH1_DEC));
    sendParam(VTH2_ADDRESS, convertVoltageToDAC(VTH2_DEC));
    sendParam(VTH3_ADDRESS, convertVoltageToDAC(VTH3_DEC));
    sendParam(VTH4_ADDRESS, convertVoltageToDAC(VTH4_DEC));
    sendParam(VTH5_ADDRESS, convertVoltageToDAC(VTH5_DEC));
    sendParam(VTH6_ADDRESS, convertVoltageToDAC(VTH6_DEC));
    sendParam(VTH7_ADDRESS, convertVoltageToDAC(VTH7_DEC));
    Serial.println("VTH Sent");
    sendParam(INIT_CONFIG_ADDRESS, INIT_CONFIG_START);
    Serial.println("Configuration sent");
    Serial.println("");
}

uint32_t convertVoltageToDAC(float voltage) {
    return static_cast<uint32_t>(round((voltage * ADC_RESOLUTION_ACCURATE) / REF_VOLTAGE));
}

uint32_t calculateGateLength() {
    uint32_t gate = static_cast<uint32_t>((TW * CLOCK_PERIOD) - 1);
    return gate;
}

float calculateCurrentDirSlope(uint32_t data0, uint32_t data4) {
    // Extract the last nibble (4 bits) from data4
    uint32_t lastHexDigitOfData5 = data4 & 0xF;

    // Combine data0 and the last nibble of data4 to form interval1_count
    uint32_t interval1_count = (data0 << 4) | lastHexDigitOfData5;

    float current_dir_slope;
    if (interval1_count == 0) {
        current_dir_slope = 0;
    }
    else {
        current_dir_slope = Cf * VINT1 * 1e8 / interval1_count;
    }

    return current_dir_slope;
}

float calculateCurrentChInj(uint32_t data1, uint32_t data2, uint32_t data3) {
    float current_low = static_cast<float>(data1) * Qref1 / Tw;
    float current_medium = static_cast<float>(data2) * Qref2 / Tw;
    float current_high = static_cast<float>(data3) * Qref3 / Tw;

    float current_ch_inj = current_low + current_medium + current_high;
    return current_ch_inj;
}

void printCurrentInAppropriateUnit(float currentInFemtoAmperes) {
    if (currentInFemtoAmperes < 1000) {
        Serial.print(currentInFemtoAmperes, 3);
        Serial.println(" fA");
    }
    else if (currentInFemtoAmperes < 1e6) {
        Serial.print(currentInFemtoAmperes / 1000, 3);
        Serial.println(" pA");
    }
    else if (currentInFemtoAmperes < 1e9) {
        Serial.print(currentInFemtoAmperes / 1e6, 3);
        Serial.println(" nA");
    }
    else {
        Serial.print(currentInFemtoAmperes / 1e9, 3);
        Serial.println(" uA");
    }
}

uint32_t readUInt32() {
    uint32_t value = 0;
    value |= ((uint32_t)Serial1.read()) << 0;
    value |= ((uint32_t)Serial1.read()) << 8;
    value |= ((uint32_t)Serial1.read()) << 16;
    value |= ((uint32_t)Serial1.read()) << 24;
    return value;
}

void sendParam(uint32_t address, uint32_t value) {
    Serial1.write(address & 0xFF); // LSB
    Serial1.write((address >> 8) & 0xFF);
    Serial1.write((address >> 16) & 0xFF);
    Serial1.write((address >> 24) & 0xFF); // MSB

    Serial1.write(value & 0xFF); // LSB
    Serial1.write((value >> 8) & 0xFF);
    Serial1.write((value >> 16) & 0xFF);
    Serial1.write((value >> 24) & 0xFF); // MSB
}
