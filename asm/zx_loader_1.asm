; A:  $00 - header, $FF - data
; IX: memory addr to load
; DE: num of bytes to be loaded
; CF: "LOAD", NCF: "VERIFY"

	ORG	0x0556		; LD-BYTES entry point must have original addr since it's addressed directly by many of 3dp program loaders..
;; LD-BYTES
	INC	D
	EX	AF,AF'		;' preserve entry flags.
	DEC	D
	DI
	LD	A,$0F		; border white, mic off
	OUT	($FE),A
	LD	HL,$053F	; Address: SA/LD-RET
	PUSH	HL		; is saved on stack as terminating routine.

	JP	$386E		; 'turbo'-loading code is placed in 'SPARE' area of std. 48k ROM

	NOP			; 0x0565
	NOP			; 0x0566
	NOP			; 0x0567
	NOP			; 0x0568
	NOP			; 0x0569
	NOP			; 0x056A

;; LD-BREAK
;L056B:	...
