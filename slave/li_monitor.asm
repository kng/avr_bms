; ********************************************************
;  Single cell distributed balancer.
;  Advanced version with communication protocol.
;
; Code: Daniel Ekman <knegge@gmail.com>
; Date: 2010-08-22
; ********************************************************

.include "tn25def.inc"

;***** Registry definitions
.def	status		= r0
.def	tmp			= r16		; temp. register
.def	bitcnt		= r17		; bit counter
.def	txbyte		= r18		; data to be transmitted
.def	rxbyte		= r19		; received data
.def	delay		= r20		; delay counter
.def	delay2		= r21
.def	rxdata		= r22


;***** Port pins
.equ	TX=PB1		; MISO
.equ	RX=PB2		; INT0/SCK
.equ	DISC=PB3	; CLKI
.equ	VOLT=PB4	; ADC2

.eseg
; nothing
v_cal:
.db		0x00					; calibration byte, acts as a offset (255 = -1 etc)

.dseg
; nothing atm

.cseg
.org		0x0000
	rjmp	reset				;Reset vector

.org		INT0addr
	rjmp	ext_int


.org		INT_VECTORS_SIZE

reset:							;Initialize
	ldi 	tmp, RAMEND
	out 	SPL, tmp			;Setup stack pointer

	; setup watchdog
	ldi		tmp, (1<<WDE)|(1<<WDP3)	; 4s wd timeout, reset
	out		WDTCR, tmp

	; setup port pins
	ldi		tmp, (1<<RX)|(1<<TX) ; RX + TX pin
	out		PORTB, tmp			; Turn on pullups/out high
	ldi		tmp, (1<<TX)|(1<<DISC) ; TX + DISCharge
	out		DDRB, tmp			; set outputs

	; setup ad converter
	ldi		tmp, (1<<REFS1)|(1<<ADLAR)|(1<<MUX1)	; 1.1V ref, left adjust, PB4/ADC2
	out		ADMUX, tmp
	ldi		tmp, (1<<ADEN)|(1<<ADPS2)				; enabled, ck/16
	out		ADCSRA, tmp
	ldi		tmp, 0									; autotrig = off
	out		ADCSRB, tmp
	ldi		tmp, 1<<ADC2D							; disable digital on PB4/ADC2
	out		DIDR0, tmp

	; setup power down registers
	ldi		tmp, (1<<PRTIM0)|(1<<PRTIM1)|(1<<PRUSI)
	out		PRR, tmp

	; setup interrupts
	ldi		tmp, 0				; low level on INT0
	out		MCUCR, tmp
	ldi		tmp, (1<<INT0)		; enable int0 interrupt
	out		GIMSK, tmp

	clr		rxdata
	sei							;Enable interrupts

	rcall	gv_cal
	rjmp	main



.include	"uart.asm"			;All the UART stuff


main:
	wdr							; do watchdog reset in main loop

	tst		rxdata				; check if data is availible
	breq	main				; loop otherwise

	dec		rxdata				; indicate one byte read

	cpi		rxbyte, 'V'			; measure volts
	breq	m_volt
	cpi		rxbyte, 'E'			; enable resistor
	breq	m_enable
	cpi		rxbyte, 'D'			; disable resistor
	breq	m_disable
	cpi		rxbyte, 'R'			; reset all
	breq	m_reset

	mov		txbyte, rxbyte
	rcall	putchar				; catch the rest, resend
	rjmp	main_end

m_volt:
	rcall	getvolt
	rjmp	main_end

m_enable:
	rcall	disc_e
	rjmp	main_end

m_disable:
	rcall	disc_d
	rjmp	main_end

m_reset:
	ldi		txbyte, 'R'
	rcall	putchar
	rcall	delay_char
	rjmp	reset

main_end:
	rjmp main


getvolt:
	tst		rxdata		; test if data is availible
	breq	getvolt		; loop otherwise
	dec		rxdata		; indicate one byte read

	cpi		rxbyte, '0'		; It's calling me
	breq	getvolt_do

	ldi		txbyte, 'V'		; Not to me, retransmit -1
	rcall	putchar
	rcall	delay_char
	mov		txbyte, rxbyte
	dec		txbyte
	rcall	putchar
	rjmp	getvolt_end

getvolt_do:
	ldi		txbyte, 'v'
	rcall	putchar
	rcall	delay_char

	sbi		ADCSRA, ADSC
wadc:
	sbis	ADCSRA, ADIF		; wait until conversion is complete
	rjmp	wadc

	sbi		ADCSRA, ADIF		; clear conversion complete flag
;	in		txbyte, ADCL		; we skipped the low bits of the result, may be needed later! add calibration and scale to 8bit ?

gv_cal:
	sbic	EECR, EEPE			; wait for eventual write...
	rjmp	gv_cal
	ldi		tmp, low(v_cal)
	out		EEARL, tmp			; load the address
	ldi		tmp, high(v_cal)
	out		EEARH, tmp
	sbi		EECR, EERE			; read out a byte
	in		tmp, EEDR
	in		txbyte, ADCH
	sub		txbyte, tmp			; applicate the offset byte
	rcall	puthex

getvolt_end:
	ret



disc_e:
	tst		rxdata
	breq	disc_e			; wait for next byte, WDC reset if it doesent come.
	dec		rxdata

	cpi		rxbyte, '0'		; It's calling me
	breq	disc_e_do

	cpi		rxbyte, '-'		; It's calling all of us
	brne	disc_e_s
	sbi		PORTB, DISC		; activate the discharge transistor
	ldi		txbyte, 'E'
	rcall	putchar			; Resend the command
	rcall	delay_char
	ldi		txbyte, '-'
	rcall	putchar
	rjmp	disc_e_end

disc_e_s:
	ldi		txbyte, 'E'		; Not to me, retransmit n-1
	rcall	putchar
	rcall	delay_char
	mov		txbyte, rxbyte
	dec		txbyte
	rcall	putchar
	rjmp	disc_e_end
disc_e_do:
	sbi		PORTB, DISC		; activate the discharge transistor
	ldi		txbyte, 'e'
	rcall	putchar
disc_e_end:
	ret


disc_d:
	tst		rxdata
	breq	disc_d
	dec		rxdata

	cpi		rxbyte, '0'		; It's calling me
	breq	disc_d_do

	cpi		rxbyte, '-'		; It's calling all of us
	brne	disc_d_s
	cbi		PORTB, DISC
	ldi		txbyte, 'D'
	rcall	putchar
	rcall	delay_char
	ldi		txbyte, '-'
	rcall	putchar
	rjmp	disc_d_end

disc_d_s:
	ldi		txbyte, 'D'		; Not to me, retransmit n-1
	rcall	putchar
	rcall	delay_char
	mov		txbyte, rxbyte
	dec		txbyte
	rcall	putchar
	rjmp	disc_d_end

disc_d_do:
	cbi		PORTB, DISC
	ldi		txbyte, 'd'
	rcall	putchar
disc_d_end:
	ret

