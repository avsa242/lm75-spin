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
* 1 extra core/cog for the PASM I2C engine (none if the SPIN I2C engine is used)
* sensor.temp_rh.common.spinh (source: spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.temp_rh.common.spin2h (source: p2-spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.13-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.13-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.13-beta) | NuCode      | FTBFS                 |
| P2        | SPIN2    | FlexSpin (5.9.13-beta) | Native code | OK                    |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* None known

