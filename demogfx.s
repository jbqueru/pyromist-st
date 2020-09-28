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
	bne	.not_twist

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

	; a0 = address of start of line
	move.l	back_buffer,a0
	; d0 = limes to draw after this one
	move.w	#199,d0
.draw_line:
	; a6 = address of destination pixels
	move.l	a0,a6
	move.w	d0,d7
	andi.w	#$ffe0,d7 ; d7 = offset within line. Note: d0 is half-pixels
	lsr.w	#2,d7
	adda.w	d7,a6
	; draw one slice, move to next line
	; d7 = slice being drawn
	moveq.l	#0,d7
	move.b	(a2),d7
	; 15 is magic value of empty slice - drawn with code to save RAM
	cmpi.b	#15,d7
	beq.s	.empty_slice
	lea.l	heap,a5

	; offset for slice (1024 18-byte units for each slice)
	swap.w	d7
	lsr.l	#6,d7

	; offset for x position (32 18-byte units for each half-pixel)
	move.w	d0,d6
	andi.w	#$001f,d6
	lsl.w	#5,d6
	add.w	d6,d7

	; multiply by 18 (d7*2*(1+8))
	add.w	d7,d7	; d7 is 11-bit, word is enough
	move.l	d7,d6
	lsl.l	#3,d7
	add.l	d6,d7

	add.l	d7,a5
	move.l	(a5)+,(a6)+
	move.w	(a5)+,(a6)+
	addq.l	#2,a6
	move.l	(a5)+,(a6)+
	move.w	(a5)+,(a6)+
	addq.l	#2,a6
	move.l	(a5)+,(a6)+
	move.w	(a5)+,(a6)+
	bra.s	.done_slice
.empty_slice:
	moveq.l	#0,d7
	move.l	d0,(a6)+
	move.w	d0,(a6)+
	addq.l	#2,a6
	move.l	d0,(a6)+
	move.w	d0,(a6)+
	addq.l	#2,a6
	move.l	d0,(a6)+
	move.w	d0,(a6)+
.done_slice:

	; check is that was the last line of this slice
	subq.w	#1,d1
	bne.s	.same_char

	moveq.l	#4,d1
	addq.w	#1,a2

	; check if that was the last slice of this character
	subq.w	#1,d2
	bne.s	.same_char

	; move to the next character
	moveq.l	#0,d7
	move.b	(a1)+,d7
	sub.b	#32,d7
	lsl.w	#3,d7
	move.l	#twist_font,a2
	add.w	d7,a2

	moveq.l	#8,d2

.same_char:
	adda.w	#160,a0
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
	bne	.not_twist
	move.l	#twist_y1,front_drawn_data
	move.l	#twist_y2,front_to_draw_data
	move.l	#twist_y3,back_drawn_data
	move.l	#twist_y4,back_to_draw_data
	move.l	back_to_draw_data,most_recently_updated
	move.l	back_to_draw_data,next_to_update

	lea.l	heap,a0
	lea.l	twist_slices,a1
	moveq.l	#11,d0
.l0:
	moveq.l	#31,d1
	move.w	(a1)+,d5
	move.w	(a1)+,d6
	clr.w	d7
.l1:
	moveq.l	#31,d2
.l2:
	move.w	d5,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	d6,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	d7,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	dbra	d2,.l2
	btst	#0,d1
	bne.s	.same_pix
	lsr.w	d5
	roxr.w	d6
	roxr.w	d7
.same_pix:
	dbra	d1,.l1
	dbra	d0,.l0

	move.w	#$707,$ffff8242.w
	move.b	#1,demo_phase
.not_twist:
;;; End customized code

; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne	main_loop
	rts

;;; Start customized code
	.data

	.even
twist_slices:
	dc.w	%0111111110000000,%0000000000000000	; 0 - side left
	dc.w	%0000000000000000,%0111111110000000	; 1 - side right
	dc.w	%0111111111111111,%1111100000000000	; 2 - cropped left
	dc.w	%0000011111111111,%1111111110000000	; 3 - cropped right

	dc.w	%0000011111111000,%0000000000000000	; 4 - offset left
	dc.w	%0000000000000111,%1111100000000000	; 5 - offset right
	dc.w	%0111111111111000,%0111111110000000	; 6 - half-split left
	dc.w	%0111111110000111,%1111111110000000	; 7 - half-split right

	dc.w	%0000000001111111,%1000000000000000	; 8 - center small
	dc.w	%0000011111111111,%1111100000000000	; 9 - center medium
	dc.w	%0111111111111111,%1111111110000000	; 10 - center large
	dc.w	%0111111110000000,%0111111110000000	; 11 - split

twist_font:
; space
	dc.b	15,15,15,15,15,15,15,15
;     ####
;     ####
;     ####
;     ####
;
;     ####
;     ####
	dc.b	8,8,8,8,15,8,8,15
; "
	dc.b	15,15,15,15,15,15,15,15
; #
	dc.b	15,15,15,15,15,15,15,15
; $
	dc.b	15,15,15,15,15,15,15,15
; %
	dc.b	15,15,15,15,15,15,15,15
; &
	dc.b	15,15,15,15,15,15,15,15
