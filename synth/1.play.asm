; -----------------------------------------------------------------------------
;   play loop -- generate waveform
; -----------------------------------------------------------------------------

play:
	rcall init_music_data

play_loop:

;	COMPUTE 167 SAMPLES (166 * 496 CLOCK CYCLES)
	ldi loop_cnt, 166
sample_loop:
	rcall samples					; 127 clock cycles
	ldi tmp3, 119					; 1 clock cycle
	rcall delay						; (3*120+4)+3=364 clock cycles
	nop								; 1 clock cycle
	dec loop_cnt					; 1 clock cycle
	brne sample_loop				; 2|1 clock cycles
	nop								;   1 clock cycle

;	COMPUTE 1 SAMPLE AND UPDATE CHANNELS 1, 2, and 3 (496 CLOCK CYCLES)
	rcall samples					; 127 clock cycles
	ldi channel_data, ch1_data		; 1 clock cycle
	rcall update					; 98 clock cycles
	ldi channel_data, ch2_data		; 1 clock cycle
	rcall update					; 98 clock cycles
	ldi channel_data, ch3_data		; 1 clock cycle
	rcall update					; 98 clock cycles
	nop								; 1 clock cycle
	ldi tmp3, 21					; 1 clock cycle
	rcall delay						; (3*22+4)+3=70 clock cycles

;	COMPUTE 1 SAMPLE, UPDATE CHANNEL AND CHECK IF IT HAS TO STOP (496 CLOCK CYCLES)
	rcall samples					; 127 clock cycles
	ldi channel_data, ch4_data		; 1 clock cycle
	rcall update					; 98 clock cycles

	sbi PINB, 0						; 2 clock cycles (should get 96Ηz pulse on PB0)
	ldi tmp3, 77					; 1 clock cycle
	rcall delay						; (3*77+4)+3=238 clock cycles

	; check if all channels are done (20 clock cycles)
	clr tmp1						; clear status -- will count stopped channels
	lds status, ch1_status			; get channel 1 status
	sbrs status, 0					; check first bit (check if playing)
	inc tmp1						;
	lds status, ch2_status			; get channel 2 status
	sbrs status, 0					; check first bit (check if playing)
	inc tmp1						;
	lds status, ch3_status			; get channel 3 status
	sbrs status, 0					; check first bit (check if playing)
	inc tmp1						;
	lds status, ch4_status			; get channel 4 status
	sbrs status, 0					; check first bit (check if playing)
	inc tmp1						;
	cpi tmp1, 4						; check if all four channels have stopped
	breq stop_playing				;
	nop								;

	; check if CPU issued a stop command (7 clock cycles)
	in tmp1, PINB					; check for CPU signal
	sbrs tmp1, newbyte				;
	rjmp cpu_stop_end				;
	in tmp1, PIND					; check if received a "stop" command
	cpi tmp1, cmd_stop				;
	brne play_loop					; keep playing
	rjmp stop_playing				; or exit
cpu_stop_end:
	nop								;
	rjmp play_loop					; keep playing

stop_playing:
ret



; -----------------------------------------------------------------------------
;   delay for (3 * tmp3 + 4) cycles
; -----------------------------------------------------------------------------

delay:
	dec tmp3
	brne delay
	nop
	ret



; -----------------------------------------------------------------------------
;   clear all data related to music
; -----------------------------------------------------------------------------

