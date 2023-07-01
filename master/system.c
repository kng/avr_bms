#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include "system.h"


//--------Init Ports --------------------
void init_ports(void) {
	// Input/Output Ports initialization

	// Port B initialization
	PORTB= 0xff;
	DDRB= 0;

//	PC0 = green led
//	PC1 = yellow led
//	PC2 = red led
	// Port C initialization
	PORTC= (1<<PC3)|(1<<PC4)|(1<<PC5)|(1<<PC6);
	DDRC= (1<<PC0)|(1<<PC1)|(1<<PC2);

//	PD0 = RXD
//	PD1 = TXD
//	PD2 = R1
//	PD3 = R2
//	PD4 = R3
	// Port D initialization
	PORTD= (1<<PD5)|(1<<PD6)|(1<<PD7);
	DDRD= (1<<PD2)|(1<<PD3)|(1<<PD4);

}


//--------Init Uart interface --------------------
void init_uart(void) {
	#define BAUD 	9600		// 9k6
	#define BAUD_TOL	1		// 1% tolerance
	#include <util/setbaud.h>
	UBRR0H = UBRRH_VALUE;
	UBRR0L = UBRRL_VALUE;
	#if USE_2X
		UCSR0A |= (1 << U2X0);
	#else
		UCSR0A &= ~(1 << U2X0);
	#endif
	UCSR0B = (1<<TXEN0) | (1<<RXEN0);		// enable TX & RX engine
	UCSR0C = (1<<UCSZ00) | (1<<UCSZ01);		// 8-bit data
	rx_pos = 0;
}


void uart_rxen(void){
	rx_buff[RX_SIZE-1] = UDR0;				// clear the receiving buffer
	for(rx_pos=0;rx_pos<RX_SIZE;rx_pos++)	// clear the memory
		rx_buff[rx_pos]=0;
	rx_pos = 0;								// reset the byte counter
	UCSR0B |= (1<<RXCIE0);					// enable rx interrupt
}

void uart_rxdi(void){
	rx_buff[RX_SIZE-1] = UDR0;				// clear the receiving buffer
	UCSR0B &= ~(1<<RXCIE0);					// disable rx interrupt
}


unsigned char parse_volts(void){			// very ugly way of parsing the incoming data
	unsigned char i=0;
	if(rx_pos != 3) return 1;
	if(rx_buff[0] != 'v') return 2;
	if((rx_buff[1] >= '0') & (rx_buff[1] <= '9')) i = (rx_buff[1]-'0') * 16;
	else if((rx_buff[1] >= 'a') & (rx_buff[1] <= 'f')) i = (rx_buff[1]-'a'+10) * 16;
	else return 3;
	if((rx_buff[2] >= '0') & (rx_buff[2] <= '9')) i += (rx_buff[2]-'0');
	else if((rx_buff[2] >= 'a') & (rx_buff[2] <= 'f')) i += (rx_buff[2]-'a'+10);
	else return 4;
	return i;
}


ISR(USART_RX_vect){
	if( rx_pos == RX_SIZE){			// buffer overflow
		UCSR0B &= ~(1<<RXEN0);		// disable rx interrupt
		return;
	}
	rx_buff[rx_pos] = UDR0;			// read out the serial data
	rx_pos++;
}


void uart_send(unsigned char ch) {
	while(!(UCSR0A & (1<<UDRE0)));	// wait for data to be received
	UDR0 = ch; 						// send data
}


void delay_ms(unsigned char i){
  do{
    _delay_ms( 1 );
  }while( --i );
}



void init_timer(void) {
	TCCR1A = 0;							// no output compare and no waveform generation
	//TCCR1B = _BV(CS12) | _BV(CS10);	// ck/1024 @ 16MHZ
	TCCR1B = _BV(CS11) | _BV(CS10);		// ck/64 @ 1MHZ
	TCCR1C = 0;							// no force output compare
	TIMSK1 = _BV(TOIE1);				// timer1 overflow interrupt
}



ISR(TIMER1_OVF_vect){
	static uint8_t scaler=3;		// about 12s
	if(alarm1) --alarm1;
	if(alarm2) --alarm2;
	if(alarm3) --alarm3;
	if (--scaler == 0)
    {
		scaler = 3;
		balance = 1;
    }
}

