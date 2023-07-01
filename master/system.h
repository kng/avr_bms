#ifndef __SYSTEM
#define __SYSTEM


//	PC0 = green led
//	PC1 = yellow led
//	PC2 = red led

//	PD2 = R1
//	PD3 = R2
//	PD4 = R3 (FAN)

//        ********	RELAYS ********
//#define		R1			(PIND&_BV(PD2))
#define 	R1_ON			PORTD |= _BV(PD2)
#define 	R1_OFF			PORTD &= ~_BV(PD2)
//#define		R2			(PIND&_BV(PD3))
#define 	R2_ON			PORTD |= _BV(PD3)
#define 	R2_OFF			PORTD &= ~_BV(PD3)
//#define		R3			(PIND&_BV(PD4))
#define 	R3_ON			PORTD |= _BV(PD4)
#define 	R3_OFF			PORTD &= ~_BV(PD4)

//        ********	LEDS ********
#define 	GREEN_ON		PORTC |= _BV(PC0)
#define 	GREEN_OFF		PORTC &= ~_BV(PC0)
#define 	YELLOW_ON		PORTC |= _BV(PC1)
#define 	YELLOW_OFF		PORTC &= ~_BV(PC1)
#define 	RED_ON			PORTC |= _BV(PC2)
#define 	RED_OFF			PORTC &= ~_BV(PC2)

//        ********	LIMITS ********
#define		V_ALM			0xce	// 205 -> 3.81V  enables alarm output
#define		V_BAL			0xc3	// 195 -> 3.60V  enables balancing based on volts
#define		V_NORM			0xb8	// 184 -> 3.40V  enables balancing based on difference
#define		V_LOW			0x87	// 135 -> 2.49V  critically low voltage
#define		V_ERR			0x9		// ERROR Codes below this value



#define RX_SIZE 8
volatile unsigned char rx_buff[RX_SIZE];
volatile unsigned char rx_pos;

#define CELLS 16
volatile unsigned char battery[CELLS];

volatile unsigned char balance;
volatile unsigned char alarm1;
volatile unsigned char alarm2;
volatile unsigned char alarm3;


void init_ports(void);
void init_timer(void);
void init_uart(void);


void uart_send(unsigned char ch);
void uart_rxdi(void);
void uart_rxen(void);
unsigned char parse_volts(void);
void delay_ms(unsigned char i);


#endif


