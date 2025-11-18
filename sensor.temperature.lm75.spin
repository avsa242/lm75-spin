{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.temperature.lm75.spin
    Description:    Driver for the Maxim LM75 Digital Temperature Sensor
    Author:         Jesse Burt
    Started:        May 19, 2019
    Updated:        Nov 18, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.temp.common.spinh"             ' use code common to all temperature sensor drivers

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000
    I2C_ADDR    = 0


    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR | 1


' Overtemperature alarm (OS) output pin active state
    ACTIVE_LO   = 0
    ACTIVE_HI   = 1


VAR

    byte _addr


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef LM75_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.lm75"                     ' HW-specific constants
    time:   "time"                              ' timekeeping methods


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ, I2C_ADDR)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   ADDR_BITS:  I2C alternate address bits (%000..%111)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and lookdown(ADDR_BITS: %000..%111) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            _addr := (ADDR_BITS << 1)
            time.msleep(1)                      ' wait for device startup
            if ( i2c.present(SLAVE_WR | _addr) )' check device bus presence
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    _addr := 0


PUB defaults()
' Factory default settings
    int_latch_ena(FALSE)
    int_set_thresh(80_00)
    int_set_hyst(75_00)
    int_polarity(ACTIVE_LO)


PUB int_polarity(p=-2): r
' Interrupt pin active state (OS)
'   Valid values:
'       ACTIVE_LO (0): Pin is active low
'       ACITVE_HI (1): Pin is active high
'   Any other value polls the chip and returns the current setting
'   NOTE: The OS pin is open-drain, under all conditions, and requires
'       a pull-up resistor to output a high voltage.
    r := readreg(core.CONFIG)
    case p
        ACTIVE_LO, ACTIVE_HI:
            p := p << core.OS_POL
            p := ( (r & core.OS_POL_MASK) | p)
            writereg(core.CONFIG, p)
        other:
            return ( (r >> core.OS_POL) & 1)


PUB int_hyst(): h
' Set interrupt clear threshold (hysteresis), in hundredths of a degree
'   Valid values:
'       if temp_scale() == C: -55_00..125_00 (default: 80_00)
'       if temp_scale() == F: -67_00..257_00 (default: 176_00)
'           (clamped to range)
    h := readreg(core.T_HYST, 2)
    return temp_word2deg(h)


PUB int_set_hyst(h)
' Interrupt clear threshold (hysteresis)
'   Returns: hundredths of a degree
    h := temp2adc(h)
    writereg(core.T_HYST, h, 2)


PUB int_latch_ena(le=-2): r
' Latch interrupts asserted by the sensor
'   Valid values:
'       FALSE (0): Interrupt cleared when temp drops below threshold
'       TRUE (-1 or 1): Interrupt cleared only after reading temperature
'   Any other value polls the chip and returns the current setting
    r := readreg(core.CONFIG)
    case abs(le)
        0, 1:
            le := abs(le) << core.COMP_INT
            le := ( (r & core.COMP_INT_MASK) | le)
            writereg(core.CONFIG, le)
        other:
            return ( (r >> core.COMP_INT) & 1)


PUB int_duration(thr=-2): r
' Number of faults necessary to assert alarm
'   Valid values:
'       1, 2, 4, 6
'   Any other value polls the chip and returns the current setting
'   NOTE: The faults must occur consecutively (prevents false positives in noisy environments)
    r := readreg(core.CONFIG)
    case thr
        1, 2, 4, 6:
            thr := lookdownz(thr: 1, 2, 4, 6)   ' map 1, 2, 4, 6 to bitfield vals 0, 1, 2, 3
            thr := ( (r & core.FAULTQ_MASK) | thr)
            writereg(core.CONFIG, thr)
        other:
            r := (r >> core.FAULTQ) & core.FAULTQ_BITS
            return lookupz(r: 1, 2, 4, 6)       ' map bitfield vals 0, 1, 2, 3 to 1, 2, 4, 6


PUB int_set_thresh(thr)
' Set interrupt threshold (overtemperature), in hundredths of a degree Celsius
'   Valid values:
'       if temp_scale() == C: -55_00..125_00 (default: 80_00)
'       if temp_scale() == F: -67_00..257_00 (default: 176_00)
'           (clamped to range)
    thr := temp2adc(thr)
    writereg(core.T_OS, thr, 2)


PUB int_thresh(): t
' Interrupt threshold (overtemperature)
'   Returns: hundredths of a degree
    t := readreg(core.T_OS, 2)
    return temp_word2deg(t)


PUB powered(p=-2): r
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Current consumption when shutdown is approx 1uA
    r := readreg(core.CONFIG)
    case abs(p)
        0, 1:
            ' bit is actually a "shutdown" bit, so its logic is inverted
            ' (i.e., 0 = powered on, 1 = shutdown), so flip the bit
            p := abs(p) ^ 1
            p := ( (r & core.SHUTDOWN_MASK) | p)
            writereg(core.CONFIG, p)
        other:
            return ( (r & 1) == 0 )


PUB temp_data(): t
' Temperature ADC data
    return readreg(core.TEMP, 2)


PUB temp_word2deg(twd): t
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    t := (twd << 16 ~> 23)                      ' Extend sign, then scale down
    t *= 50                                     ' LSB = 0.5deg C
    case _temp_scale
        C:
            return
        F:
            return ( (t * 90) / 50) + 32_00
        other:
            return FALSE


PRI temp2adc(t): w
' Calculate ADC word, using temperature in hundredths of a degree
'   Returns: ADC word, 16bit, left-justified
    case _temp_scale                            ' convert to Celsius, first
        C:
            t := -55_00 #> t <# 125_00
        F:
            t := ( ( (-67_00 #> t <# 257_00) - 32_00) * 50) / 90
        other:
            return FALSE

    w := (t / 50) << 7
    return ~~w


PRI readreg(reg_nr, len=1): v | cmd_pkt
' Read value from register
    cmd_pkt.byte[0] := SLAVE_WR | _addr
    cmd_pkt.byte[1] := reg_nr

    v := 0
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start()
    i2c.write(SLAVE_RD | _addr)
    i2c.rdblock_msbf(@v, len, i2c.NAK)
    i2c.stop()


PRI writereg(reg_nr, val, len=1) | cmd_pkt
' Write value to register
    cmd_pkt.byte[0] := SLAVE_WR | _addr
    cmd_pkt.byte[1] := reg_nr

    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_msbf(@val, len)
    i2c.stop()


DAT
{
Copyright 2025 Jesse Burt

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

