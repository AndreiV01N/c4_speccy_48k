## ZX-Spectrum-48K on FPGA ##

**Hardware**

- "RZ-EasyFPGA" development board with Altera EP4CE6/EP4CE10 chip embedded (my PCB has 'OMDAZZ' logo)
- Any VGA display equipped with 15-pin DSUB input
- Standard PS/2 PC keyboard
- USB-Serial adapter (e.g. pl2303 - works great)

**Some notes and details**

- The project is mainly based on https://marsohod.org/forum/proekty-polzovatelej/3137-zx-spectrum-128k-na-osnove-proekta-ewgeny7 and emulates 48k version of ZX Spectrum.
- Considering some limitations of the dev board it had to reduce some functionality: 3-bit color (no BRIGHT signal), built-in BEEPER sound, LOAD/SAVE over RS-232 without HW flow control.
- Main ULA-module has been completely rewritten in Verilog.
- Desired VGA mode can be configured using parameters in __ula.v__ and settings in PLL-module related to 'vga clock_pix' signal frequency.
- ZX screen is tiled by __F9__ key, zoomed by __F10__ key.
- The __HOME__ key triggers CPU RESET.
- RS-232 speed is set to 115200-8N1 which allows to load/save 11025-mono bitrate .wav files in real time:

`$ stty -F /dev/ttyUSB0 115200 raw -echo`

- LOAD/SAVE modes are toggled by __F11__, __F12__ keys resp. followed by indication on 4x7led block. Below is a chart of implemented LOAD/SAVE modes:

Mode | Command sample | ROM modding is required
---- | -------------- | -----------------------
LOAD mode 0 | `$ cat ABC.wav >/dev/ttyUSB0` | No
LOAD mode 1 | `$ cat ABC.tap >/dev/ttyUSB0` | Yes (\*)
SAVE mode 0 | `$ cat /dev/ttyUSB0 > ABC.wav` | No
SAVE mode 1 | `$ cat /dev/ttyUSB0 > ABC.tap` | Yes (\*)
SAVE mode 2 | `$ cat /dev/ttyUSB0 > ABC.tap` | No (\*\*)


(\*) - LOAD-1 and SAVE-1 "turbo" modes require ROM modding (see asm/ dir). Also note that the both "turbo" modes may not work everywhere since tons of ZX-software use its own loaders/savers which expect/produce standard slow signalling on TAPE_IN/TAPE_OUT pins.

(\*\*) - the obtained .tap file has to be processed with 'fix_tap' tool (see c/readme.txt)
