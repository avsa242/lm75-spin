# lm75-spin 
---------------

This is a P8X32A/Propeller driver object for the Maxim LM78 Digital Temperature Sensor and Thermal Watchdog (I2C).

## Salient Features

* I2C connection at up to 400kHz
* Reads temperature
* Can shutdown/sleep
* Can set OS (alarm) pin mode and active state

## Requirements

* 1 additional core/cog for the PASM I2C driver

## Limitations

* Driver is in early stages of development and may malfunction or outright fail to build

## TODO

- [ ] Implement method to set hysteresis temp
- [ ] Implement method to set alarm temp
- [ ] Implement reusable conversion method to <-> from parsed temperature to the device's 9-bit register format
