# lm75-spin 
-----------

This is a P8X32A/Propeller driver object for the Maxim LM78 Digital Temperature Sensor and Thermal Watchdog (I2C).

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read die temperature
* Set overtemperature (assert) and hysteresis (clear) interrupts
* Set interrupt active high/low, comparator or interrupt mode
* Alternate I2C addresses

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 additional core/cog for the PASM I2C driver

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 5.0.0)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* None known

## TODO

- [x] Implement method to set hysteresis temp
- [x] Implement method to set alarm temp
- [x] Implement reusable conversion method to <-> from parsed temperature to the device's 9-bit register format
- [x] Add support for alternate I2C addresses
- [x] Add support for setting temperature scale
- [x] Port to P2/SPIN2
