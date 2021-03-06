{{┌──────────────────────────────────────────┐
  │ IL3820 ePaper display PASM text driver   │
  │ Author: Chris Gadd                       │
  │ Copyright (c) 2020 Chris Gadd            │
  │ See end of file for terms of use.        │
  └──────────────────────────────────────────┘
  Written for the Parallax 28024 ePaper display

  The display is designed as 128 horizontal pixels x 296 vertical, x coordinate ranges from byte[0] to byte[15] and y coordinate ranges from byte[0] to byte[4720]
    [0:0] is the top left, with x incrementing left-to-right and y incrementing top-to-bottom.  Each byte is written across eight columns, lsb first

  ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬   ┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐ 
  │  0:0 │  0:1 │  0:2 │  0:3 │  0:4 │  0:5 │  0:6 │  0:7 │   │ 15:0 │ 15:1 │ 15:2 │ 15:3 │ 15:4 │ 15:5 │ 15:6 │ 15:7 │ 
  ├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼   ┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤ 
  │ 16:0 │ 16:1 │ 16:2 │ 16:3 │ 16:4 │ 16:5 │ 16:6 │ 16:7 │   │ 31:0 │ 31:1 │ 31:2 │ 31:3 │ 31:4 │ 31:5 │ 31:6 │ 31:7 │ 
  ├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼   ┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤ 
                                                                                                                        
  ├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼   ┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤ 
  │4720:0│4720:1│4720:2│4720:3│4720:4│4720:5│4720:6│4720:7│   │4735:0│4735:1│4735:2│4735:3│4735:4│4735:5│4735:6│4735:7│ 
  └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴   ┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘ 

  This driver treats the display as 296 horizontal x 128 vertical pixels, coordinate 0,0 is in the bottom-left of the display
  Uses the built-in ROM fonts, creating a 4 line x 18 character display

   4-wire interface
  CS   
  BUSY 
  D/C  
  CLK  
  DIN  ──
          D7  D6  D5  D4  D3  D2  D1  D0       BUSY high for ~418ms                 
}}
CON
'Definitions
  WIDTH   = 128 
  HEIGHT  = 296 
  BLACK   = 0
  WHITE   = 1
  UPDT    = 1
  SLP     = 2
  WAKE    = 3

VAR
  long  mailbox
  long  charmap[16]
  byte  bitmap[width * height / 8]
  byte  row_pos, col_pos, color
  byte  cog

PUB null                                                '' Not a top-level object

PUB start(_cs,_mosi,_sck,_dc,_busy,_reset) : okay       '' Start driver
  stop
  mailbox := 0
  mailbox_address := @mailbox
  bitmap_base := @bitmap
  commands_base := @commands
  cs_mask := |< _cs
  mosi_mask := |< _mosi
  sck_mask  := |< _sck
  dc_mask   := |< _dc
  busy_mask := |< _busy
  reset_mask := |< _reset
  _200ms     := clkfreq / 1000 * 200
  okay := cog := cognew(@entry,0) + 1
  waitcnt(clkfreq + cnt)

PUB stop                                                '' Stop driver if it has already been started - frees the cog         
  if cog
    cogstop(cog~ - 1)                                 

PUB clearBitmap                                         
  bytefill(@bitmap,$FF,WIDTH * HEIGHT / 8)

PUB Move(row,col)                                       '' Row 0(bottom) - 3(top) / Col 0(left) - 17(right)
  row_pos := row <# 3
  col_pos := col <# 18

PUB setColor(_color)                                    '' color 0 - black on white / color 1 - white on black
  color := _color ^ 1  

PUB Dec(value) | i, x

  x := value == NEGX                                    'Check for max negative
  if value < 0
    value := ||(value+x)                                'If negative, make positive; adjust for max negative
    Tx("-")                                             'and output sign

  i := 1_000_000_000                                    'Initialize divisor

  repeat 10                                             'Loop for 10 digits
    if value => i                                                               
      Tx(value / i + "0" + x*(i == 1))                  'If non-zero digit, output digit; adjust for max negative
      value //= i                                       'and digit from value
      result~~                                          'flag non-zero found
    elseif result or i == 1
      Tx("0")                                           'If zero digit (or only digit) output it
    i /= 10                                             'Update divisor

PUB Str(strPtr)                                         '' Writes a string of characters into bitmap  
  repeat strsize(strPtr)
    tx(byte[strPtr++])

PUB Tx(char) | address, temp, i, j                      '' Retrieves character from ROM, rotates, and writes into bitmap

  if row_pos > 3 or col_pos > 17
    return false
  longfill(@charmap,0,16)                                                                               
  address := (char & !1) << 6 + $8000                   
  repeat j from 0 to 31
    temp := long[address] >> (char & 1)
    address += 4     
    repeat i from 0 to 30 step 2
      charmap[i / 2] ->= 1
      charmap[i / 2] |= ((temp >> i) & 1) ^ (color & 1)
  repeat i from 0 to 15
    bitmap[row_pos * 4 + col_pos * 256 + i * 16 + 0] := charmap[i] >> 24
    bitmap[row_pos * 4 + col_pos * 256 + i * 16 + 1] := charmap[i] >> 16
    bitmap[row_pos * 4 + col_pos * 256 + i * 16 + 2] := charmap[i] >> 8
    bitmap[row_pos * 4 + col_pos * 256 + i * 16 + 3] := charmap[i] >> 0
  col_pos += 1

