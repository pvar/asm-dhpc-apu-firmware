; *****************************************************************************
;
;   Code for microcontroller on audio circuit
;
; *****************************************************************************
;
;   Panos Varelas (12/05/2015)
;
;   deltaHacker magazine [http://deltahacker.gr]
;
; *****************************************************************************




; -----------------------------------------------------------------------------
;   macros
; -----------------------------------------------------------------------------

.include "macros.asm"

; -----------------------------------------------------------------------------
;   constants
; -----------------------------------------------------------------------------

.include "m328Pdef.inc"

.equ cmd_abort	= 200
.equ cmd_ena	= 201
.equ cmd_dis	= 202
.equ cmd_clear	= 203
.equ cmd_tempo	= 204
.equ cmd_notes	= 205
.equ cmd_stop	= 206
.equ cmd_play	= 207

.equ newbyte	= 1							; PB1
.equ byteread	= 2							; PB2

.equ ch1_data = 0x00						; channel 1 data
.equ ch1_phase_delta_l = 0x0100				;
.equ ch1_phase_delta_h = 0x0101				;
.equ ch1_note_ptr_l = 0x0102				;
.equ ch1_note_ptr_h = 0x0103				;
.equ ch1_duration = 0x0104					;
.equ ch1_parameters = 0x0105				;
.equ ch1_volume = 0x0106					;
.equ ch1_status = 0x0107					;
.equ ch1_phase_accum_l = 0x0108				;
.equ ch1_phase_accum_h = 0x0109				;

.equ ch2_data = 0x0a						; channel 2 data
.equ ch2_phase_delta_l = 0x010a				;
.equ ch2_phase_delta_h = 0x010b				;
.equ ch2_note_ptr_l = 0x010c				;
.equ ch2_note_ptr_h = 0x010d				;
.equ ch2_duration = 0x010e					;
.equ ch2_parameters = 0x010f				;
.equ ch2_volume = 0x0110					;
.equ ch2_status = 0x0111					;
.equ ch2_phase_accum_l = 0x0112				;
.equ ch2_phase_accum_h = 0x0113				;

.equ ch3_data = 0x14						; channel 3 data
.equ ch3_phase_delta_l = 0x0114				;
.equ ch3_phase_delta_h = 0x0115				;
.equ ch3_note_ptr_l = 0x0116				;
.equ ch3_note_ptr_h = 0x0117				;
.equ ch3_duration = 0x0118					;
.equ ch3_parameters = 0x0119				;
.equ ch3_volume = 0x011a					;
.equ ch3_status = 0x011b					;
.equ ch3_phase_accum_l = 0x011c				;
.equ ch3_phase_accum_h = 0x011d				;

.equ ch4_data = 0x1e						; channel 4 data
.equ ch4_phase_delta_l = 0x011e				;
.equ ch4_phase_delta_h = 0x011f				;
.equ ch4_note_ptr_l = 0x0120				;
.equ ch4_note_ptr_h = 0x0121				;
.equ ch4_duration = 0x0122					;
.equ ch4_parameters = 0x0123				;
.equ ch4_volume = 0x0124					;
.equ ch4_status = 0x0125					;
.equ ch4_phase_accum_l = 0x0126				;
.equ ch4_phase_accum_h = 0x0127				;

.equ rch1_notes = 0x0131					; 424 Bytes for notes of channel 1
.equ rch2_notes = 0x02D9					; 424 Bytes for notes of channel 2
.equ rch3_notes = 0x0481					; 424 Bytes for notes of channel 3
.equ rch4_notes = 0x0629					; 424 Bytes for notes of channel 4

; about chX_status:
; bit0 -- playing / stopped
; bit1 -- enabled / disabled


; -----------------------------------------------------------------------------
;   registers & variables
; -----------------------------------------------------------------------------

.def channel_data = r23						; points to parameters of a channel (in SRAM)

.def phase_delta_l = r24					; parameters of a channel (loaded from SRAM)
.def phase_delta_h = r25					;
.def phase_accum_l = r2						;
.def phase_accum_h = r3						;
.def note_ptr_l = r4						;
.def note_ptr_h = r5						;
.def duration = r6							;
.def parameters = r7						;
.def volume = r8							;
.def duty_cycle = r15						;
.def status = r16							;

.def lfsr_l = r13							; 16bit register for LFSR (used for noise)
.def lfsr_h = r14							;

.def sample_acc = r9						; sample accumulator
.def rythm = r10							; offset to "durations" table
.def sample = r17							; single sample
.def loop_cnt = r18							; loop counter in play routine

.def tmp1 = r19								; scratch registers
.def tmp2 = r20								;
.def tmp3 = r21								;
.def tmp4 = r22								;


; -----------------------------------------------------------------------------
;   code segment initialization
; -----------------------------------------------------------------------------

.cseg
.org 0
	rjmp mcu_init


; -----------------------------------------------------------------------------
;   microcontroller initialization
; -----------------------------------------------------------------------------

mcu_init:
	ldi tmp1, $08					; set stack pointer High-Byte
	out SPH, tmp1					;
	ldi tmp1, $FF					; set stack pointer Low-Byte
	out SPL, tmp1					;

	; port pins
	clr tmp1						;
	ser tmp2						;
	out DDRD, tmp1					; PORTD: all inputs
	out DDRC, tmp2					; PORTC: all outputs
	out PORTD, tmp1					; PORTD: no pull-up
	out PORTC, tmp1					; PORTC: logic zero
	out DDRB, tmp1					; PORTB: all inputs
	out PORTB, tmp2					; PORTB: pull-up
	sbi DDRB, byteread				; PB2: output
	cbi PORTB, newbyte				; PB1: no pull-up

	; analog to digital converter
	lds tmp1, ADCSRA				; turn off ADC
	cbr tmp1, 128					; set ADEN bit to 0
	sts ADCSRA, tmp1				;
	lds tmp1, ACSR					; turn off and disconnect analog comp from internal v-ref
	sbr tmp1, 128					; set ACD bit to 1
	cbr tmp1, 64					; set ACBG bit to 1
	sts ACSR, tmp1					;

	; watchdog
	lds tmp1, WDTCSR				; stop Watchdog Timer
	andi tmp1, 0b10110111			;
	sts WDTCSR, tmp1				;

	; further power reduction
	ser tmp1						; power down ADC, TWI, UART, SPI and timer circuits
	sts PRR, tmp1					;

	cli								; make sure interrupts are disabled


; -----------------------------------------------------------------------------
;   main program
; -----------------------------------------------------------------------------

	call mem_init					; copy data from flash

	ser tmp1						; activate all channels (default state)
	sts ch1_status, tmp1			;
	sts ch2_status, tmp1			;
	sts ch3_status, tmp1			;
	sts ch4_status, tmp1			;

; -----------------------------------------------------------------------------
main_loop:
	call get_byte

execute_command:
	subi tmp1, 200					; subtract 200 to get offset
	brlo main_loop					; if negative (less than 200): ignore and loop over

	cpi tmp1, 8						; check for invalid command
	brsh main_loop					; if shame or higher than 8: ignore and loop over
	
	ldi ZH, high(jumplist*2)		; get jumplist starting address
	ldi ZL, low(jumplist*2)			;

	lsl tmp1						; multiply offset (table contains words nots bytes)
	clr tmp2

	add ZL, tmp1					; add offset to jumplist pointer
	adc ZH, tmp2					;

	lpm tmp1, Z+					; get address-to-call from jumplist
	lpm tmp2, Z						;
	mov ZL, tmp1					;
	mov ZH, tmp2					;

	icall							; call subroutine specified in jumplist

	rjmp main_loop

; -----------------------------------------------------------------------------
jumplist:
	.dw xabort
	.dw xenable
	.dw xdisable
	.dw xclear
	.dw xtempo
	.dw xnotes
	.dw xstop
	.dw xplay



.include "api.asm"
.include "play.asm"
.include "update.asm"
.include "melody.asm"
.include "memory.asm"	; this must be last
