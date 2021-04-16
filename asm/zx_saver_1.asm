; A:  $00 - header, $FF - data
; IX: 1-st byte memory location
; DE: num of bytes to save

	ORG	0x04C2		; SA-BYTES entry point must have original addr since it's addressed directly by many of 3dp program savers..
;; SA-BYTES
	JP	$38E0		; SA-BYTES "turbo" version (3)
	NOP			; 0x04C5 (1)

;L04C6	LD	HL,$1F80	; jump back here if 5F_in[7]=0
;	BIT	7,A
;	JR	Z,L04D0
;	LD	HL,$0C98

;; SA-FLAG
;L04D0:
