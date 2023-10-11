#include <stdbool.h>

// IO Settings
#define LED_ALIVE_PIN           13
#define LED_1_PIN               14
#define LED_2_PIN               15
#define LED_3_PIN               16


// DAC Settings
// CONSTANTS                                                            */
#define DAC7578_NCH		        8 // number of channels per DAC. Must not exceed 2^8-1 = 255
#define DAC7578_WRU_CMD	        0b0011  // write + update command
#define DAC7578_RD_CMD	        0b0001		// read channel command 
#define DAC7578_RST_CMD         0b0111 // software reset
#define DAC_ADDRESS_A	        0b1001000
#define DAC_I2C_WR_PCKT_LEN     3 // command, MSB, LSB
#define DAC_I2C_RD_PCKT_LEN     2 // MSB, LSB

#define DAC7578_CONV_VOLT(V)    ( (uint16_t)(4096/3 * V) )

// DACs channels
// DAC a
#define DAC_A	      		    0
#define VCM1_CH 			    0
#define VBIAS1_CH               1
#define VTH1_CH 			    2
#define VTH2_CH 			    3
#define VTH3_CH 			    4
#define VCHARGE1P_CH  		    6
#define VCHARGE1N_CH  		    5
#define VCMD_CH				    7

/* DACs channel default values
 * calculated from decimal value as:
 *		V_HEX = 4096/3 * V_dec
*/
#define VBIAS1_REG			    0x00000889 // 1.6 V --
#define VBIAS2_REG              0x00000D55 // 2.5 V
#define VBIAS3_REG 		 	    0x0000064B // 1.18V
#define VCM_REG 		        0x00000800 // 1.5V
#define VTH1_REG	            0x00000889 // 1.6V
#define VTH2_REG 		        0x00000911 // 1.7V
#define VTH3_REG 			    0x000009C3 // 1.83V
#define VTH4_REG 			    0x00000D55 // 2.5V
#define VCMD_REG       		    0x00000800 // 1.5V
#define VCHARGEP_REG  		    0x00000D55 // 2.5V
#define VCHARGEN_REG  		    0x00000800 // 1.5V

// SHT41 Settings
bool sht41_meas_enable = true;
#define SHT41_ADDR			    0b1000000
#define SHT41_CMD_TEMP_H	    0b11100011 // measurement command for temperature, hold master
#define SHT41_CMD_TEMP_NH	    0b11110011 // measurement command for temperature, no-hold master
#define SHT41_CMD_RH_H		    0b11100101 // measurement command for relative humidity, hold master
#define SHT41_CMD_RH_NH		    0b11110101 // measurement command for relative humidity, no-hold master
#define SHT41_RD_PERIOD		    1 // periodic read interval [s]
