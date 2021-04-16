compile .asm files using:
$ z80asm -v -i ./zx_loader_1.asm -o ./zx_loader_1.bin
$ z80asm -v -i ./zx_loader_2.asm -o ./zx_loader_2.bin
...

put obtained .bin files into appropriate places of original 48k image by:
$ hexedit ./zx_loader_1.bin (then F9 F7 F3:48.bin Ins F2 Ctrl-X)
...

make '48.hex' from resulting '48.bin' to feed it Quartus:
$ srec_cat ./48.bin -Binary -o ./48.hex -Intel

More details can be found in .asm sources..