PUB updateDisplay | t                                   '' Refresh display with bitmap, one-second timeout
  t := clkfreq + cnt
  repeat while mailbox <> 0
    if cnt - t > 0
      return false
  mailbox := UPDT

PUB sleep | t
  t := clkfreq + cnt
  repeat while mailbox <> 0
    if cnt - t > 0
      return false
  mailbox := SLP

PUB resetDisplay | t
  t := clkfreq + cnt
  repeat while mailbox <> 0
    if cnt - t > 0
      return false
  mailbox := WAKE

DAT                     org
entry
                        or        dira,cs_mask
                        or        dira,mosi_mask
                        or        dira,sck_mask
                        or        dira,dc_mask
                        or        dira,reset_mask
                        or        outa,cs_mask
Reset
                        andn      outa,reset_mask
                        mov       delay_target,_200ms
                        add       delay_target,cnt
                        waitcnt   delay_target,_200ms
                        or        outa,reset_mask
                        waitcnt   delay_target,0
                        mov       command_address,#@c_sw_reset - @commands
                        call      #write_command
                        test      busy_mask,ina               wc
          if_c          jmp       #$-1                        
                        mov       command_address,#@c_driver_output - @commands
                        call      #write_command
                        mov       command_address,#@c_booster_start - @commands
                        call      #write_command
                        mov       command_address,#@c_write_vcom - @commands
                        call      #write_command
                        mov       command_address,#@c_set_dummy_period - @commands
                        call      #write_command
                        mov       command_address,#@c_set_gate_time - @commands
                        call      #write_command
                        mov       command_address,#@c_data_entry_mode - @commands
                        call      #write_command
                        mov       command_address,#@c_write_lut_full - @commands
                        call      #write_command
                        test      busy_mask,ina               wc
          if_c          jmp       #$-1
'' Clear
                        call      #clear_bitmap
                        call      #update_display
                        mov       command_address,#@c_write_lut_part - @commands
                        call      #write_command
                        test      busy_mask,ina               wc
          if_c          jmp       #$-1
'..............................................................................................................
main_loop
                        mov       mail,#0
                        wrlong    mail,mailbox_address
:loop
                        rdlong    mail,mailbox_address        wz
          if_z          jmp       #:loop
                        cmp       mail,#UPDT                  wz
          if_e          call      #update_display
                        cmp       mail,#SLP                   wz
          if_e          jmp       #command_sleep
                        cmp       mail,#WAKE                  wz
          if_e          jmp       #Reset                        
                        jmp       #main_loop
'==============================================================================================================
update_display                                                                 
                        mov       command_address,#@c_set_x_position - @commands
                        call      #write_command
                        mov       command_address,#@c_set_y_position - @commands
                        call      #write_command
                        mov       command_address,#@c_set_x_counter - @commands
                        call      #write_command
                        mov       command_address,#@c_set_y_counter - @commands
                        call      #write_command
                        test      busy_mask,ina               wc
          if_c          jmp       #$-1
'' write RAM
                        andn      outa,cs_mask
                        andn      outa,dc_mask
                        mov       spi_byte,#WRITE_RAM                        
                        call      #write_byte
                        or        outa,dc_mask
                        mov       bitmap_ptr,bitmap_base
                        mov       byte_counter,bitmap_bytes
:loop
                        rdbyte    spi_byte,bitmap_ptr
                        call      #write_byte
                        add       bitmap_ptr,#1
                        djnz      byte_counter,#:loop
                        or        outa,cs_mask
'' update
                        mov       command_address,#@c_display_update_2 - @commands
                        call      #write_command
                        mov       command_address,#@c_master_activation - @commands
                        call      #write_command
                        test      busy_mask,ina               wc
          if_c          jmp       #$-1
update_display_ret      ret
'--------------------------------------------------------------------------------------------------------------
command_sleep
                        mov       command_address,#@c_deep_sleep_mode - @commands
                        call      #write_command
                        jmp       #main_loop                        
'--------------------------------------------------------------------------------------------------------------
clear_bitmap
                        mov       bitmap_ptr,bitmap_base
                        mov       byte_counter,bitmap_bytes
                        shr       byte_counter,#2                               ' clear bitmap as longs
                        neg       t1,#1                                         ' write $FFFF_FFFF to clear
:loop
                        wrlong    t1,bitmap_ptr
                        add       bitmap_ptr,#4
                        djnz      byte_counter,#:loop
