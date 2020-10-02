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
	tst.b	draw_phase
	bne.s	.not_start

	cmp.b	#1,compute_phase
	blt.s	.done_update
	move.b	#1,draw_phase
	bra.s	.done_update
.not_start:
	; check if we're actively running the twist scroller
	cmp.b	#1,draw_phase
	bne.s	.not_twist
	bsr	twist_update
.not_twist:
.done_update:
;;; End customized code

	; Unblock draw thread, block this thread until it's ready again
	move.w	#$2700,sr
	move.l	next_to_update,most_recently_updated
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne.s	update_thread_entry
	rts

draw_thread_entry:
;;; Start customized code

	; check if we're actively running the twist scroller
	cmp.b	#1,draw_phase
	bne.s	.not_twist
	bsr.s	twist_draw
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
	bra.s	draw_thread_entry

main_thread_entry:
;;; Start customized code
	tst.b	compute_phase
	bne.s	not_twist
	bsr	twist_compute
	bra.s	done_phase
not_twist:
	cmp.b	#1,compute_phase
	bne.s	done_phase
	nop
done_phase:
;;; End customized code

	bra.s	main_thread_entry

;;; Start customized code
	.bss
draw_phase:
	ds.b	1
compute_phase:
	ds.b	1

	.even
heap:
	ds.b	221184
heap2:
	ds.b	307200	; 150 frames of 64*64

	.include "twistscr.s"
;;; End customized code
