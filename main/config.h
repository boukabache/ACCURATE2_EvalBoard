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
 * 
 * @warning These parameters are not FPGA releted!!! There is no register
 * in the FPGA to set these parameters. Nor the FPGA needs to know about them.
 * The FPGA has a different UART management register!
*/
struct confSerial {
    bool stream;    //!< Stream flag, if true the data is streamed on serial port
    bool rawOutput; //!< Raw output flag, if true the output is raw
    bool log;       //!< Log flag, if true the data is logged on the SD card
};

/**
 * @brief Struct to hold all the configuration parameters.
*/
struct confParam {
    float dac[8];             //!< DAC configuration vector: vOutA:0, vOutB:1, ecc
    struct confACCURATE acc;  //!< ACCURATE configuration struct
    struct confSerial serial; //!< Serial configuration struct
    uint32_t* UUID;           //!< Pointer to 128-bit UUID vector

};

// Global confiuration struct DECLARATION (definition in main.ino)
extern struct confParam conf;



// Default values for the DAC voltage channels, in volts
#define DEFAULT_VOUTA 1.6
#define DEFAULT_VOUTB 1.5
#define DEFAULT_VOUTC 1.55
#define DEFAULT_VOUTD 2.5
#define DEFAULT_VOUTE 1.6
#define DEFAULT_VOUTF 2.5
#define DEFAULT_VOUTG 1.83
#define DEFAULT_VOUTH 1.18

// Default values for the chargeQuantaCPs
#define DEFAULT_CHARGE_QUANTA_CP1 12710  // 000011000110100110
#define DEFAULT_CHARGE_QUANTA_CP2 25420  // 000110001101001100
#define DEFAULT_CHARGE_QUANTA_CP3 101680 // 011000110100110000

// Default times for the charge pumps
#define T_CHARGE 4
#define T_INJECTION 4

/**
 * @brief Default configuration values.
 */
constexpr struct confParam defaultConf = {
    // DAC default values
    {DEFAULT_VOUTA, DEFAULT_VOUTB, DEFAULT_VOUTC, DEFAULT_VOUTD, 
        DEFAULT_VOUTE, DEFAULT_VOUTF, DEFAULT_VOUTG, DEFAULT_VOUTH},
    { // Default confACCURATE values
        {DEFAULT_CHARGE_QUANTA_CP1, DEFAULT_CHARGE_QUANTA_CP2, DEFAULT_CHARGE_QUANTA_CP3}, // chargeQuantaCP
        {0, 0, 0},   // cooldownMinCP
        {0, 0, 0},   // cooldownMaxCP
        0,           // resetOTA
        T_CHARGE,    // tCharge (0 is corrected to 1)
        T_INJECTION, // tInjection (0 is corrected to 1)
        {0, 0, 0},   // disableCP
        0            // singlyCPActivation
    },
    { // Default confSerial values
        true,  // stream
        true,  // rawOutput
        false  // log
    },
    nullptr // UUID pointer
};



// Clock frequency of the ACCURATE frontend
#define ACCURATE_CLK 50E6 // 50 MHz

// SHT41 Settings
#define SHT41_RD_PERIOD 1 // periodic read interval [s]

// ACCURATE Constants
#define DOWNSCALING_FACTOR 10E14
const float Cf = 5e-12 * DOWNSCALING_FACTOR;




struct CurrentMeasurement {
    float currentInFemtoAmpere; // Current in fA
    float convertedCurrent;     // Converted current based on range
    String range;               // String indicating the current range
};


// DAC Settings
// Redundant shit for back compatibility with an old function
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