clear_bitmap_ret        ret
'--------------------------------------------------------------------------------------------------------------
write_command
                        add       command_address,commands_base
                        rdbyte    byte_counter,command_address
                        andn      outa,cs_mask
                        andn      outa,dc_mask
:loop
                        add       command_address,#1
                        rdbyte    spi_byte,command_address
                        call      #write_byte
                        or        outa,dc_mask
                        djnz      byte_counter,#:loop
                        or        outa,cs_mask
write_command_ret       ret
'..............................................................................................................
write_byte
                        shl       spi_byte,#32-8
                        mov       bit_counter,#8
:loop
                        shl       spi_byte,#1                 wc
                        muxc      outa,mosi_mask
                        or        outa,sck_mask
                        andn      outa,sck_mask
                        djnz      bit_counter,#:loop
write_byte_ret          ret
'--------------------------------------------------------------------------------------------------------------
copy_char
                        mov       char_ptr,char_base
                        mov       byte_counter,#5
:loop
                        rdbyte    bitmap_byte,char_ptr
                        add       char_ptr,#1
                        wrbyte    bitmap_byte,bitmap_ptr
                        add       bitmap_ptr,#1
                        djnz      byte_counter,#:loop
copy_char_ret           ret
'==============================================================================================================
bitmap_base             long      0-0
bitmap_bytes            long      WIDTH / 8 * HEIGHT                           
commands_base           long      0-0
char_base               long      0-0
cs_mask                 long      0-0
mosi_mask               long      0-0
sck_mask                long      0-0
dc_mask                 long      0-0
busy_mask               long      0-0
reset_mask              long      0-0
_200ms                  long      0-0
mailbox_address         long      0-0

mail                    res       1
bitmap_ptr              res       1
bitmap_byte             res       1
char_ptr                res       1
delay_target            res       1
command_address         res       1
spi_byte                res       1
byte_counter            res       1
bit_counter             res       1
t1                      res       1
                        fit
                        
CON     
  DRIVER_OUTPUT           = $01  
  BOOSTER_SOFT_START      = $0C  
' GATE_SCAN_START         = $0F  
  DEEP_SLEEP_MODE         = $10  
  DATA_ENTRY_MODE         = $11  
  SW_RESET                = $12  
' TEMPERATURE_SENSOR      = $1A  
  MASTER_ACTIVATION       = $20  
  DISPLAY_UPDATE_1        = $21  
  DISPLAY_UPDATE_2        = $22  
  WRITE_RAM               = $24  
  WRITE_VCOM_REGISTER     = $2C  
  WRITE_LUT_REGISTER      = $32  
  SET_DUMMY_LINE_PERIOD   = $3A
  SET_GATE_TIME           = $3B
  BORDER_WAVEFORM_CONTROL = $3C
  SET_RAM_X_POSITION      = $44
  SET_RAM_Y_POSITION      = $45
  SET_RAM_X_COUNTER       = $4E
  SET_RAM_Y_COUNTER       = $4F
  TERMINATE_READ_WRITE    = $FF

DAT
commands
c_sw_reset              byte      1,SW_RESET
c_deep_sleep_mode       byte      1,DEEP_SLEEP_MODE,1
c_driver_output         byte      4,DRIVER_OUTPUT, (height -1 & $FF), ((HEIGHT - 1) >> 8 & $FF),0
c_booster_start         byte      4,BOOSTER_SOFT_START,$D7,$D6,$9D
c_write_vcom            byte      2,WRITE_VCOM_REGISTER,$A8
c_set_dummy_period      byte      2,SET_DUMMY_LINE_PERIOD,$1A
c_set_gate_time         byte      2,SET_GATE_TIME,$08
c_data_entry_mode       byte      2,DATA_ENTRY_MODE,%00000_0_11                                                 
c_write_lut_full        byte      31,WRITE_LUT_REGISTER,$02,$02,$01,$11,$12,$12,$22,$22,$66,$69,{
                                                       }$69,$59,$58,$99,$99,$88,$00,$00,$00,$00,{
                                                       }$F8,$B4,$13,$51,$35,$51,$51,$19,$01,$00
c_write_lut_part        byte      31,WRITE_LUT_REGISTER,$10,$18,$18,$08,$18,$18,$08,$00,$00,$00,{ 
                                                       }$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,{
                                                       }$13,$14,$44,$12,$00,$00,$00,$00,$00,$00  
c_set_x_position        byte      3,SET_RAM_X_POSITION,0,15
c_set_y_position        byte      5,SET_RAM_Y_POSITION,0,0,((HEIGHT - 1) & $FF),(((HEIGHT - 1) >> 8) & $FF)
c_set_x_counter         byte      2,SET_RAM_X_COUNTER,0
c_set_y_counter         byte      3,SET_RAM_Y_COUNTER,0,0
c_write_ram             byte      1,WRITE_RAM
c_display_update_2      byte      2,DISPLAY_UPDATE_2,$C4
c_master_activation     byte      1,MASTER_ACTIVATION
c_terminate             byte      1,TERMINATE_READ_WRITE
  
DAT                     
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