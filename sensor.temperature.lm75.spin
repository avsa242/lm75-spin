{
    --------------------------------------------
    Filename: sensor.temperature.lm75.spin
    Author: Jesse Burt
    Description: Driver for the Maxim LM75 Digital Temperature Sensor
    Copyright (c) 2022
    Started May 19, 2019
    Updated Dec 27, 2022
    See end of file for terms of use.
    --------------------------------------------
}
{ pull in methods common to all Temp drivers }
#include "sensor.temp.common.spinh"

CON

    { I2C }
    SLAVE_WR    = core#SLAVE_ADDR
    SLAVE_RD    = core#SLAVE_ADDR | 1
    DEF_SCL     = 28
    DEF_SDA     = 29
    DEF_HZ      = 100_000

    DEF_ADDR    = %000

' Overtemperature alarm (OS) output pin active state
    ACTIVE_LO   = 0
    ACTIVE_HI   = 1

VAR

    byte _addr

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef LM75_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.lm75"                       ' HW-specific constants
    time: "time"                                ' timekeeping methods

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins, 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom settings
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ and lookdown(ADDR_BITS: %000..%111)
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            _addr := (ADDR_BITS << 1)
            time.msleep(1)                      ' wait for device startup
            if (i2c.present(SLAVE_WR | _addr))  ' check device bus presence
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    _addr := 0

PUB defaults{}
' Factory default settings
    int_latch_ena(FALSE)
    int_set_thresh(80_00)
    int_set_hyst(75_00)
    int_polarity(ACTIVE_LO)

PUB int_polarity(state): curr_state
' Interrupt pin active state (OS)
'   Valid values:
'       ACTIVE_LO (0): Pin is active low
'       ACITVE_HI (1): Pin is active high
'   Any other value polls the chip and returns the current setting
'   NOTE: The OS pin is open-drain, under all conditions, and requires
'       a pull-up resistor to output a high voltage.
    curr_state := 0
    readreg(core#CONFIG, 1, @curr_state)
    case state
        ACTIVE_LO, ACTIVE_HI:
            state := state << core#OS_POL
        other:
            return ((curr_state >> core#OS_POL) & 1)

    state := ((curr_state & core#OS_POL_MASK) | state)
    writereg(core#CONFIG, 1, @state)

PUB int_hyst{}: hyst
' Set interrupt clear threshold (hysteresis), in hundredths of a degree
'   Valid values:
'       if temp_scale() == C: -55_00..125_00 (default: 80_00)
'       if temp_scale() == F: -67_00..257_00 (default: 176_00)
'           (clamped to range)
    hyst := 0
    readreg(core#T_HYST, 2, @hyst)
    return temp_word2deg(hyst)

PUB int_set_hyst(hyst)
' Interrupt clear threshold (hysteresis)
'   Returns: hundredths of a degree
    hyst := temp2adc(hyst)
    writereg(core#T_HYST, 2, @hyst)

PUB int_latch_ena(state): curr_state
' Latch interrupts asserted by the sensor
'   Valid values:
'       FALSE (0): Interrupt cleared when temp drops below threshold
'       TRUE (-1 or 1): Interrupt cleared only after reading temperature
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CONFIG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#COMP_INT
        other:
            return ((curr_state >> core#COMP_INT) & 1)

    state := ((curr_state & core#COMP_INT_MASK) | state)
    writereg(core#CONFIG, 1, @state)

PUB int_duration(thr): curr_thr
' Number of faults necessary to assert alarm
'   Valid values:
'       1, 2, 4, 6
'   Any other value polls the chip and returns the current setting
'   NOTE: The faults must occur consecutively (prevents false positives in noisy environments)
    curr_thr := 0
    readreg(core#CONFIG, 1, @curr_thr)
    case thr
        1, 2, 4, 6:
            thr := lookdownz(thr: 1, 2, 4, 6)
        other:
            curr_thr := (curr_thr >> core#FAULTQ) & core#FAULTQ_BITS
            return lookupz(curr_thr: 1, 2, 4, 6)

    thr := ((curr_thr & core#FAULTQ_MASK) | thr)
    writereg(core#CONFIG, 1, @thr)

PUB int_set_thresh(thr)
' Set interrupt threshold (overtemperature), in hundredths of a degree Celsius
'   Valid values:
'       if temp_scale() == C: -55_00..125_00 (default: 80_00)
'       if temp_scale() == F: -67_00..257_00 (default: 176_00)
'           (clamped to range)
    thr := temp2adc(thr)
    writereg(core#T_OS, 2, @thr)

PUB int_thresh{}: curr_thr
' Interrupt threshold (overtemperature)
'   Returns: hundredths of a degree
    curr_thr := 0
    readreg(core#T_OS, 2, @curr_thr)
    return temp_word2deg(curr_thr)

PUB powered(state): curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Current consumption when shutdown is approx 1uA
    curr_state := 0
    readreg(core#CONFIG, 1, @curr_state)
    case ||(state)
        0, 1:
            ' bit is actually a "shutdown" bit, so its logic is inverted
            ' (i.e., 0 = powered on, 1 = shutdown), so flip the bit
            state := ||(state) ^ 1
        other:
            return (curr_state & 1) == 0

    state := ((curr_state & core#SHUTDOWN_MASK) | state)
    writereg(core#CONFIG, 1, @state)

PUB temp_data{}: temp_raw
' Temperature ADC data
    temp_raw := 0
    readreg(core#TEMP, 2, @temp_raw)

PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp := (temp_word << 16 ~> 23)             ' Extend sign, then scale down
    temp *= 50                                  ' LSB = 0.5deg C
    case _temp_scale
        C:
            return
        F:
            return ((temp * 90) / 50) + 32_00
        other:
            return FALSE

PRI temp2adc(temp_cal): temp_word
' Calculate ADC word, using temperature in hundredths of a degree
'   Returns: ADC word, 16bit, left-justified
    case _temp_scale                            ' convert to Celsius, first
        C:
            temp_cal := -55_00 #> temp_cal <# 125_00
        F:
            temp_cal := (( (-67_00 #> temp_cal <# 257_00) - 32_00) * 50) / 90
        other:
            return FALSE

    temp_word := (temp_cal / 50) << 7
    return ~~temp_word

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from device into ptr_buff
    cmd_pkt.byte[0] := SLAVE_WR | _addr
    cmd_pkt.byte[1] := reg_nr

    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start{}
    i2c.write(SLAVE_RD | _addr)
    i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
    i2c.stop{}

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Writes nr_bytes from ptr_buff to device
    cmd_pkt.byte[0] := SLAVE_WR | _addr
    cmd_pkt.byte[1] := reg_nr

    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_msbf(ptr_buff, nr_bytes)
    i2c.stop{}

DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

