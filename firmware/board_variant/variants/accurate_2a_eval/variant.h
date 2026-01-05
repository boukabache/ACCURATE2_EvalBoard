/*
  Copyright (c) 2014-2015 Arduino LLC.  All right reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#ifndef _VARIANT_ARDUINO_ZERO_
#define _VARIANT_ARDUINO_ZERO_

// The definitions here needs a SAMD core >=1.6.10
#define ARDUINO_SAMD_VARIANT_COMPLIANCE 10610

/*----------------------------------------------------------------------------
 *        Definitions
 *----------------------------------------------------------------------------*/

 /** Frequency of the board main oscillator */
#define VARIANT_MAINOSC		(32768ul)

/** Master clock frequency */
#define VARIANT_MCK			  (48000000ul)

/*----------------------------------------------------------------------------
 *        Headers
 *----------------------------------------------------------------------------*/

#include "WVariant.h"

#ifdef __cplusplus
#include "SERCOM.h"
#include "Uart.h"
#endif // __cplusplus

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

  /*----------------------------------------------------------------------------
   *        Pins
   *----------------------------------------------------------------------------*/

   // Number of pins defined in PinDescription array
#ifdef __cplusplus
  extern "C" unsigned int PINCOUNT_fn();
#endif
#define PINS_COUNT           (PINCOUNT_fn())
#define NUM_DIGITAL_PINS     (20u)
#define NUM_ANALOG_INPUTS    (6u)
#define NUM_ANALOG_OUTPUTS   (1u)
#define analogInputToDigitalPin(p)  ((p < 6u) ? (p) + 14u : -1)

#define digitalPinToPort(P)        ( &(PORT->Group[g_APinDescription[P].ulPort]) )
#define digitalPinToBitMask(P)     ( 1 << g_APinDescription[P].ulPin )
  //#define analogInPinToBit(P)        ( )
#define portOutputRegister(port)   ( &(port->OUT.reg) )
#define portInputRegister(port)    ( &(port->IN.reg) )
#define portModeRegister(port)     ( &(port->DIR.reg) )
#define digitalPinHasPWM(P)        ( g_APinDescription[P].ulPWMChannel != NOT_ON_PWM || g_APinDescription[P].ulTCChannel != NOT_ON_TIMER )

/*
 * digitalPinToTimer(..) is AVR-specific and is not defined for SAMD
 * architecture. If you need to check if a pin supports PWM you must
 * use digitalPinHasPWM(..).
 *
 * https://github.com/arduino/Arduino/issues/1833
 */
 // #define digitalPinToTimer(P)

 // LEDs
#define PIN_LED_28           (28u)
#define PIN_LED_29           (29u)
#define PIN_LED_26           (26u)
#define PIN_LED_31           (31u)
#define PIN_LED              PIN_LED_28
#define PIN_LED2             PIN_LED_29
#define PIN_LED3             PIN_LED_26
#define LED_BUILTIN          PIN_LED_13
#define LED_ALIVE            PIN_LED_31

// Buttons
#define PIN_BUTTON_25        (25u)
#define PIN_BUTTON_27        (27u)
#define PIN_BUTTON_30        (30u)
#define PIN_BUTTON           PIN_BUTTON_27
#define PIN_BUTTON2          PIN_BUTTON_25
#define PIN_BUTTON3          PIN_BUTTON_30

/*
 * USB
 */
#define PIN_USB_HOST_ENABLE (255ul) // Use a value that is out of the range of actual pin numbers
#define PIN_USB_DM          (255ul)
#define PIN_USB_DP          (255ul)


 /*
  * Analog pins
  */
#define PIN_A0               (14ul)
#define PIN_A1               (15ul)
#define PIN_A2               (16ul)
#define PIN_A3               (17ul)
#define PIN_A4               (18ul)
#define PIN_A5               (19ul)
#define PIN_DAC0             (14ul)

  static const uint8_t A0 = PIN_A0;
  static const uint8_t A1 = PIN_A1;
  static const uint8_t A2 = PIN_A2;
  static const uint8_t A3 = PIN_A3;
  static const uint8_t A4 = PIN_A4;
  static const uint8_t A5 = PIN_A5;
  static const uint8_t DAC0 = PIN_DAC0;
#define ADC_RESOLUTION		12

  // Other pins
#define PIN_ATN              (38ul)
  static const uint8_t ATN = PIN_ATN;

  /*
   * Serial interfaces
   */
   // Serial
