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
	cmp.w	#416,d0 ; TODO: write proper code to handle text length
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

	move.l	back_buffer,a0

	; handle the scroll by skipping lines
	; d0 = number of lines to skip
	move.l	back_to_draw_data,a6
	move.w	(a6),d0

	; d1 = 8-(d0%7) = number of remaining lines on current character
	move.w	d0,d1
	andi.w	#7,d1
	neg.w	d1
	addq.w	#8,d1

	; a1 = address of the character to draw
	move.l	#twist_text,a1
	lsr.w	#3,d0
	adda.w	d0,a1

	; a2 = address of the font slice to draw
	moveq.l	#0,d2
	move.b	(a1)+,d2
	sub.b	#32,d2
	lsl.w	#3,d2
	move.l	#twist_font,a2
	add.w	d2,a2
	; TODO: skip some lines as necessary

	; d0 = limes to draw after this one
	move.w	#199,d0
.draw_line:
	; draw one slice
	move.b	(a2)+,(a0)

	; check if that was the last slice of this character
	subq.w	#1,d1
	bne.s	.same_char

	; move to the next character
	moveq.l	#0,d2
	move.b	(a1)+,d2
	sub.b	#32,d2
	lsl.w	#3,d2
	move.l	#twist_font,a2
	add.w	d2,a2
	moveq.l	#8,d1

.same_char:
	; move to the next screen line
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
	dc.b	"                         "
	dc.b	"! ! !   !!! !!! !!!   ! ! !"
	dc.b	"                         "
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
