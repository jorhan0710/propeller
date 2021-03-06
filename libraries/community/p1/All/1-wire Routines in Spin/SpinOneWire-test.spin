 {{

SpinOneWire-test
----------------

This is a simple example for the SpinOneWire object. Connect up to eight 1-wire
devices to pin 10, a TV output starting at pin 12, and you'll get a real-time
listing of the devices on the bus. If there are any DS18B20 temperature sensors
attached, we'll read their temperature too.

┌───────────────────────────────────┐
│ Copyright (c) 2008 Micah Dowty    │               
│ See end of file for terms of use. │
└───────────────────────────────────┘

}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  MAX_DEVICES = 8
  
OBJ
  debug   : "tv_text"
  ow      : "SpinOneWire"
  f       : "FloatMath"
  fp      : "FloatString"
  
VAR
  long addrs[2 * MAX_DEVICES]
  
PUB start | i, numDevices, addr

  debug.start(12)
  ow.start(10)

  repeat
    numDevices := ow.search(ow#REQUIRE_CRC, MAX_DEVICES, @addrs)

    debug.str(string($01, "── SpinOneWire Test ──", 13, 13, "Devices:"))

    repeat i from 0 to MAX_DEVICES-1
      debug.out(13)
    
      if i => numDevices
        ' No device: Blank line
        repeat 39
          debug.out(" ")

      else
        addr := @addrs + (i << 3)

        ' Display the 64-bit address        

        debug.hex(LONG[addr + 4], 8)
        debug.hex(LONG[addr], 8)
        debug.str(string("  "))

        if BYTE[addr] == ow#FAMILY_DS18B20
          ' It's a DS18B20 temperature sensor. Read it.
          readTemperature(addr)

        else
          ' Nothing else to show...
          debug.str(string(9,9))

PRI readTemperature(addr) | temp, degC, degF
  '' Read the temperature from a DS18B20 sensor, and display it.
  '' Blocks while the conversion is taking place.

  ow.reset
  ow.writeByte(ow#MATCH_ROM)
  ow.writeAddress(addr)

  ow.writeByte(ow#CONVERT_T)

  ' Wait for the conversion
  repeat
    waitcnt(clkfreq/100 + cnt)

    if ow.readBits(1)
      ' Have a reading! Read it from the scratchpad.

      ow.reset
      ow.writeByte(ow#MATCH_ROM)
      ow.writeAddress(addr)

      ow.writeByte(ow#READ_SCRATCHPAD)
      temp := ow.readBits(16)

      ' Convert from fixed point to floating point
      degC := f.FDiv(f.FFloat(temp), 16.0)

      ' Convert celsius to fahrenheit
      degF := f.FAdd(f.FMul(degC, 1.8), 32.0)

      fp.SetPrecision(4)
      debug.str(fp.FloatToString(degF))
      debug.str(string("°F    "))

      return
