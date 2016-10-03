; -----------------------------------------------------------------------------
;   wait for a byte from CPU
; -----------------------------------------------------------------------------

get_byte:
	; GET COMMAND
	cbi PORTB, byteread			; to CPU: done processing
	nop_x2						; wait for pins and latches to settle

wait_for_byte:
	in tmp1, PINB				; wait for CPU signal
	sbrs tmp1, newbyte			;
	rjmp wait_for_byte			;

	nop_x2						; wait for pins and latches to settle
	in tmp1, PIND				; get new byte from data-bus

	sbi PORTB, byteread			; to CPU: started processing
ret


; -----------------------------------------------------------------------------
;   enable specified channel
; -----------------------------------------------------------------------------

xenable:
	; get channel to enable
	call get_byte
ena_ch1:
	cpi tmp1, 1
	brne ena_ch2
	lds status, ch1_status
	ori status, 0b00000010
	sts ch1_status, status
ret
ena_ch2:
	cpi tmp1, 2
	brne ena_ch3
	lds status, ch2_status
	ori status, 0b00000010
	sts ch2_status, status
ret
ena_ch3:
	cpi tmp1, 3
	brne ena_ch4
	lds status, ch3_status
	ori status, 0b00000010
	sts ch3_status, status
ret
ena_ch4:
	cpi tmp1, 4
	brne ena_end
	lds status, ch4_status
	ori status, 0b00000010
	sts ch4_status, status
ena_end:
ret


; -----------------------------------------------------------------------------
;   disable specified channel
; -----------------------------------------------------------------------------

xdisable:
	; get channel to disable
	call get_byte
dis_ch1:
	cpi tmp1, 1
	brne dis_ch2
	lds status, ch1_status
	andi status, 0b11111101
	sts ch1_status, status
ret
dis_ch2:
	cpi tmp1, 2
	brne dis_ch3
	lds status, ch2_status
	andi status, 0b11111101
	sts ch2_status, status
ret
dis_ch3:
	cpi tmp1, 3
	brne dis_ch4
	lds status, ch3_status
	andi status, 0b11111101
	sts ch3_status, status
ret
dis_ch4:
	cpi tmp1, 4
	brne dis_end
	lds status, ch4_status
	andi status, 0b11111101
	sts ch4_status, status
dis_end:
ret


; -----------------------------------------------------------------------------
;   clear specified channel
; -----------------------------------------------------------------------------

xclear:
	; get channel to be cleared
	call get_byte
clr_ch1:
	cpi tmp1, 1
	brne clr_ch2
	ldi YL, low(rch1_notes)
	ldi YH, high(rch1_notes)
	rjmp clr_end
clr_ch2:
	cpi tmp1, 2
	brne clr_ch3
	ldi YL, low(rch2_notes)
	ldi YH, high(rch2_notes)
	rjmp clr_end
clr_ch3:
	cpi tmp1, 3
	brne clr_ch4
	ldi YL, low(rch3_notes)
	ldi YH, high(rch3_notes)
	rjmp clr_end
clr_ch4:
	cpi tmp1, 4
	brne clr_end
	ldi YL, low(rch4_notes)
	ldi YH, high(rch4_notes)

clr_end:
	; put an ending marker
	ldi tmp2, 0
	ldi tmp3, 146
	st Y+, tmp2
	st Y, tmp3
ret


; -----------------------------------------------------------------------------
;   set specified tempο
; -----------------------------------------------------------------------------

xtempo:
	; get new tempo value
	call get_byte

	; put it in appropriate register
	mov rythm, tmp1
ret


; -----------------------------------------------------------------------------
;   get notes and store in specified channel
; -----------------------------------------------------------------------------

xnotes:
	; get channel to add notes to
	call get_byte

	; get starting address of corresponding channel
add_ch1:
	cpi tmp1, 1
	brne add_ch2
	ldi YL, low(rch1_notes)
	ldi YH, high(rch1_notes)
	rjmp add_end
add_ch2:
	cpi tmp1, 2
	brne add_ch3
	ldi YL, low(rch2_notes)
	ldi YH, high(rch2_notes)
	rjmp add_end
add_ch3:
	cpi tmp1, 3
	brne add_ch4
	ldi YL, low(rch3_notes)
	ldi YH, high(rch3_notes)
	rjmp add_end
add_ch4:
	cpi tmp1, 4
	brne clr_end
	ldi YL, low(rch4_notes)
	ldi YH, high(rch4_notes)

add_end:
	; get address of last note in selected channel
	rcall find_marker

	; check limit for notes per channel
	cpi tmp1, 243
	brsh xnotes_end

	; get parameters of new note
	call get_byte
	st Y+, tmp1
	
	; get pitch and octave of new note
	call get_byte
	st Y+, tmp1

	; put ending marker
	clr tmp1
	st Y+, tmp1
	ldi tmp1, 146
	st Y+, tmp1
xnotes_end:
ret


; -----------------------------------------------------------------------------
;   abort current operation
; -----------------------------------------------------------------------------
xabort:
	; Nothing to abort at this moment!
    ; Return to main loop and wait for a new byte.
ret

; -----------------------------------------------------------------------------
;   stop playing
; -----------------------------------------------------------------------------
xstop:
	; Nothing to stop at this moment!
    ; Return and wait for a new byte.
ret

; -----------------------------------------------------------------------------
;   start playing
; -----------------------------------------------------------------------------
xplay:
	; to CPU: done processing (don't keep the CPU waiting!)
	cbi PORTB, byteread

	call play
ret
