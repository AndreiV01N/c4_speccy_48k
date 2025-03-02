The utilite is intended to correct an interim .tap-file obtained by SAVE in mode "2".

SAVE mode "2" processes standard TAPE-OUT zx-spectrum signal and converts the HIGH/LOW levels sequence to a
stream of data bytes which are going to be sent via serial port to save as TAP file.
The problem is we are unable to predict oncoming block size to fill up leading 2-bytes TAP block's header.
Hence we have to write 2-bytes value of block size at the end of processed block in place of next block's header (and so on).
Finally, at the end of the very last block we reserve 2 additional bytes to write its size.

So, the given tool just shifts all 2-bytes headers in one position to the left and then cuts last 2 bytes.

i.e.
    00 00 <BLOCK_1 DATA> AA AA <BLOCK_2 DATA> BB BB <BLOCK_3 DATA> CC CC
turns into:
    AA AA <BLOCK_1 DATA> BB BB <BLOCK_2 DATA> CC CC <BLOCK_3 DATA>

Usage:
$ gcc ./fix_tap.c -o fix_tap
$ ./fix_tap saved.tap
