
;**** A P P L I C A T I O N   N O T E   A V R 3 0 5 ************************
;*
;* Title		: Half Duplex Interrupt Driven Software UART
;* Version		: rev. 1.2 (24-04-2002), reset vector added
;*			: rev. 1.1 (27.08.1997)
;* Last updated		: 24-04-2002
;* Target		: AT90Sxxxx (All AVR Device)
;*
;* Support email	: avr@atmel.com
;*
;* Code Size		: 32 Words
;* Low Register Usage	: 0
;* High Register Usage	: 4
;* Interrupt Usage	: None
;*
;* DESCRIPTION
;* This Application note contains a very code efficient software UART.
;* The example program receives one character and echoes it back.
;***************************************************************************



;***************************************************************************
;*
;* "putchar"
;*
;* This subroutine transmits the byte stored in the "Txbyte" register
;* The number of stop bits used is set with the sb constant
;*
;* Number of words	:14 including return
;* Number of cycles	:Depens on bit rate
;* Low registers used	:None
;* High registers used	:2 (bitcnt,Txbyte)
;* Pointers used	:None
;*
;***************************************************************************
.equ		sb	= 1			;Number of stop bits (1, 2, ...)

putchar:
	cli						; disable interrupts
	ldi		bitcnt,9+sb		; 1+8+sb (sb is # of stop bits)
	com		txbyte			; Invert everything
	sec						; Start bit

putchar0:
	brcc	putchar1		; If carry set
	cbi		PORTB,TX		;    send a '0'
	rjmp	putchar2		; else	

putchar1:
	sbi		PORTB,TX		;    send a '1'
	nop

putchar2:
	rcall	UART_delay		; One bit delay
	rcall	UART_delay
	nop
	nop		; fine tuning
	nop

	lsr		txbyte			; Get next bit
	dec		bitcnt			; If not all bit sent
	brne	putchar0		;    send next
							; else
	sei						;  enable interrupts
	ret						; return


;***************************************************************************
;*
;* "getchar"
;*
;* This subroutine receives one byte and returns it in the "Rxbyte" register
;*
;* Number of words	:14 including return
;* Number of cycles	:Depens on when data arrives
;* Low registers used	:None
;* High registers used	:2 (bitcnt,Rxbyte)
;* Pointers used	:None
;*
;***************************************************************************

ext_int:
	push	status
	in		status, SREG
	push 	status
	push	bitcnt
	push	delay

	ldi 	bitcnt,9		;8 data bit + 1 stop bit

ei1:

	rcall	UART_delay		;0.5 bit delay
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

ei2:
	rcall	UART_delay		;1 bit delay
	rcall	UART_delay		
	nop
	nop
	nop
	nop

	clc						;clear carry
	sbic 	PINB,RX			;if RX pin high
	sec						;

	dec 	bitcnt			;If bit is stop bit
	breq 	ei3			;   return
							;else
	ror 	rxbyte			;   shift bit into Rxbyte
	rjmp 	ei2			;   go get next

ei3:
	inc		rxdata			; indicate data is availible

	pop		delay
	pop		bitcnt
	pop		status
	out		SREG, status
	pop		status
	reti


;***************************************************************************
;*
;* "UART_delay"
;*
;* This delay subroutine generates the required delay between the bits when
;* transmitting and receiving bytes. The total execution time is set by the
;* constant "b":
;*
;*	3·b + 7 cycles (including rcall and ret)
;*
;* Number of words	:4 including return
;* Low registers used	:None
;* High registers used	:1 (temp)
;* Pointers used	:None
;*
;***************************************************************************

.equ	b	= 13	;9600 bps @ 1 MHz crystal

UART_delay:
	ldi		delay, b
UART_delay1:
	dec		delay
	brne	UART_delay1
	ret

; 1=134, 2=13 -> 5.27ms
; 1=91,  2=9  -> 2.5ms
; 1=77,  2=9  -> 2.1ms
delay_char:						; delay for retransmission.. 
	ldi		delay2, 9
delay_char1:
	ldi		delay, 77
delay_char2:
	dec		delay
	brne		delay_char2
	dec		delay2
	brne		delay_char1
	ret



puthex:
	push	txbyte		; backup copy
	swap    txbyte		; swap nibbles

	andi    txbyte, 0x0F	; mask out lower nibble
	cpi     txbyte, 10
	brcs    _phe1
	subi    txbyte, -('a' - '0' - 10)
_phe1:
	subi    txbyte, -'0'
	rcall	putchar
	rcall	delay_char

	pop		txbyte			; retrieve backup
	andi    txbyte, 0x0F	; mask out lower nibble
	cpi     txbyte, 10
	brcs    _phe2
	subi    txbyte, -('a' - '0' - 10)
_phe2:
	subi    txbyte, -'0'
	rcall	putchar
	rcall	delay_char
	ret
