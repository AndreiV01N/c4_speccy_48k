; A:  $00 - header, $FF - data
; IX: 1-st byte memory location
; DE: num of bytes to save

; The code below is placed in 'SPARE' area of original ROM firmware "ZX Spectrum 48K":
	ORG	0x38E0		; 'SPARE' area

	LD	HL,$053F	; return address
	PUSH	HL

	PUSH	AF
	IN	A,($5F)
	AND	$80		; check bit-7 of I/O port 5F
	JR	NZ,SA_BYTES_TURBO
	POP	AF
	JP	$04C6		; port 5F[7] is 0, so jump out to proceed with original SA-BYTES

; the mod writes prepared ".TAP"-sequence to 3F port so that the data will be written to FIFO and then sent via RS232 out..
SA_BYTES_TURBO:			; port 5F[7] is 1, run modified SA-BYTES code ("turbo" version)
	POP	AF
	EX	AF,AF'		; 'save
	INC	DE		; increase length by one (considering header).
	DEC	IX		; decrease start.
	DI			; disable interrupts

	INC	DE		; (temporary, considering parity-byte in whole block size)
	LD	L,E
	CALL	LD_WRITE_BYTE	; send E to port 3F_out
	RET	NC		; SPACE is pressed
	LD	L,D
	CALL	LD_WRITE_BYTE	; send D to port 3F_out
	RET	NC		; SPACE is pressed
	DEC	DE

	LD	C,$0E		; C=$0E, YELLOW, MIC OFF
	EX	AF,AF'		; 'restore
	LD	L,A		; header ($FF or $00) is 1st byte to be saved.
	JR	SA_START	; JUMP forward to mid entry point of loop

; -------------------------
;   During the save loop a parity byte is maintained in H.
;   the save loop begins by testing if reduced length is zero and if so
;   the final parity byte is saved reducing count to $FFFF.
SA_LOOP:
	LD	A,D		; test if byte counter (DE) has reached $0000
	OR	E		; test against low byte.
	JR	Z,SA_PARITY	; forward to SA-PARITY if DE=0 (very last byte has to be written is 'parity')
	LD	L,(IX+$00)	; load currently addressed byte to L.
SA_LOOP_P:
	LD	A,H		; fetch parity byte.
	XOR	L		; exclusive or with new byte.
SA_START:
	LD	H,A		; put parity byte in H ($00 or $FF on start)
;	SCF			; set carry flag ready to rotate in.
	CALL	LD_WRITE_BYTE
	RET	NC
	DEC	DE		; decrease length
	INC	IX		; increase byte pointer

	LD	A,D		; test if byte counter (DE) has reached $FFFF
	INC	A
	JR	NZ,SA_LOOP	; JUMP to SA-LOOP if more bytes.
	RET

SA_PARITY:
	LD	L,H		; transfer the running parity byte to L and
	JR	SA_LOOP_P	; back to SA-LOOP-P to output that byte before quitting normally.


LD_WRITE_BYTE:			; L contains the byte to write
	LD	A,$7F
	IN	A,($FE)		; read from hFE I/O port
	RRA			; CF <= $FE[0]
	RET	NC		; return if SPACE is pressed
	IN	A,($5F)		; bit-4 is FIFO_out status (0 - empty, 1 - some unsent data)
	AND	$20		; check bit-5 whether FIFO_out is full
	JR	NZ,LD_WRITE_BYTE ; loop back while FIFO_out is full

	LD	A,C
	CPL			; ~A
	LD	C,A
	AND	$07
	OR	$08
	OUT	($FE),A		; change border color to opposite (yellow/blue)

	LD	A,L
	OUT	($3F),A
	LD	A,$10
	OUT	($5F),A		; write $10 to port $5F (bit-4)
	XOR	A		; A <= 0 (resets CF)
	OUT	($5F),A		; write $00 to port $5F

	SCF
	RET			; CF is up
