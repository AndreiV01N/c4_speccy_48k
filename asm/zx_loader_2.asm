; A:  $00 - header, $FF - data
; IX: location in memory
; DE: num of bytes to be loaded
; CF: "LOAD", NCF: "VERIFY"

; The code below is placed in 'SPARE' area of original ROM firmware "ZX Spectrum 48K":
	ORG	0x386E		; start of 'SPARE' location

	IN	A,($FE)		; here we jumped in from main code branch
	RRA
	AND	$20
	OR	$02
	LD	C,A
	CP	A		; set zero flag

	PUSH	AF
	IN	A,($5F)
	AND	$08		; check bit-3 of I/O port h5F
	JR	NZ,LD_BYTES_TURBO
	POP	AF
	JP	$056B		; port 5F[3] is 0, so jump out to proceed with original LD-BYTES..

; the mod reads ".TAP" bytes sequence from 3F port and loads it into memory
LD_BYTES_TURBO:			; port 5F[3] is 1, run modified LD-BYTES code ("turbo" version)..
	POP	AF
;
; skipping LD-BREAK, LD-START, LD-WAIT, LD-LEADER, LD-SYNC...
;
	LD	B,$02		; Read first 2 bytes (TAP-file block size)
LD_2_BYTES:
	CALL	LD_READ_BYTE	; CF - new data-byte in L, ~CF - SPACE key is pressed
	RET	NC		; SPACE is pressed
	DJNZ	LD_2_BYTES

	LD	A,C
	XOR	$03		; blue-yellow border
	LD	C,A
	LD	H,$00		; init parity byte
	JR	LD_MARKER
LD_LOOP:
	EX	AF,AF'		;' restore
	JR	NZ,LD_FLAG
	JR	NC,LD_VERIFY	; actually the command is "VERIFY" (not "LOAD")
	LD	(IX+$00),L
	JR	LD_NEXT
LD_FLAG:
	RL	C
	XOR	L
	RET	NZ		; block types mismatch (3rd TAP byte vs. A)

	LD	A,C
	RRA
	LD	C,A

	INC	DE
	JR	LD_DEC
LD_VERIFY:
	LD	A,(IX+$00)	; fetch byte from memory to compare
	XOR	L
	RET	NZ
LD_NEXT:
	INC	IX
LD_DEC:
	DEC	DE
	EX	AF,AF'		;' store
LD_MARKER:
	CALL	LD_READ_BYTE	; (instead of original 'LD-8-BITS')
	RET	NC		; SPACE is pressed

	LD	A,H
	XOR	L
	LD	H,A

	LD	A,D
	OR	E
	JR	NZ,LD_LOOP

	LD	A,H		; parity must be zero at the end of block
	CP	$01		; set CF only if parity is zero
	RET			; return to $053F as it's in top of stack
;
; skipping LD-EDGE-2, LD-EDGE-1, LD-DELAY, LD-SAMPLE...
;
LD_READ_BYTE:
	LD	A,$7F
	IN	A,($FE)		; read from hFE I/O port
	RRA			; CF <= $FE[0]
	RET	NC		; return if SPACE is pressed
	IN	A,($5F)		; bit-0 is FIFO_in status (0 - empty, 1 - some unread data)
	RRA			; CF <= $5F[0]
	JR	NC,LD_READ_BYTE	; loop back while FIFO_in is empty

	LD	A,C
	CPL
	LD	C,A
	AND	$07
	OR	$08
	OUT	($FE),A		; change border color to opposite (yellow/blue)

	XOR	A
	INC	A
	OUT	($5F),A		; write $01 to port $5F
	XOR	A		; A <= 0 (resets CF)
	OUT	($5F),A		; write $00 to port $5F
	IN	A,($3F)		; read new TAP data byte from FIFO_in
	LD	L,A		; L <= TAP byte

	SCF
	RET			; CF is up
