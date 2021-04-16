## Hardware ##

- "RZ-EasyFPGA" dev board with Altera EP4CE6/EP4CE10 chip embedded (mine one has 'OMDAZZ' logo on PCB)
- Any of 1280x1024@60Hz VGA display equipped with 15-pin DSUB input
- Standard PS/2 PC keyboard
- USB-Serial adapter (e.g. pl2303 - works great)

**Some notes and details**

- The project is mainly based on https://marsohod.org/forum/proekty-polzovatelej/3137-zx-spectrum-128k-na-osnove-proekta-ewgeny7 and emulates 48k version of ZX Spectrum.
- Considering some limitations of the dev board it had to reduce some functionality: 3-bit color (no BRIGHT signal), built-in BEEPER sound, LOAD/SAVE over RS-232 w/o flow ctl.
- Main ULA-module was rewritten in Verilog, video-subsystem adapted to the resolution 1280x1024@60 (pixel clock 108MHz).
- RS-232 speed is set to 115200-8N1 which allows to load/save 11025-mono bitrate .wav files in real time:

`$ stty -F /dev/ttyUSB0 115200 raw -echo`
- LOAD/SAVE modes are toggled by F11,F12 keys resp. followed by indication on 4x7led block. Below is a matrix of implamented LOAD/SAVE modes:

Mode | Command sample | ROM modding is required
---- | -------------- | -----------------------
LOAD mode 0 | `$ cat ABC.wav >/dev/ttyUSB0` | No
LOAD mode 1 | `$ cat ABC.tap >/dev/ttyUSB0` | Yes (\*)
SAVE mode 0 | `$ cat /dev/ttyUSB0 > ABC.wav` | No
SAVE mode 1 | `$ cat /dev/ttyUSB0 > ABC.tap` | Yes (\*)
SAVE mode 2 | `$ cat /dev/ttyUSB0 > ABC.tap` | No (\*\*)

(\*) - LOAD and SAVE modes "1" imply ROM modding (see asm/ dir). Also note that the both "turbo" modes may not work anywhere since tons of ZX-software use its own loaders/savers which expect/produce standard slow signalling on TAPE_IN/TAPE_OUT pins.

(\*\*) - the .tap file has to be fixed by 'fix_tap' tool (see c/readme.txt)