init_music_data:
	ldi tmp3, low(ch1_melody*2)		; initialize note pointers
	ldi tmp4, high(ch1_melody*2)	;
	sts ch1_note_ptr_l, tmp3		;
	sts ch1_note_ptr_h, tmp4		;
	ldi tmp3, low(ch2_melody*2)		;
	ldi tmp4, high(ch2_melody*2)	;
	sts ch2_note_ptr_l, tmp3		;
	sts ch2_note_ptr_h, tmp4		;
	ldi tmp3, low(ch3_melody*2)		;
	ldi tmp4, high(ch3_melody*2)	;
	sts ch3_note_ptr_l, tmp3		;
	sts ch3_note_ptr_h, tmp4		;
	ldi tmp3, low(ch4_melody*2)		;
	ldi tmp4, high(ch4_melody*2)	;
	sts ch4_note_ptr_l, tmp3		;
	sts ch4_note_ptr_h, tmp4		;

	lds status, ch1_status			; mark all channels as playing
	sbr status, 1					; (do not alter enable/disable bit)
	sts ch1_status, status			;
	lds status, ch2_status			;
	sbr status, 1					;
	sts ch2_status, status			;
	lds status, ch3_status			;
	sbr status, 1					;
	sts ch3_status, status			;
	lds status, ch4_status			;
	sbr status, 1					;
	sts ch4_status, status			;

	clr tmp1						; clear all phase accumulators
	sts ch1_phase_accum_l, tmp1		;
	sts ch1_phase_accum_h, tmp1		;
	sts ch2_phase_accum_l, tmp1		;
	sts ch2_phase_accum_h, tmp1		;
	sts ch3_phase_accum_l, tmp1		;
	sts ch3_phase_accum_h, tmp1		;
	sts ch4_phase_accum_l, tmp1		;
	sts ch4_phase_accum_h, tmp1		;

	ldi tmp1, 1						; set pseudo durations
	sts ch1_duration, tmp1			; (force new note on update)
	sts ch2_duration, tmp1			;
	sts ch3_duration, tmp1			;
	sts ch4_duration, tmp1			;

	ldi ZH, high(tempo*2)			; get melody rhythm
	ldi ZL, low(tempo*2)			;
	lpm								;
	mov rythm, r0					;

	ldi channel_data, ch1_data		; update all channels
	rcall update					; (get the first note)
	ldi channel_data, ch2_data		;
	rcall update					;
	ldi channel_data, ch3_data		;
	rcall update					;
	ldi channel_data, ch4_data		;
	rcall update					;

	ret



; -----------------------------------------------------------------------------
;   calculate new sample for each channel (124 clock cycles)
; -----------------------------------------------------------------------------
samples:
	clr sample_acc

;	-----------------------------------
;	CHANNEL 1: SQUARE (31 CLOCK CYCLES)
;	-----------------------------------
	lds tmp1, ch1_phase_accum_l		; load phase_accum
	lds tmp2, ch1_phase_accum_h		;
	lds tmp3, ch1_phase_delta_l		; load phase_delta
	lds tmp4, ch1_phase_delta_h		;
	add tmp1, tmp3					; add phase_delta to phase_accumulator
	adc tmp2, tmp4					;

	brcc no_clr1					;
	clr tmp1						; clear low byte on accumulator overflow (the other is already cleared ;-)
no_clr1:
	sts ch1_phase_accum_l, tmp1		; save phase_accum
	sts ch1_phase_accum_h, tmp2		;

	lds parameters, ch1_parameters	; load extra parameters
	ldi tmp4, 0b10000000			;
	sbrc parameters, 3				; get duty cycle
	ldi tmp4, 0b11000000			;

	cp tmp2, tmp4					; check MSB of phase accumulator
	brcs keep_low1					;
	lds sample, ch1_volume			;
	rjmp end_ch1					;
keep_low1:
	clr sample
	nop
	nop
end_ch1:
	lds status, ch1_status			; check if channel is active or inactive (2nd bit in status)
	sbrc status, 1					; skip if disabled
	add sample_acc, sample 			; add sample to total

;	-----------------------------------
;	CHANNEL 2: SQUARE (31 CLOCK CYCLES)
;	-----------------------------------
	lds tmp1, ch2_phase_accum_l		; load phase_accum
	lds tmp2, ch2_phase_accum_h		;
	lds tmp3, ch2_phase_delta_l		; load phase_delta
	lds tmp4, ch2_phase_delta_h		;
	add tmp1, tmp3					; add phase_delta to phase_accumulator
	adc tmp2, tmp4					;

	brcc no_clr2					;
	clr tmp1						; clear low byte on accumulator overflow (the other is already cleared ;-)
