.cseg
.def		reg_workhorse = r16
.def		amplitude = r17				; represents the wave amplitude
.def		io_set = r18
.def		updateflag = r19			; if timerover flow, set the flag to 1 to indicate an amplitude
										; update trigger. 0 indicates no update.
.def 		checkrising = r20			; register to see if amplitude is rising or falling
										; if checkrising = 0, the amplitude is rising, if 1 the amplitude is falling
.def 		potentiometer = r21			; work register for storing ADC from the potentiometer


.org		0x0000
			rjmp setup
.org		0x0020 						; int vector for timer0 overflow
			rjmp ISR_OV0
.org		0x002A
			rjmp ISR_ADC				; int vector for ADC overflow to get the potentiometer value
.org		0x0100

sinevalues:								; sine value look up table

		.db 128,143,159,174,189,202,215,226
		.db	235,243,249,253,255,255,253,249
		.db	243,235,226,215,202,189,174,159
		.db	143,128,112,96,81,66,53,40
		.db	29,20,12,6,2,0,0,2
		.db	6,12,20,29,40,53,66,81
		.db	96,112,127

setup:	
		ldi reg_workhorse, low(RAMEND)	; init the stack
		out SPL, reg_workhorse
		ldi reg_workhorse, high(RAMEND)
		out SPH, reg_workhorse
		ldi reg_workhorse, 0b00000000
		out TCCR0A, reg_workhorse		; init TCCR0A
		ldi reg_workhorse, 0b00000101
		out TCCR0B, reg_workhorse		; init TCCR0B
		ldi reg_workhorse, 0b00000001
		sts TIMSK0, reg_workhorse		; init TIMSK0
		ldi reg_workhorse, 0b01100101	
		sts ADMUX, reg_workhorse		; init ADMUX with ADLAR enabled for left justified
		ldi reg_workhorse, 0b11101111
		sts ADCSRA, reg_workhorse		; init ADCSRA
		ser io_set	
		out DDRD, io_set				; set PORTx as output 
		sei								; enable interrupts



loop:	out PORTD, amplitude			; push out the amplitude every loop
		cpi updateflag, 1				; check if you should update amplitude
		breq sawtooth
	  ; breq triangle
	  ; breq sine
		rjmp loop


sinereset: 								; resets the pointer back to the beginning of sinevalues
		ldi ZH, HIGH(sinevalues<<1)
		ldi ZL, LOW(sinevalues<<1)
		rjmp sine

sine:									; loads the sine wave values from the data memory into amplitude
		lpm amplitude, Z+
		cpi amplitude, 127				; branch to sinereset to if it reaches the end of the 
		breq sinereset
		ldi updateflag, 0				; set updateflag back to 0
		rjmp loop


sawtooth:
		inc amplitude					; increase amplitude, it should go from 0 -> 255 and back to 0 -> 255
		ldi updateflag, 0				; set updateflag back to 0
		rjmp loop

triangle:
		cpi checkrising, 1				; check to see if you should be incrementing or decrementing
		breq triangledec				; if checkrising is 1 it is flagged as decrement, jump to triangeldec instead
		inc amplitude					; increase amplitude
		cpi amplitude, 255				; if amplitude equals 255
		breq setrisingdec				; branch to setrisingdec, this will set the checkrising register to indicate decrement
		ldi updateflag, 0				; set updateflag back to 0
		rjmp loop

triangledec:
		dec amplitude					; decrease amplitude
		cpi amplitude, 0				; if amplitude equals 0
		breq setrisinginc				; branch to setrisinginc, this will set the checkrising register to indicate increment
		ldi updateflag, 0				; set updateflag back to 0
		rjmp loop

setrisingdec:							
		ldi checkrising, 1				; set checkrising to indicate that it is now decrementing
		rjmp loop

setrisinginc:
		ldi checkrising, 0				; set checkrising to indicate that it is now incrementing
		rjmp loop

ISR_OV0:
		ldi updateflag, 1				; trigger the update flag to update next loop
		out TCNT0, potentiometer		; store the value of the ADCH to the TCNT0 to change the frequency 
		reti							; return from interrupt

ISR_ADC:
		lds potentiometer, ADCH
		reti
