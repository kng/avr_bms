/*********************************************
Project : Li monitor master M8
Version : 01
Date    : 2010 08 28
Author  : Daniel Ekman
Comments: Controls the li_monitor balancing slaves


Chip type           : ATmega88P
Program type        : Application
Clock frequency     : 1 MHz
Memory model        : Small
External SRAM size  : 0
Data Stack size     : 1024
*********************************************/
#include <avr/io.h>
#include <avr/pgmspace.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include "system.h"


int main(void) {
	unsigned char i;
	unsigned char min;

	init_ports();
	init_uart();
	init_timer();


	balance=1;
	sei();

	while (1) {


		if(balance){
			GREEN_ON;
//			uart_rxen();					// disable all balancers
			uart_send('D');
			uart_send('-');
			delay_ms(250);					// wait for voltages to settle...
//			uart_rxdi();

			for(i=0;i<CELLS;i++){			// collect all voltages
				uart_rxen();
				uart_send('V');
				uart_send('0'+i);
				delay_ms(CELLS*4+i*7); 		// delay verified on 16 cells
				uart_rxdi();
				battery[i] = parse_volts();
			}

			min=255;
			RED_OFF;
			YELLOW_OFF;
			for(i=0;i<CELLS;i++){
				if((battery[i] > V_ERR) && (battery[i] <= min)){
					min = battery[i];			// determine the lowest
				}
				if(battery[i] > V_ALM){			// detect high voltage
					alarm1 = 75;				// set charging inhibit timeout to 5min
				}
				if((battery[i] < V_LOW) && (battery[i] > V_ERR)){
					YELLOW_ON;
					alarm2 = 225;				// undervoltage timeout 15min
				}
				if(battery[i] < V_ERR){
					RED_ON;
				}
			}

			for(i=0;i<CELLS;i++){				// turn on balancing if the conditions are met
				if(((battery[i] > min + 4) && (battery[i] > V_NORM)) || (battery[i] > V_BAL)){
					uart_send('E');
					uart_send('0'+i);
					delay_ms(20);
					alarm3=15;					// turn on fan for a minute...
				}
			}
			delay_ms(250);						// collect last data.
			balance = 0;						// get ready for the next timer interrupt
			GREEN_OFF;
		}


//				overvoltage alarm
		if(alarm1)	R1_ON;
		else		R1_OFF;

//				low voltage alarm
		if(alarm2)	R2_ON;
		else		R2_OFF;

//				fan on when balancing
		if(alarm3)	R3_ON;
		else		R3_OFF;

  	}
	return 0;
}


