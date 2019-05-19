{
    --------------------------------------------
    Filename: core.con.lm75.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2019
    Started May 19, 2019
    Updated May 19, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ        = 400_000                 'Change to your device's maximum bus rate, according to its datasheet
    SLAVE_ADDR          = $48 << 1                'Change to your device's slave address, according to its datasheet
                                                ' (7-bit format)

'' Register definitions
    TEMPERATURE         = $00
    TEMPERATURE_MASK    = $FF80

    CONFIGURATION       = $01
    CONFIGURATION_MASK  = $FF

    T_HYST              = $02
    T_HYST_MASK         = $FF80

    T_OS                = $03
    T_OS_MASK           = $FF80

PUB Null
'' This is not a top-level object
