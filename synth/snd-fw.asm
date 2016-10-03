; *****************************************************************************
;
;   Code for microcontroller on audio circuit
;
; *****************************************************************************
;
;   Panos Varelas (12/02/2015)
;
;   deltaHacker magazine [http://deltahacker.gr]
;
; *****************************************************************************




; -----------------------------------------------------------------------------
;   macros
; -----------------------------------------------------------------------------

.include "0.macros.asm"

; -----------------------------------------------------------------------------
;   constants
; -----------------------------------------------------------------------------

.include "m88def.inc"

.equ newbyte	= 1							; PB1
.equ byteread	= 2							; PB2

.equ cmd_play	= 210
.equ cmd_stop	= 205

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

; chX_status:bit0	: playing / stopped
; chX_status:bit1	: enabled / disabled

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
	ldi tmp1, $04					; set stack pointer High-Byte
	out SPH, tmp1					;
	ldi tmp1, $FF					; set stack pointer Low-Byte
	out SPL, tmp1					;

	; port pins
	clr tmp1						;
	ser tmp2						;
	out DDRD, tmp1					; PORTD: all inputs
	out PORTD, tmp2					; PORTD: pull-up
	out DDRC, tmp2					; PORTC: all outputs
	out PORTC, tmp1					; PORTC: logic zero

	sbr tmp1, byteread				;
	out DDRB, tmp1					; PORTB: all inputs / byteread output
	com tmp1						;
	out PORTB, tmp2					; PORTB: pull-up on inputs

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

; -----------------------------------------------------------------------------
;   main program loop
; -----------------------------------------------------------------------------

	ser tmp1						; activate
	sts ch1_status, tmp1			;
	sts ch2_status, tmp1			;
	sts ch3_status, tmp1			;
	clr tmp1						; deactivate
	sts ch4_status, tmp1			;

main_loop:
	rcall play
	rjmp main_loop




.include "1.play.asm"
.include "2.update.asm"
.include "3.melody.asm"
