; -----------------------------------------------------------------------------
;   copy channel data from flash to SRAM
; -----------------------------------------------------------------------------

mem_init:
	; keep tempo value locally
	ldi ZH, high(ftempo*2)
	ldi ZL, low(ftempo*2)
	lpm rythm, Z

	; transfer channel1 notes
	ldi ZH, high(fch1_notes*2)
	ldi ZL, low(fch1_notes*2)
	ldi YH, high(rch1_notes)
	ldi YL, low(rch1_notes)
	ldi tmp1, 212
ch1_cp_loop:
	lpm r0, Z+
	st Y+, r0 
	lpm r0, Z+
	st Y+, r0 
	dec tmp1
	brne ch1_cp_loop

	; transfer channel2 notes
	ldi ZH, high(fch2_notes*2)
	ldi ZL, low(fch2_notes*2)
	ldi YH, high(rch2_notes)
	ldi YL, low(rch2_notes)
	ldi tmp1, 212
ch2_cp_loop:
	lpm r0, Z+
	st Y+, r0 
	lpm r0, Z+
	st Y+, r0 
	dec tmp1
	brne ch2_cp_loop

	; transfer channel3 notes
	ldi ZH, high(fch3_notes*2)
	ldi ZL, low(fch3_notes*2)
	ldi YH, high(rch3_notes)
	ldi YL, low(rch3_notes)
	ldi tmp1, 212
ch3_cp_loop:
	lpm r0, Z+
	st Y+, r0 
	lpm r0, Z+
	st Y+, r0 
	dec tmp1
	brne ch3_cp_loop

	; transfer channel4 notes
	ldi ZH, high(fch4_notes*2)
	ldi ZL, low(fch4_notes*2)
	ldi YH, high(rch4_notes)
	ldi YL, low(rch4_notes)
	ldi tmp1, 212
ch4_cp_loop:
	lpm r0, Z+
	st Y+, r0 
	lpm r0, Z+
	st Y+, r0 
	dec tmp1
	brne ch4_cp_loop
ret


; -----------------------------------------------------------------------------
;   locate end of melody
; 	input:  Y points to beginning of memory space for a channel
;   output: Y points just after the last note
;   output: tmp1 counts existing notes
; -----------------------------------------------------------------------------

find_marker:
	clr tmp1
check_byte:
	ld tmp2, Y+					; check second byte of each couple
	ld tmp2, Y					;
	inc tmp1
	cpi tmp2, 146
	brne check_byte
	dec tmp1
	sbiw YH:YL, 1
ret


