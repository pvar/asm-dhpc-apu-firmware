; -----------------------------------------------------------------------------
;   play loop -- generate waveform
; -----------------------------------------------------------------------------

play:
	rcall init_music_data

play_loop:
;	COMPUTE 166 SAMPLES (166 * 496 CLOCK CYCLES)
	ldi loop_cnt, 166
sample_loop:
	rcall samples					; 135 clock cycles
	ldi tmp3, 116					; 1 clock cycle
	rcall delay						; (3*116+4)+3=355 clock cycles
	nop								; 1 clock cycle
	nop								; 1 clock cycle
	dec loop_cnt					; 1 clock cycle
	brne sample_loop				; 2|1 clock cycles
	nop								;   1 clock cycle
;	COMPUTE 1 SAMPLE AND UPDATE CHANNELS 1, 2, and 3 (496 CLOCK CYCLES)
	rcall samples					; 135 clock cycles
	ldi channel_data, ch1_data		; 1 clock cycle
	rcall update					; 94 clock cycles
	ldi channel_data, ch2_data		; 1 clock cycle
	rcall update					; 94 clock cycles
	ldi channel_data, ch3_data		; 1 clock cycle
	rcall update					; 94 clock cycles
	nop								; 1 clock cycle
	nop								; 1 clock cycle
	ldi tmp3, 22					; 1 clock cycle
	rcall delay						; (3*22+4)+3=73 clock cycles
;	COMPUTE 1 SAMPLE, UPDATE CHANNEL AND CHECK IF SHOULD STOP (496 CLOCK CYCLES)
	rcall samples					; 135 clock cycles
	ldi channel_data, ch4_data		; 1 clock cycle
	rcall update					; 94 clock cycles

	sbi PINB, 0						; 2 clock cycles (should get 96Ηz pulse on PB0)
	ldi tmp3, 74					; 1 clock cycle
	rcall delay						; (3*74+4)+3=229 clock cycles
	; check if all channels are done playing (20 clock cycles)
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
	; check if CPU issued a stop command (12 clock cycles)
	in tmp1, PINB					; check for CPU signal
	sbrs tmp1, newbyte				;
	rjmp cpu_stop_end				;
	sbi PORTB, byteread				; to CPU: started processing
	in tmp1, PIND					; load incoming byte
	cbi PORTB, byteread				; to CPU: done processing (don't keep the CPU waiting!)
	nop								;
	cpi tmp1, cmd_stop				; check if received a "stop" command
	brne play_loop					; keep playing
	rjmp stop_playing				; or exit
cpu_stop_end:
	nop_x4							;
	nop_x2							;
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
;   prepare channels for playback
; -----------------------------------------------------------------------------

init_music_data:
	ldi tmp3, low(rch1_notes)		; initialize note pointers
	ldi tmp4, high(rch1_notes)		;
	sts ch1_note_ptr_l, tmp3		;
	sts ch1_note_ptr_h, tmp4		;
	ldi tmp3, low(rch2_notes)		;
	ldi tmp4, high(rch2_notes)		;
	sts ch2_note_ptr_l, tmp3		;
	sts ch2_note_ptr_h, tmp4		;
	ldi tmp3, low(rch3_notes)		;
	ldi tmp4, high(rch3_notes)		;
	sts ch3_note_ptr_l, tmp3		;
	sts ch3_note_ptr_h, tmp4		;
	ldi tmp3, low(rch4_notes)		;
	ldi tmp4, high(rch4_notes)		;
	sts ch4_note_ptr_l, tmp3		;
	sts ch4_note_ptr_h, tmp4		;

	lds status, ch1_status			; mark all channels as playing
	ori status, 0b00000001			;
	sts ch1_status, status			;
	lds status, ch2_status			;
	ori status, 0b00000001			;
	sts ch2_status, status			;
	lds status, ch3_status			;
	ori status, 0b00000001			;
	sts ch3_status, status			;
	lds status, ch4_status			;
	ori status, 0b00000001			;
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

	ldi channel_data, ch1_data		; update all channels
	call update						; (get the first note)
	ldi channel_data, ch2_data		;
	call update						;
	ldi channel_data, ch3_data		;
	call update						;
	ldi channel_data, ch4_data		;
	call update						;

	ret



; -----------------------------------------------------------------------------
;   calculate new sample for each channel (126 clock cycles)
; -----------------------------------------------------------------------------
samples:
	clr sample_acc

;	-----------------------------------
;	CHANNEL 1: SQUARE (33 CLOCK CYCLES)
;	-----------------------------------
ch1_sample:
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
	lds status, ch1_status			; check if channel is active and playing
	andi status, 0b00000011			;
	cpi status, 0b00000011			;
	brne ch2_sample					;
	add sample_acc, sample 			; add sample to total

;	-----------------------------------
;	CHANNEL 2: SQUARE (33 CLOCK CYCLES)
;	-----------------------------------
ch2_sample:
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
	lds sample, ch2_volume			;
	rjmp end_ch2					;
keep_low2:
	clr sample
	nop
	nop
end_ch2:
	lds status, ch2_status			; check if channel is active and playing
	andi status, 0b00000011			;
	cpi status, 0b00000011			;
	brne ch3_sample					;
	add sample_acc, sample 			; add sample to total
	add sample_acc, sample 			; add sample to total

;	-------------------------------------
;	CHANNEL 3: TRIANGLE (30 CLOCK CYCLES)
;	-------------------------------------
ch3_sample:
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
	ldi tmp3, 0b00001110			; prepare mask according to MSB of accumulator
	sbrs tmp2, 7					;
	ldi tmp3, 0b00000001			;
	eor sample, tmp3				; exclusive OR with mask to "center" values around 7
end_ch3:
	lds status, ch3_status			; check if channel is active and playing
	andi status, 0b00000011			;
	cpi status, 0b00000011			;
	brne ch4_sample					;
	add sample_acc, sample 			; add sample to total

;	----------------------------------
;	CHANNEL 4: NOISE (30 CLOCK CYCLES)
;	----------------------------------
ch4_sample:
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
	lds status, ch4_status			; check if channel is active and playing
	andi status, 0b00000011			;
	cpi status, 0b00000011			;
	brne sample_end					;
	add sample_acc, sample 			; add sample to total

;	----------------------------------
sample_end:
	out PORTC, sample_acc			; output sum of samples
	ret