;       ####
;     ####
;   ####
;
;
;
;
	dc.b	5,8,4,15,15,15,15,15
; (
	dc.b	15,15,15,15,15,15,15,15
; )
	dc.b	15,15,15,15,15,15,15,15
; *
	dc.b	15,15,15,15,15,15,15,15
; +
	dc.b	15,15,15,15,15,15,15,15
; ,
	dc.b	15,15,15,15,15,15,15,15
; -
	dc.b	15,15,15,15,15,15,15,15
;
;
;
;
;
;     ####
;     ####
	dc.b	15,15,15,15,15,8,8,15
; /
	dc.b	15,15,15,15,15,15,15,15
; 0
	dc.b	15,15,15,15,15,15,15,15
; 1
	dc.b	15,15,15,15,15,15,15,15
; 2
	dc.b	15,15,15,15,15,15,15,15
; 3
	dc.b	15,15,15,15,15,15,15,15
; 4
	dc.b	15,15,15,15,15,15,15,15
; 5
	dc.b	15,15,15,15,15,15,15,15
; 6
	dc.b	15,15,15,15,15,15,15,15
; 7
	dc.b	15,15,15,15,15,15,15,15
; 8
	dc.b	15,15,15,15,15,15,15,15
; 9
	dc.b	15,15,15,15,15,15,15,15
; :
	dc.b	15,15,15,15,15,15,15,15
; ;
	dc.b	15,15,15,15,15,15,15,15
; <
	dc.b	15,15,15,15,15,15,15,15
; =
	dc.b	15,15,15,15,15,15,15,15
; >
	dc.b	15,15,15,15,15,15,15,15
;   ########
; ####    ####
;       ####
;     ####
;
;     ####
;     ####
	dc.b	9,11,5,8,15,8,8,15
; @
	dc.b	15,15,15,15,15,15,15,15

;   ########
; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####
; ####    ####
	dc.b	9,11,11,11,10,11,11,15
; ##########
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ##########
	dc.b	2,11,11,2,11,11,2,15
;   ########
; ####    ####
; ####
; ####
; ####
; ####    ####
;   ########
	dc.b	9,11,0,0,0,11,9,15
; ##########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ##########
	dc.b	2,11,11,11,11,11,2,15
; ############
; ####
; ####
; ##########
; ####
; ####
; ############
	dc.b	10,0,0,2,0,0,10,15
; ############
; ####
; ####
; ##########
; ####
; ####
; ####
	dc.b	10,0,0,2,0,0,0,15
;   ########
; ####    ####
; ####
; ####  ######
; ####    ####
; ####    ####
;   ########
	dc.b	9,11,0,7,11,11,9,15
; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####
; ####    ####
; ####    ####
	dc.b	11,11,11,10,11,11,11,15
;   ########
;     ####
;     ####
;     ####
;     ####
;     ####
;   ########
	dc.b	9,8,8,8,8,8,9,15
;         ####
;         ####
;         ####
;         ####
;         ####
; ####    ####
;   ########
	dc.b	1,1,1,1,1,11,9,15
; ####    ####
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ####    ####
	dc.b	11,11,11,2,11,11,11,15
; ####
; ####
; ####
; ####
; ####
; ####
; ############
	dc.b	0,0,0,0,0,0,10,15
; ####    ####
; ############
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
	dc.b	11,10,11,11,11,11,11,15
; ####    ####
; ######  ####
; ############
; ####  ######
; ####    ####
; ####    ####
; ####    ####
	dc.b	11,6,10,7,11,11,11,15
;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########
	dc.b	9,11,11,11,11,11,9,15
; ##########
; ####    ####
; ####    ####
; ##########
; ####
; ####
; ####
	dc.b	2,11,11,2,0,0,0,15
;   ########
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####  ######
;   ##########
	dc.b	9,11,11,11,11,7,3,15
; ##########
; ####    ####
; ####    ####
; ##########
; ####    ####
; ####    ####
; ####    ####
	dc.b	2,11,11,2,11,11,11,15
;   ########
; ####    ####
; ####
;   ########
;         ####
; ####    ####
;   ########
	dc.b	9,11,0,9,1,11,9,15
; ############
;     ####
;     ####
;     ####
;     ####
;     ####
;     ####
	dc.b	10,8,8,8,8,8,8,15
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########
	dc.b	11,11,11,11,11,11,9,15
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
;   ########
;     ####
	dc.b	11,11,11,11,11,9,8,15
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ####    ####
; ############
; ####    ####
	dc.b	11,11,11,11,11,10,11,15
; ####    ####
; ####    ####
; ####    ####
;   ########
; ####    ####
; ####    ####
; ####    ####
	dc.b	11,11,11,9,11,11,11,15
; ####    ####
; ####    ####
; ####    ####
;   ########
;     ####
;     ####
;     ####
	dc.b	11,11,11,9,8,8,8,15
; ############
;         ####
;       ####
;     ####
;   ####
; ####
; ############
	dc.b	10,1,5,8,4,0,10,15
twist_text:
	dc.b	"       "				; 7
	dc.b	"ABCDEFGHIJKLMNOPQRSTUVWXYZ!"		; 27
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

	.even
heap:
	ds.b	221184
;;; End customized code
