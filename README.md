# lm75-spin 
-----------

This is a P8X32A/Propeller driver object for the Maxim LM75 Digital Temperature Sensor and Thermal Watchdog (I2C).

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at ~30kHz (P1: SPIN I2C), up to 400kHz (P1: PASM I2C, P2)
* Read die temperature
* Set overtemperature (assert) and hysteresis (clear) interrupts
* Set interrupt active high/low, comparator or interrupt mode
* Alternate I2C addresses

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 additional core/cog for the PASM I2C engine (none if SPIN I2C engine is used)

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1 OpenSpin (bytecode): Untested (deprecated)
* P1/SPIN1 FlexSpin (bytecode): OK, tested with 5.9.7-beta
* P1/SPIN1 FlexSpin (native): OK, tested with 5.9.7-beta
* ~~P2/SPIN2 FlexSpin (nu-code): FTBFS, tested with 5.9.7-beta~~
* P2/SPIN2 FlexSpin (native): OK, tested with 5.9.7-beta
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* None known

