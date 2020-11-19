{
    --------------------------------------------
    Filename: sensor.temperature.lm75.i2c.spin
    Author: Jesse Burt
    Description: Driver for the Maxim LM75
        Digital Temperature Sensor
    Copyright (c) 2020
    Started May 19, 2019
    Updated Nov 19, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR            = core#SLAVE_ADDR
    SLAVE_RD            = core#SLAVE_ADDR|1

    DEF_SCL             = 28
    DEF_SDA             = 29
    DEF_HZ              = 100_000
    I2C_MAX_FREQ        = core#I2C_MAX_FREQ

' Overtemperature alarm (OS) output modes
    ALARM_COMP          = 0
    ALARM_INT           = 1

' Overtemperature alarm (OS) output pin active state
    ALARM_ACTIVE_LOW    = 0
    ALARM_ACTIVE_HIGH   = 1

    C                   = 0
    F                   = 1

VAR

    byte _temp_scale

OBJ

    i2c : "com.i2c"
    core: "core.con.lm75"
    time: "time"

PUB Null{}
' This is not a top-level object

PUB Start{}: okay
' Start using "standard" Propeller I2C pins, 100kHz
    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx(SCL_PIN, SDA_PIN, I2C_HZ)
                time.msleep(1)
                if i2c.present(SLAVE_WR)        ' check device bus presence
                    return okay

    return FALSE                                ' something above failed

PUB Stop{}

    i2c.stop{}{}

PUB Defaults{}
' Factory default settings

PUB AlarmPinActive(state): curr_state
' Overtemperature alarm output pin active state
'   Valid values:
'       ALARM_ACTIVE_LOW (0): Pin is active low
'       ALARM_ACITVE_HIGH (1): Pin is active high
'   Any other value polls the chip and returns the current setting
'   NOTE: The OS pin is open-drain, under all conditions, and requires
'       a pull-up resistor to output a high voltage.
    readreg(core#CONFIG, 1, @curr_state)
    case state
        ALARM_ACTIVE_LOW, ALARM_ACTIVE_HIGH:
            state := state << core#OS_POL
        other:
            return ((curr_state >> core#OS_POL) & %1)

    state := ((curr_state & core#OS_POL_MASK) | state) & core#CONFIG_MASK
    writereg(core#CONFIG, 1, @state)

PUB AlarmTriggerThresh(nr_faults): curr_thr
' Set number of faults necessary to assert alarm
'   Valid values:
'       1, 2, 4, 6
'   Any other value polls the chip and returns the current setting
'   NOTE: The faults must occur consecutively (prevents false positives in noisy environments)
    readreg(core#CONFIG, 1, @curr_thr)
    case nr_faults
        1, 2, 4, 6:
            nr_faults := lookdownz(nr_faults: 1, 2, 4, 6)
        other:
            curr_thr := (curr_thr >> core#FAULTQ) & core#FAULTQ_BITS
            return lookupz(curr_thr: 1, 2, 4, 6)

    nr_faults := ((curr_thr & core#FAULTQ_MASK) | nr_faults) & core#CONFIG_MASK
    writereg(core#CONFIG, 1, @nr_faults)

PUB HystTemp
' XXX

PUB IntMode(mode): curr_mode
' Overtemperature alarm output mode
'   Valid values:
'       ALARM_INT (1):  Interrupt mode
'       ALARM_COMP (0): Comparator mode
'   Any other value polls the chip and returns the current setting
    readreg(core#CONFIG, 1, @curr_mode)
    case mode
        ALARM_COMP, ALARM_INT:
            mode := mode << core#COMP_INT
        other:
            return ((curr_mode >> core#COMP_INT) & %1)

    mode := ((curr_mode & core#COMP_INT_MASK) | mode) & core#CONFIG_MASK
    writereg(core#CONFIG, 1, @mode)

PUB Powered(state): curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Current consumption when shutdown is approx 1uA
    readreg(core#CONFIG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) ^ 1
        other:
            return (curr_state & %1) == 1

    state := ((curr_state & core#SHUTDOWN_MASK) | state) & core#CONFIG_MASK
    writereg(core#CONFIG, 1, @state)

PUB TempData{}: temp_raw
' Temperature ADC data
    temp_raw := 0
    readreg(core#TEMP, 2, @temp_raw)

PUB Temperature{}: temp_cal
' Temperature, in hundredths of a degree, in chosen scale
    return calcTemp(tempdata{})

PUB TempScale(scale): curr_scl
' Set temperature scale used by Temperature method
'   Valid values:
'      *C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PRI calcTemp(temp_word): temp_cal | tmp
' Calculate temperature, using temperature word
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp_cal := (temp_word << 16 ~> 23)                              ' Extend the sign bit, then bring it down into the LSBs, keeping the sign bit
    temp_cal := temp_cal * 50                                        ' Each LSB is 0.5deg C, multiply by 5 to get centi-degrees
    case _temp_scale
        C:
            return
        F:
            return ((temp_cal * 90) / 50) + 32_00
        other:
            return FALSE

PRI readReg(reg, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Read nr_bytes from device into ptr_buff
    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg

    i2c.start{}
    i2c.wr_block(@cmd_pkt, 2)
    i2c.start{}
    i2c.write(SLAVE_RD)
    repeat tmp from nr_bytes-1 to 0
        byte[ptr_buff][tmp] := i2c.read(tmp == 0)
    i2c.stop{}

PRI writereg(reg, nr_bytes, ptr_buff) | cmd_pkt[2], tmp
' Writes nr_bytes from ptr_buff to device
    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg

    repeat tmp from 0 to nr_bytes-1
        cmd_pkt.byte[2 + tmp] := byte[ptr_buff][tmp]

    i2c.start{}
    i2c.wr_block (@cmd_pkt, 2 + nr_bytes)
    i2c.stop{}

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