#define PIN_SERIAL_RX       (24ul)
#define PIN_SERIAL_TX       (23ul)
#define PAD_SERIAL_TX       (SERCOM_RX_PAD_3)
#define PAD_SERIAL_RX       (UART_TX_PAD_2)
   // Serial1
#define PIN_SERIAL1_RX       (38ul)
#define PIN_SERIAL1_TX       (22ul)
#define PAD_SERIAL1_TX       (SERCOM_RX_PAD_1)
#define PAD_SERIAL1_RX       (UART_TX_PAD_0)
   // Serial2
#define PIN_SERIAL2_RX       (0ul)
#define PIN_SERIAL2_TX       (1ul)
#define PAD_SERIAL2_TX       (SERCOM_RX_PAD_3)
#define PAD_SERIAL2_RX       (UART_TX_PAD_2)

/*
 * SPI Interfaces
 */
#define SPI_INTERFACES_COUNT 1

#define PIN_SPI_MISO         (34u)
#define PIN_SPI_MOSI         (35u)
#define PIN_SPI_SCK          (37u)
#define PIN_SPI_SS           (36u)
#define PERIPH_SPI           sercom1
#define PAD_SPI_TX           SPI_PAD_0_SCK_1
#define PAD_SPI_RX           SERCOM_RX_PAD_3

  static const uint8_t SS = PIN_SPI_SS;	// SERCOM1 last PAD is present on A2 but HW SS isn't used. Set here only for reference.
  static const uint8_t MOSI = PIN_SPI_MOSI;
  static const uint8_t MISO = PIN_SPI_MISO;
  static const uint8_t SCK = PIN_SPI_SCK;

  /*
   * Wire Interfaces
   */
#define WIRE_INTERFACES_COUNT 1

#define PIN_WIRE_SDA         (20u)
#define PIN_WIRE_SCL         (21u)
#define PERIPH_WIRE          sercom3
#define WIRE_IT_HANDLER      SERCOM3_Handler

  static const uint8_t SDA = PIN_WIRE_SDA;
  static const uint8_t SCL = PIN_WIRE_SCL;

  /*
   * I2S Interfaces
   */
#define I2S_INTERFACES_COUNT 1

#define I2S_DEVICE          0
#define I2S_CLOCK_GENERATOR 3
#define PIN_I2S_SD          (9u)
#define PIN_I2S_SCK         (1u)
#define PIN_I2S_FS          (0u)

#ifdef __cplusplus
}
#endif

/*----------------------------------------------------------------------------
 *        Arduino objects - C++ only
 *----------------------------------------------------------------------------*/

#ifdef __cplusplus

 /*	=========================
  *	===== SERCOM DEFINITION
  *	=========================
 */
extern SERCOM sercom0;
extern SERCOM sercom1;
extern SERCOM sercom2;
extern SERCOM sercom3;
extern SERCOM sercom4;
extern SERCOM sercom5;

extern Uart Serial;
extern Uart Serial1;
extern Uart Serial2;

#endif

#ifdef __cplusplus
extern "C" {
#endif
  unsigned int PINCOUNT_fn();
#ifdef __cplusplus
}
#endif

// These serial port names are intended to allow libraries and architecture-neutral
// sketches to automatically default to the correct port name for a particular type
// of use.  For example, a GPS module would normally connect to SERIAL_PORT_HARDWARE_OPEN,
// the first hardware serial port whose RX/TX pins are not dedicated to another use.
//
// SERIAL_PORT_MONITOR        Port which normally prints to the Arduino Serial Monitor
//
// SERIAL_PORT_USBVIRTUAL     Port which is USB virtual serial
//
// SERIAL_PORT_LINUXBRIDGE    Port which connects to a Linux system via Bridge library
//
// SERIAL_PORT_HARDWARE       Hardware serial port, physical RX & TX pins.
//
// SERIAL_PORT_HARDWARE_OPEN  Hardware serial ports which are open for use.  Their RX & TX
//                            pins are NOT connected to anything by default.
#define SERIAL_PORT_USBVIRTUAL      Serial
#define SERIAL_PORT_MONITOR         Serial
// Serial has no physical pins broken out, so it's not listed as HARDWARE port
#define SERIAL_PORT_HARDWARE        Serial, Serial1
#define SERIAL_PORT_HARDWARE_OPEN   Serial1

#endif /* _VARIANT_ARDUINO_ZERO_ */

