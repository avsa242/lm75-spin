{
    --------------------------------------------
    Filename: sensor.temperature.lm75.i2c.spin
    Author:
    Description:
    Copyright (c) 2019
    Started May 19, 2019
    Updated May 19, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR          = core#SLAVE_ADDR
    SLAVE_RD          = core#SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 400_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

VAR


OBJ

    i2c : "com.i2c"
    core: "core.con.lm75"
    time: "time"

PUB Null
''This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.MSleep (1)
                if i2c.present (SLAVE_WR)                       'Response from device?
                    return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop

    i2c.stop

PUB Configure
' XXX

PUB HystTemp
' XXX

PUB Shutdown(enabled) | tmp
' Shutdown (sleep) sensor
'   Valid values:
'       TRUE (-1 or 1): Shutdown the LM75's internal blocks (low-power, I2C interface active)
'       FALSE (0): Normal operation
'   Any other value polls the chip and returns the current setting
    readRegX(core#CONFIGURATION, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled
        OTHER:
            return (tmp & %1) * TRUE

    tmp &= core#MASK_SHUTDOWN
    tmp := (tmp | enabled) & core#CONFIGURATION_MASK
    writeRegX(core#CONFIGURATION, 1, @tmp)

PUB Temperature | tmp
' Returns temperature, in centi-degrees Celsius
    readRegX(core#TEMPERATURE, 2, @result)
    result.byte[3] := result.byte[0]                            ' Swap byte order
    result.byte[0] := result.byte[1]
    result.byte[1] := result.byte[3]
    result &= core#TEMPERATURE_MASK
    result >>= 7
    ~~result
    result := result * 5

PRI readRegX(reg, nr_bytes, buff_addr) | cmd_packet
' Reads bytes from device register

    cmd_packet.byte[0] := SLAVE_WR
    cmd_packet.byte[1] := reg

    i2c.start
    i2c.wr_block (@cmd_packet, 2)
    i2c.start
    i2c.write (SLAVE_RD)
    i2c.rd_block (buff_addr, nr_bytes, TRUE)
    i2c.stop

PRI writeRegX(reg, nr_bytes, buff_addr) | cmd_packet[2], tmp
' Writes bytes to device register
    cmd_packet.byte[0] := SLAVE_WR
    cmd_packet.byte[1] := reg

    repeat tmp from 0 to nr_bytes-1
        cmd_packet.byte[2 + tmp] := byte[buff_addr][tmp]

    i2c.start
    i2c.wr_block (@cmd_packet, 2 + nr_bytes)
    i2c.stop

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
