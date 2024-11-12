/**
 * @file config.h
 * @brief File containing the configuration parameters for the evaluation board operations.
 * @author Mattia Consani
 */

#ifndef CONFIG_H
#define CONFIG_H


/**
 * @brief Struct to hold the ACCURATE configuration.
*/
struct confACCURATE {
    uint32_t chargeQuantaCP[3]; //!< Charge injected by one activation of the corresponding charge pump, with LSB=39.3390656 atto coulomb
    uint32_t cooldownMinCP[3]; //!< Minimum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles
    uint32_t cooldownMaxCP[3]; //!< Maximum interval between two activation of the corresponding charge pump, in number of charge/discharge cycles
    uint8_t resetOTA; //!< As long as it is one, the switch short circuiting the output to the input of the OTA is closed
    uint8_t tCharge; //!< Time duration in clock cycles for recharge of the charge pump. 0 is automatically corrected to 1
    uint8_t tInjection; //!< Time duration in clock cycles for activation (injection) of the charge pump. 0 is automatically corrected to 1
    uint8_t disableCP[3]; //!< Do not use the corresponding charge pump
    uint8_t singlyCPActivation; //!< If high and multiple charge pumps would activate at the same time, only the largest one activates
};

/**
 * @brief Struct to hold the serial configuration.
*/
struct confSerial {
    bool stream; // Stream flag, if true the data is streamed on serial port
    bool rawOutput; // Raw output flag, if true the output is raw
    bool log; // Log flag, if true the data is logged on the SD card
};

/**
 * @brief Struct to hold all the configuration parameters.
*/
struct confParam {
    float dac[8]; // DAC configuration vector: vOutA:0, vOutB:1, ecc
    struct confACCURATE acc; // ACCURATE configuration struct
    struct confSerial serial; // Serial configuration struct
    uint32_t* UUID; // Pointer to 128-bit UUID vector

};

// Global confiuration struct DECLARATION
extern struct confParam conf;



// Clock frequency of the ACCURATE frontend
#define ACCURATE_CLK 50E6 // 50 MHz

// SHT41 Settings
#define SHT41_RD_PERIOD 1 // periodic read interval [s]

// ACCURATE Constants
#define DOWNSCALING_FACTOR 10E14
const float Cf = 5e-12 * DOWNSCALING_FACTOR;

// Default values for the DAC voltage channels, in volts
#define DEFAULT_VOUTA 1.6
#define DEFAULT_VOUTB 1.5
#define DEFAULT_VOUTC 1.55
#define DEFAULT_VOUTD 2.5
#define DEFAULT_VOUTE 1.6
#define DEFAULT_VOUTF 2.5
#define DEFAULT_VOUTG 1.83
#define DEFAULT_VOUTH 1.18


struct CurrentMeasurement {
    float currentInFemtoAmpere; // Current in fA
    float convertedCurrent;     // Converted current based on range
    String range;               // String indicating the current range
};


// DAC Settings
const float VBIAS1_DEC = 1.6;
const float VBIAS2_DEC = 2.5;
const float VBIAS3_DEC = 1.18;
const float VCM_DEC = 1.5;
const float VTH1_DEC = 1.55;
const float VTH2_DEC = 1.7;
const float VTH3_DEC = 1.83;
const float VTH4_DEC = 2.5;
const float VTH5_DEC = 1.5; // Vcmd
const float VTH6_DEC = 1.5; // Vcharge-
const float VTH7_DEC = 2.5; // Vcharge+

const uint32_t ADC_RESOLUTION_ACCURATE = 4096;
const float REF_VOLTAGE = 3.0;

// ADC Settings
#define CURRENT_MEASUREMENT_DELAY 100 // Delay between current measurements [ms]

#endif // CONFIG_H
