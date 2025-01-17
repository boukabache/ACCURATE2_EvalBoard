/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"

rawDataFPGA fpgaReadData() {
    // FIXME: use of magic numbers, no bueno
    char chargeRaw[6];
    char cp1CountRaw[4];
    char cp2CountRaw[4];
    char cp3CountRaw[4];
    char cp1StartIntervalRaw[4];
    char cp1EndIntervalRaw[4];
    char temperatureRaw[2];
    char humidityRaw[2];

    struct rawDataFPGA data;
    data.valid = false;

    if (Serial1.find((char) FPGA_CURRENT_ADDRESS)) {
        // Wait for the full payload to be available
        // Read the payload
        Serial1.readBytes(chargeRaw, 6);

        // FIXME: THIS IS WRONG. rawCharge is of signed type inside the vhdl code!! What happens to leading '1's if it is negative?
        // Convert the payload to a 64-bit integer rapresentation
        data.charge = 0;
        for (int i = 0; i < 6; i++) {
            data.charge |= ((uint64_t)chargeRaw[i] << (8 * i));
        }

        Serial1.readBytes(cp1CountRaw, 4);
        data.cp1Count = *(uint32_t*) cp1CountRaw;

        Serial1.readBytes(cp2CountRaw, 4);
        data.cp2Count = *(uint32_t*) cp2CountRaw;

        Serial1.readBytes(cp3CountRaw, 4);
        data.cp3Count = *(uint32_t*) cp3CountRaw;

        Serial1.readBytes(cp1StartIntervalRaw, 4);
        data.cp1StartInterval = *(uint32_t*) cp1StartIntervalRaw;

        Serial1.readBytes(cp1EndIntervalRaw, 4);
        data.cp1EndInterval = *(uint32_t*) cp1EndIntervalRaw;

        Serial1.readBytes(temperatureRaw, 2);
        data.tempSht41 = *(uint16_t*) temperatureRaw;

        Serial1.readBytes(humidityRaw, 2);
        data.humidSht41 = *(uint16_t*) humidityRaw;

        // Clear the rest of the serial buffer, if not already empty.
        // This is necessary to avoid communication artifacts that
        // affect the current measurement, introducing spikes.
        while (Serial1.available()) {
            Serial1.read();
        }

        data.valid = true;
    }

    return data;
}


struct IOstatus getPinStatus() {
    struct IOstatus status;

    // Read button states (HIGH means pressed if using pull-up resistors)
    status.btn1 = digitalRead(PIN_BUTTON);
    status.btn2 = digitalRead(PIN_BUTTON2);
    status.btn3 = digitalRead(PIN_BUTTON3);

    // Assuming HIGH means LED is ON.
    status.led1 = digitalRead(PIN_LED);
    status.led2 = digitalRead(PIN_LED2);
    status.led3 = digitalRead(PIN_LED3);

    // Encode the status as a string
    status.status = "";
    status.status += status.btn1 ? "0" : "1";
    status.status += status.btn2 ? "0" : "1";
    status.status += status.btn3 ? "0" : "1";
    status.status += status.led1 ? "0" : "1";
    status.status += status.led2 ? "0" : "1";
    status.status += status.led3 ? "0" : "1";

    return status;
}


