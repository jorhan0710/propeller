'' File: HI_LCD_CNT.spin
{{
┌──────────────────────────────────────────┐
│ Hitachi LCD compatible Library  R 1.00   │
│ Author: Frank  Freedman                  │
│ Copyright (c) 2011 Frank Freedman        │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

Hitachi compatible LCD display driver library for restricted I/O availability

This driver was written from scratch for a Powertip PC2400LRF to get a better feel
for the devices,and mostly to see how few I/O lines I could get away with.

The result did not come out to bad.....

CMD_OUT and DAT_OUT work by setting up the uppper bits of the shift register with the
needed control signals for inst/data and read/write. The Shift register then is clocked
four more times with the 4 msbs to get the first nibble to the output then the enable is raised.
This is repeated two times for upper and lower 4  bits. Yes, I could have used a loop here,
but just chose not to as it gives me a bit of consistency with the data function. Other possibe
variants could have included additional logic to decode the four upper four s/r bits to into
up to 16 possible functions all then triggered by the EN line. Chose not to for now.
Maybe if I ever need the read-back function.... Of course if I had the I/O lines to spare,
I would not waste the cost of additional board real estate and hardware. This was after all,
written for a restricted I/O bits situation.

In summary:
8 bit parallel direct connect around 11 I/O lines,
4 bit via s/r 5 lines if using I/O pins for R/w* and I*/O.

As it turned out, just 3 lines for the 74xx164 as drawn here

                      +5V
───┐           ┌─────┴─────┐                  ┌──────────
   ├P10───┐─1┤ D1  14 Qa ├3───────────────11┤d4
P  │        └─2┤ D2     Qb ├4───────────────12┤d5
r  ├P11─────8┤ clk    Qc ├5───────────────13┤d6
o  │           │        Qd ├6───────────────14┤d7
p  │           │74xx164 Qe ├10───────────────5┤R/w*
   │       +5V │        Qf ├11───────────────4┤RS   Power Tip
c  │          │        Qg ├12                │     PC2004LRF
h  │        └─9┤*Rst 7  Qh ├13                │        or
i  │           └─────┬─────┘                  │     Hitachi Equiv.
p  │                                         │
   ├P12────────────────────────────────────6┤en
───┘                                          └───────────
       All r= 3k9


}}

CON

    _xinfreq = 5_000_000
    _clkmode = xtal1 + pll16x

DTA = 10                    's/r data
CLK = 11                    's/r clock
EN = 12                     'R/I* data/instruction

VAR
    byte  CTRL


PUB init_DISP
dira[CLK]~~                     'set I/O piins up
dira[DTA]~~                     ' note pin assgnmt set in CON segment
dira[EN]~~

'' Used for setting up the LCD display parametes for overall ops. Must be called at least once

waitcnt(cnt + clkfreq/10)     ' delay 100 mS after POR to assure init

CTRL := %00000001           ' clear display and  set ac to 00
CMD_OUT(CTRL)
waitcnt(cnt + clkfreq/100)   ' wait for 10mS

CTRL := %00101000           '  first cmd after POR. function set 4 bit,5x8 1/8DF
CMD_OUT(CTRL)
waitcnt(cnt + clkfreq/100)   ' wait for 10mS

CTRL := %00001101           ' set disp on, cursor off, blink
CMD_OUT(CTRL)
waitcnt(cnt + clkfreq/100)   ' wait for 10mS

CTRL := %00000001           ' clear display and  set ac to 00
CMD_OUT(CTRL)
waitcnt(cnt + clkfreq/100)   ' wait for 10mS

CTRL := %00000110           ' set to cursor left disp  static
CMD_OUT(CTRL)
waitcnt(cnt + clkfreq/100)   ' wait for 10mS



PUB CMD_OUT(OUT_VAL)           ' OUT_VAL contains addx or inst
  repeat 2
    outa[DTA] := 0             ' set the bit and clock the s/r
    outa[CLK]~~                '
    outa[CLK]~
    outa[DTA] := 0             '
    outa[CLK]~~                '
    outa[CLK]~
    outa[DTA] := 0             'set 0 for write
    outa[CLK]~~                '
    outa[CLK]~
    outa[DTA] := 0             'set 0 for cmd
    outa[CLK]~~                '
    outa[CLK]~
    repeat 4                   ' use 4 to send  msbs then lsbs to LCD
      if OUT_VAL & %10000000
         outa[DTA]~~           ' set to one if MSB=1
      outa[CLK]~~              ' shift bit into  reg
      outa[CLK]~
      OUT_VAL <<= 1
      outa[DTA]~
    outa[EN]~~
    outa[EN]~
    waitcnt(cnt + clkfreq/1000)   ' wait for 1mS

PUB DAT_OUT(OUT_VAL)
  repeat 2
    outa[DTA] := 0
    outa[CLK]~~
    outa[CLK]~
    outa[DTA] := 0
    outa[CLK]~~
    outa[CLK]~
    outa[DTA] := 1
    outa[CLK]~~
    outa[CLK]~
    outa[DTA] := 0
    outa[CLK]~~
    outa[CLK]~
    repeat 4
      if OUT_VAL & %10000000
         outa[DTA]~~
      outa[CLK]~~
      outa[CLK]~
      OUT_VAL <<= 1
      outa[DTA]~
    outa[EN] := 1
    outa[EN] := 0
    waitcnt(cnt + clkfreq/1000)   ' wait for 1mS


{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