no_clr2:
	sts ch2_phase_accum_l, tmp1		; save phase_accum
	sts ch2_phase_accum_h, tmp2		;

	lds parameters, ch2_parameters	; load extra parameters
	ldi tmp4, 0b10000000			;
	sbrc parameters, 3				; get duty cycle
	ldi tmp4, 0b11000000			;

	cp tmp2, tmp4					; check MSB of phase accumulator
	brcs keep_low2					;
	lds sample, ch1_volume			;
	rjmp end_ch2					;
keep_low2:
	clr sample
	nop
	nop
end_ch2:
	lds status, ch2_status			; check if channel is active or inactive (2nd bit in status)
	sbrc status, 1					; skip if disabled
	add sample_acc, sample 			; add sample to total

;	-------------------------------------
;	CHANNEL 3: TRIANGLE (28 CLOCK CYCLES)
;	-------------------------------------
	lds tmp1, ch3_phase_accum_l		; load phase_accum
	lds tmp2, ch3_phase_accum_h		;
	lds tmp3, ch3_phase_delta_l		; load phase_delta
	lds tmp4, ch3_phase_delta_h		;
	add tmp1, tmp3					; add phase_delta to phase_accumulator
	adc tmp2, tmp4					;

	brcc no_clr3					;
	clr tmp1						; clear low byte on accumulator overflow (the other is already cleared ;-)
no_clr3:
	sts ch3_phase_accum_l, tmp1		; save phase_accum
	sts ch3_phase_accum_h, tmp2		;

	mov sample, tmp2				; get high byte of accumulator
	swap sample						; swap nibbles
	andi sample, 0b00000111			; keep 3LSBs of transposed high nibble
	lsl sample						; shift left
	ldi tmp3, 0b00001110			; prepare mask according to msb of high nibble of high byte of accumulator
	sbrs tmp2, 7					;
	ldi tmp3, 0b00000001			;
	eor sample, tmp3				; exclusive OR with mask to "center" values around 7
end_ch3:
	lds status, ch3_status			; check if channel is active or inactive (2nd bit in status)
	sbrc status, 1					; skip if disabled
	add sample_acc, sample 			; add sample to total

;	----------------------------------
;	CHANNEL 4: NOISE (28 CLOCK CYCLES)
;	----------------------------------
	lds tmp1, ch4_phase_accum_l		; load phase_accum
	lds tmp2, ch4_phase_accum_h		;
	lds tmp3, ch4_phase_delta_l		; load phase_delta
	lds tmp4, ch4_phase_delta_h		;
	add tmp1, tmp3					; add phase_delta to phase_accumulator
	adc tmp2, tmp4					;
noise:
	brcc skip_lfsr					; if accumulator overflows, compute new sample
	ldi tmp3, 2						; prepare LFSR tap
	lsl lfsr_l						; shift LFSR registers
	rol lfsr_h						;
	brvc skip_xor					;
	eor lfsr_l, tmp3				; exclusive OR with tap
skip_xor:
	mov sample, lfsr_l				; get sample from LFSR low byte
	andi sample, 0b00000111			; mask-out all but 3LSBs
	rjmp exit_lfsr
skip_lfsr:
	nop_x4
	nop_x4
exit_lfsr:
	sts ch4_phase_accum_l, tmp1		; save phase_accum
	sts ch4_phase_accum_h, tmp2		;
end_ch4:
	lds status, ch4_status			; check if channel is active or inactive (2nd bit in status)
	sbrc status, 1					; skip if disabled
	add sample_acc, sample 			; add sample to total

;	----------------------------------
	out PORTC, sample_acc			; output sum of samples
	ret
