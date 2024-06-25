/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"

float accumulatedCurrent = 0;
int measurementCount = 0;

CurrentMeasurement fpga_read_current() {
    if (Serial1.available() < FPGA_DATA_LENGTH) {
        CurrentMeasurement noDeviceMeasurement;
        noDeviceMeasurement.currentInFemtoAmpere = std::nan("1"); // NaN to indicate error
        noDeviceMeasurement.convertedCurrent = std::nan("1");
        noDeviceMeasurement.range = "Error";

        return noDeviceMeasurement;
    }

    while (Serial1.available() >= FPGA_DATA_LENGTH) {
        uint8_t addressByte = Serial1.read();
        if (addressByte != FPGA_CURRENT_ADDRESS) {
            // Clear the remaining bytes in the buffer
            for (int i = 0; i < FPGA_PAYLOAD_LENGTH; i++) {
                if (Serial1.available()) {
                    Serial1.read();
                }
            }
            continue;
        }

        uint8_t dataBytes[FPGA_PAYLOAD_LENGTH];
        for (int i = 0; i < FPGA_PAYLOAD_LENGTH; i++) {
            dataBytes[i] = Serial1.read();
        }

        uint64_t data = 0;
        for (int i = 0; i < FPGA_PAYLOAD_LENGTH; i++) {
            data |= ((uint64_t)dataBytes[i] << (8 * i));
        }

        float readCurrent = fpga_calc_current(data, DEFAULT_LSB, DEFAULT_PERIOD);

        if (FPGA_CALCULATE_AVERAGE) {
            accumulatedCurrent += readCurrent;
            measurementCount++;
        }

        float finalCurrent = FPGA_CALCULATE_AVERAGE ? accumulatedCurrent / measurementCount : readCurrent;
        CurrentMeasurement measurement = fpga_format_current(finalCurrent);

#ifdef DEBUG
        Serial.print("Data: 0x");
        Serial.print(addressByte, HEX);
        for (int i = FPGA_PAYLOAD_LENGTH - 1; i >= 0; i--) {
            Serial.print(dataBytes[i], HEX);
        }
        Serial.print(" - Measured Current: ");
        Serial.print(measurement.convertedCurrent);
        Serial.print(" ");
        Serial.println(measurement.range);
#endif
        return measurement;
    }

    // Return a measurement indicating an error
    CurrentMeasurement errorMeasurement;
    errorMeasurement.currentInFemtoAmpere = std::nan("1"); // NaN to indicate error
    errorMeasurement.convertedCurrent = std::nan("1");
    errorMeasurement.range = "Error";
    return errorMeasurement;
}

TempHumMeasurement fpga_read_temp_humidity() {
    TempHumMeasurement measurement;
    measurement.status = SHT41_ERR_MEASUREMENT;

    if (Serial1.available() < TEMPHUM_DATA_LENGTH) {
        return measurement;
    }

    while (Serial1.available() >= TEMPHUM_DATA_LENGTH) {
        uint8_t addressByte = Serial1.read();
        if (addressByte != FPGA_TEMPHUM_ADDRESS) {
            // Clear the remaining bytes in the buffer
            for (int i = 0; i < TEMPHUM_PAYLOAD_LENGTH; i++) {
                if (Serial1.available()) {
                    Serial1.read();
                }
            }
            continue;
        }

        uint8_t dataBytes[TEMPHUM_PAYLOAD_LENGTH];
        for (int i = 0; i < TEMPHUM_PAYLOAD_LENGTH; i++) {
            dataBytes[i] = Serial1.read();
        }

        // Validate CRC
        if (crc8(dataBytes, 2) != dataBytes[2] || crc8(dataBytes + 3, 2) != dataBytes[5]) {
            measurement.status = SHT41_ERR_CRC;
            return measurement;
        }

        uint16_t rawTemperature = (dataBytes[1] << 8) | dataBytes[0];
        uint16_t rawHumidity = (dataBytes[3] << 8) | dataBytes[2];

        sht41_calculate(rawTemperature, rawHumidity, &measurement);

        return measurement;
    }

    // Return a measurement indicating an error
    measurement.status = SHT41_ERR_MEASUREMENT;
    return measurement;
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

float fpga_calc_current(uint64_t data, float lsb, int period) {
    float charge = data * lsb;
    float attoCurrent = charge / (period * 1e-6);
    float femtoCurrent = attoCurrent * 1e-6;

    return femtoCurrent;
}

CurrentMeasurement fpga_format_current(float currentInFemtoAmperes) {
    CurrentMeasurement measurement;
    measurement.currentInFemtoAmpere = currentInFemtoAmperes;

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

void fpga_send_parameters(uint8_t address, uint32_t value) {
    Serial1.write(address);

    Serial1.write(value & 0xFF); // LSB
    Serial1.write((value >> 8) & 0xFF);
    Serial1.write((value >> 16) & 0xFF);
    Serial1.write((value >> 24) & 0xFF); // MSB
}
