/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"

CurrentMeasurement fpga_read() {
    if (Serial1.available() < 4 * 7) {
        // Return a measurement indicating no device available
        CurrentMeasurement noDeviceMeasurement;
        noDeviceMeasurement.currentInFemtoAmpere = std::nan("1"); // NaN to indicate error
        noDeviceMeasurement.convertedCurrent = std::nan("1");
        noDeviceMeasurement.range = "Error";
        return noDeviceMeasurement;
    }

    while (Serial1.available() >= 4 * 7) {
        uint32_t data[7];
        String dataString = "";

        for (int i = 0; i < 7; i++) {
            data[i] = fpga_read_UInt32();
#ifdef DEBUG
            dataString += " Data[" + String(i) + "]: " + String(data[i], HEX);
#endif
        }

        if (data[6] == 0x5A) { // Stop bit
            float readCurrent = fpga_calc_current_ch_inj(data[1], data[2], data[3]);
            CurrentMeasurement measurement = fpga_format_current(readCurrent);
#ifdef DEBUG
            Serial.print(dataString + " - OK");
            Serial.print(" - Measured Current: ");
            Serial.print(measurement.convertedCurrent);
            Serial.print(" ");
            Serial.println(measurement.range);
#endif
            return measurement;
        }
        else {
#ifdef DEBUG
            Serial.println(dataString + " - Error");
#endif
            fpga_attempt_resynchronization();

            // Return a measurement indicating an error
            CurrentMeasurement errorMeasurement;
            errorMeasurement.currentInFemtoAmpere = std::nan("1"); // NaN to indicate error
            errorMeasurement.convertedCurrent = std::nan("1");
            errorMeasurement.range = "Error";
            return errorMeasurement;
        }
    }
}

void fpga_attempt_resynchronization() {
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

void fpga_send_configurations() {
    delay(1000); // Wait for the FPGA to boot up
#ifdef DEBUG
    Serial.println("");
#endif

    fpga_send_parameters(INIT_CONFIG_ADDRESS, INIT_CONFIG);

#ifdef DEBUG
    Serial.println("INIT Config sent");
#endif

    fpga_send_parameters(GATE_LENGTH_ADDRESS, fpga_calculate_gate_len());

#ifdef DEBUG
    Serial.println("GATE sent");
#endif

    delay(20);
    fpga_send_parameters(RST_DURATION_ADDRESS, RST_DURATION);

#ifdef DEBUG
    Serial.println("RST DURATION sent");
#endif

    delay(20);
    fpga_send_parameters(VBIAS1_ADDRESS, fpga_convert_volt_to_DAC(VBIAS1_DEC));
    fpga_send_parameters(VBIAS2_ADDRESS, fpga_convert_volt_to_DAC(VBIAS2_DEC));

#ifdef DEBUG
    delay(20);
#endif

    fpga_send_parameters(VBIAS3_ADDRESS, fpga_convert_volt_to_DAC(VBIAS3_DEC));

#ifdef DEBUG
    Serial.println("VBIAS Sent");
#endif

    fpga_send_parameters(VCM_ADDRESS, fpga_convert_volt_to_DAC(VCM_DEC));

#ifdef DEBUG
    delay(20);
    Serial.println("VCM Sent");
#endif

    fpga_send_parameters(VCM1_ADDRESS, fpga_convert_volt_to_DAC(VCM_DEC));
    fpga_send_parameters(VTH1_ADDRESS, fpga_convert_volt_to_DAC(VTH1_DEC));
    fpga_send_parameters(VTH2_ADDRESS, fpga_convert_volt_to_DAC(VTH2_DEC));
    fpga_send_parameters(VTH3_ADDRESS, fpga_convert_volt_to_DAC(VTH3_DEC));
    fpga_send_parameters(VTH4_ADDRESS, fpga_convert_volt_to_DAC(VTH4_DEC));
    fpga_send_parameters(VTH5_ADDRESS, fpga_convert_volt_to_DAC(VTH5_DEC));
    fpga_send_parameters(VTH6_ADDRESS, fpga_convert_volt_to_DAC(VTH6_DEC));
    fpga_send_parameters(VTH7_ADDRESS, fpga_convert_volt_to_DAC(VTH7_DEC));

#ifdef DEBUG
    Serial.println("VTH Sent");
    sendParam(INIT_CONFIG_ADDRESS, INIT_CONFIG_START);
    Serial.println("Configuration sent");
    Serial.println("");
#endif
}


uint32_t fpga_convert_volt_to_DAC(float voltage) {
    return static_cast<uint32_t>(round((voltage * ADC_RESOLUTION_ACCURATE) / REF_VOLTAGE));
}

uint32_t fpga_calculate_gate_len() {
    uint32_t gate = static_cast<uint32_t>((TW * CLOCK_PERIOD) - 1);
    return gate;
}

float fpga_calc_current_dir_slope(uint32_t data0, uint32_t data4) {
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

float fpga_calc_current_ch_inj(uint32_t data1, uint32_t data2, uint32_t data3) {
    float current_low = static_cast<float>(data1) * Qref1 / TW;
    float current_medium = static_cast<float>(data2) * Qref2 / TW;
    float current_high = static_cast<float>(data3) * Qref3 / TW;

    float current_ch_inj = current_low + current_medium + current_high;
    return current_ch_inj;
}

CurrentMeasurement fpga_format_current(float currentInFemtoAmperes) {
    CurrentMeasurement measurement;
    measurement.currentInFemtoAmpere = currentInFemtoAmperes; // Store the original value in fA

    // Convert the current and determine the range
    if (currentInFemtoAmperes < 1000) {
        measurement.convertedCurrent = currentInFemtoAmperes;
        measurement.range = "fA";
    }
    else if (currentInFemtoAmperes < 1e6) {
        measurement.convertedCurrent = currentInFemtoAmperes / 1000;
        measurement.range = "pA";
    }
    else if (currentInFemtoAmperes < 1e9) {
        measurement.convertedCurrent = currentInFemtoAmperes / 1e6;
        measurement.range = "nA";
    }
    else {
        measurement.convertedCurrent = currentInFemtoAmperes / 1e9;
        measurement.range = "uA";
    }

    return measurement;
}

uint32_t fpga_read_UInt32() {
    uint32_t value = 0;
    value |= ((uint32_t)Serial1.read()) << 0;
    value |= ((uint32_t)Serial1.read()) << 8;
    value |= ((uint32_t)Serial1.read()) << 16;
    value |= ((uint32_t)Serial1.read()) << 24;
    return value;
}

void fpga_send_parameters(uint8_t address, uint32_t value) {
    Serial1.write(address);

    Serial1.write(value & 0xFF); // LSB
    Serial1.write((value >> 8) & 0xFF);
    Serial1.write((value >> 16) & 0xFF);
    Serial1.write((value >> 24) & 0xFF); // MSB
}