uint32_t fpga_convert_volt_to_DAC(float voltage) {
    return static_cast<uint32_t>(round((voltage * ADC_RESOLUTION_ACCURATE) / REF_VOLTAGE));
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


void sendToFPGA(uint8_t address, uint32_t value) {
    Serial1.write(0xDD); // Start byte

    Serial1.write(address); // 1 byte address

    Serial1.write((value >> 24) & 0xFF); // MSB
    Serial1.write((value >> 16) & 0xFF);
    Serial1.write((value >> 8) & 0xFF);
    Serial1.write(value & 0xFF); // LSB

    // As of now just print to serial in case of error
    fpgaCheckResponse();
}

void fpgaUpdateAllParam() {
    // Disable streaming of data from FPGA, enable (n)ack to rx requests
    sendToFPGA(FPGA_UART_MANAGEMENT_ADDR, 0);

    // Send DAC values
    sendToFPGA(FPGA_DAC_VOUTA_ADDR, fpga_convert_volt_to_DAC(conf.dac[0]));
    sendToFPGA(FPGA_DAC_VOUTB_ADDR, fpga_convert_volt_to_DAC(conf.dac[1]));
    sendToFPGA(FPGA_DAC_VOUTC_ADDR, fpga_convert_volt_to_DAC(conf.dac[2]));
    sendToFPGA(FPGA_DAC_VOUTD_ADDR, fpga_convert_volt_to_DAC(conf.dac[3]));
    sendToFPGA(FPGA_DAC_VOUTE_ADDR, fpga_convert_volt_to_DAC(conf.dac[4]));
    sendToFPGA(FPGA_DAC_VOUTF_ADDR, fpga_convert_volt_to_DAC(conf.dac[5]));
    sendToFPGA(FPGA_DAC_VOUTG_ADDR, fpga_convert_volt_to_DAC(conf.dac[6]));
    sendToFPGA(FPGA_DAC_VOUTH_ADDR, fpga_convert_volt_to_DAC(conf.dac[7]));

    // Send ACCURATE configuration values
    sendToFPGA(FPGA_ACC_CHARGE_QUANTA_CP1_ADDR, conf.acc.chargeQuantaCP[0]);
    sendToFPGA(FPGA_ACC_CHARGE_QUANTA_CP2_ADDR, conf.acc.chargeQuantaCP[1]);
    sendToFPGA(FPGA_ACC_CHARGE_QUANTA_CP3_ADDR, conf.acc.chargeQuantaCP[2]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MIN_CP1_ADDR, conf.acc.cooldownMinCP[0]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MAX_CP1_ADDR, conf.acc.cooldownMaxCP[0]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MIN_CP2_ADDR, conf.acc.cooldownMinCP[1]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MAX_CP2_ADDR, conf.acc.cooldownMaxCP[1]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MIN_CP3_ADDR, conf.acc.cooldownMinCP[2]);
    sendToFPGA(FPGA_ACC_COOLDOWN_MAX_CP3_ADDR, conf.acc.cooldownMaxCP[2]);
    sendToFPGA(FPGA_ACC_RESET_OTA_ADDR, conf.acc.resetOTA);
    sendToFPGA(FPGA_ACC_TCHARGE_ADDR, conf.acc.tCharge);
    sendToFPGA(FPGA_ACC_TINJECTION_ADDR, conf.acc.tInjection);
    sendToFPGA(FPGA_ACC_DISABLE_CP1_ADDR, conf.acc.disableCP[0]);
    sendToFPGA(FPGA_ACC_DISABLE_CP2_ADDR, conf.acc.disableCP[1]);
    sendToFPGA(FPGA_ACC_DISABLE_CP3_ADDR, conf.acc.disableCP[2]);
    sendToFPGA(FPGA_ACC_SINGLY_CP_ACTIVATION_ADDR, conf.acc.singlyCPActivation);

    // Enable back streaming of data from FPGA, disable (n)ack to rx requests
    sendToFPGA(FPGA_UART_MANAGEMENT_ADDR, 1);
}

bool fpgaCheckResponse() {
    // FIXME: use of magic numbers
    char response[31];
    // Read the payload
    Serial1.readBytes(response, 31);

    // Print the response for debugging
    for (int i = 0; i < 31; i++) {
        Serial.print(response[i], HEX);
        Serial.print(" ");
    }

    // Clear the rest of the serial buffer, if not already empty.
    while (Serial1.available()) {
        Serial1.read();
    }

    // Check if the response is ack
    if (response[0] == 0x00) { // TODO: check if is response[0] or response[5]
        return true;
    } else {
        if (response[0] == 0x01) {
            Serial.println("Write error: Generic error");
        } else if (response[0] == 0x02) {
            Serial.println("Write error: Transaction timeout");
        } else if (response[0] == 0x04) {
            Serial.println("Write error: Header error");
        } else if (response[0] == 0x08) {
            Serial.println("Write error: Message invalid");
        } else {
            Serial.println("Write error: Unknown error");
        }
    }
}