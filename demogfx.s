;   Copyright 2020 Jean-Baptiste M. "JBQ" "Djaybee" Queru
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing, software
;   distributed under the License is distributed on an "AS IS" BASIS,
;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;   See the License for the specific language governing permissions and
;   limitations under the License.

	.text

update_thread_entry:
;;; Start customized code

	; check if we're actively running the twist scroller
	cmp.b	#1,demo_phase
	bne.s	.not_twist

	move.l	most_recently_updated,a5
	move.l	next_to_update,a6

	; move by 1 line
	move.w	(a5),d0
	addq.w	#1,d0
	cmp.w	#1088,d0 ; TODO: write proper code to handle text length
	bne.s	.in_range
	moveq.l	#0,d0 ; TODO: move to next phase instead of wrapping
.in_range:
	move.w	d0,(a6)
.not_twist:
;;; End customized code

	; Unblock draw thread, block this thread until it's ready again
	move.w	#$2700,sr
	move.l	next_to_update,most_recently_updated
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
	bra.s	update_thread_entry

draw_thread_entry:
;;; Start customized code

	; check if we're actively running the twist scroller
	cmp.b	#1,demo_phase
	bne.s	.not_twist

	; handle the scroll by skipping lines
	; d7 = position in scroller = lines to skip in whole scroller
	move.l	back_to_draw_data,a6
	move.w	(a6),d7

	; d1 = 4-d7%4 = number of remaining lines in current slice
	move.w	d7,d1
	andi.w	#3,d1
	neg.w	d1
	addq.w	#4,d1

	; d7 = d7/4 = number of slices to skip in whole scroller
	lsr.w	#2,d7

	; d6 = d7%8 = number of slices to skip in current character
	move.w	d7,d6
	andi.w	#7,d6

	; d2 = 8-d6 = number of remaining slices on current character
	moveq.l	#8,d2
	sub.w	d6,d2

	; d7 = d7/8 = number of characters to skip
	lsr.w	#3,d7

	; a1 = address of the character to draw
	move.l	#twist_text,a1
	adda.w	d7,a1

	; a2 = address of the font slice to draw
	moveq.l	#0,d7
	move.b	(a1)+,d7
	sub.b	#32,d7
	lsl.w	#3,d7
	add.w	d6,d7
	move.l	#twist_font,a2
	add.w	d7,a2

	; a0 = destination address
	move.l	back_buffer,a0
	; d0 = limes to draw after this one
	move.w	#199,d0
.draw_line:
	; draw one slice, move to next line
	move.b	(a2),(a0)
	adda.w	#160,a0

	; check is that was the last line of this slice
	subq.w	#1,d1
	bne.s	.same_char

	moveq.l	#4,d1
	addq.w	#1,a2

	; check if that was the last slice of this character
	subq.w	#1,d2
	bne.s	.same_char

	; move to the next character
	moveq.l	#0,d3
	move.b	(a1)+,d3
	sub.b	#32,d3
	lsl.w	#3,d3
	move.l	#twist_font,a2
	add.w	d3,a2
	moveq.l	#8,d2

.same_char:
	dbra	d0,.draw_line

.not_twist:

;;; End customized code

	; Block this thread until it's ready again
	move.w	#$2700,sr
	move.l	back_drawn_data,-(sp)
	move.l	back_to_draw_data,back_drawn_data
	move.l	(sp)+,back_to_draw_data
	move.l	back_to_draw_data,next_to_update
	clr.b	draw_thread_ready
	jsr	switch_threads
	bra	draw_thread_entry

main_thread_entry:
main_loop:
;;; Start customized code
	tst.b	demo_phase
	bne.s	.not_twist
	move.l	#twist_y1,front_drawn_data
	move.l	#twist_y2,front_to_draw_data
	move.l	#twist_y3,back_drawn_data
	move.l	#twist_y4,back_to_draw_data
	move.l	back_to_draw_data,most_recently_updated
	move.l	back_to_draw_data,next_to_update
	move.b	#1,demo_phase
	move.w	#$707,$ffff8242.w
.not_twist:
;;; End customized code

; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne.s	main_loop
	rts

;;; Start customized code
	.data

; centered small
; centered medium
; centered large
; clipped
; side (2x)
; split

; half-offset (2x) (for Z'?)
; asymetrical split (for NQ)

; 6 to 8 slices
;
; min 16 pixel positions
; 32 rotations?

; 32 pix wide = 12 bytes per slice w/ split storage (CPU?)

; 8*32*64*12 = 196608

; non-linear rotation space for smoothness?

;   ########
; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####
; ####    ####

; ##########
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ##########

;   ########
; ####    ####
; ####
; ####
; ####
; ####    ####
;   ########

; ##########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ##########

; ############
; ####
; ####
; ##########
; ####
; ####
; ############

; ############
; ####
; ####
; ##########
; ####
; ####
; ####

;   ########
; ####    ####
; ####
; ####    ####
; ####    ####
; ####    ####
;   ########

; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####
; ####    ####
; ####    ####

;   ########
;     ####
;     ####
;     ####
;     ####
;     ####
;   ########

;         ####
;         ####
;         ####
;         ####
;         ####
; ####    ####
;   ########

; ####    ####
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ####    ####

; ####
; ####
; ####
; ####
; ####
; ####
; ############

; ####    ####
; ############
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####

;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####

;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########

; ##########
; ####    ####
; ####    ####
; ##########
; ####
; ####
; ####

;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ############
;   ##########

; ##########
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ####    ####

;   ########
; ####    ####
; ####
;   ########
;         ####
; ####    ####
;   ########

; ############
;     ####
;     ####
;     ####
;     ####
;     ####
;     ####

; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########

; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########
;     ####

; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####

; ####    ####
; ####    ####
; ####    ####
;   ########
; ####    ####
; ####    ####
; ####    ####

; ####    ####
; ####    ####
; ####    ####
;   ########
;     ####
;     ####
;     ####

; ############
;         ####
;     ####
;     ####
;     ####
; ####
; ############

;
;
;
;
;
;     ####
;     ####

;     ####
;     ####
;     ####
;     ####
;
;     ####
;     ####


;   ########
; ####    ####
;         ####
;     ####
;
;     ####
;     ####

;     ####
;     ####
; ####
;
;
;
;

; ####    ####
; ######  ####
; ############
; ####  ######
; ####    ####
; ####    ####
; ####    ####

;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####  ######
;   ##########

; ############
;         ####
;       ####
;     ####
;   ####
; ####
; ############

;   ########
; ####    ####
;       ####
;     ####
;
;     ####
;     ####

;       ####
;     ####
;   ####
;
;
;
;



twist_font:
; space
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
; !
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	0
	dc.b	1
	dc.b	0

twist_text:
	dc.b	"       "				; 7
	dc.b	"! ! !   !!! !!! !!!   ! ! !"		; 27
	dc.b	"       "				; 7

	.bss
	.even
twist_y1:
	ds.w	1
twist_y2:
	ds.w	1
twist_y3:
	ds.w	1
twist_y4:
	ds.w	1

demo_phase:
	ds.b	1
;;; End customized code
