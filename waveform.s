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

wave_update:
	move.l	most_recently_updated,a5
	move.l	next_to_update,a6

	; move by 1 line
	move.w	(a5),d0
	addq.w	#1,d0
	cmp.w	#1088,d0 ; TODO: write proper code to handle text length
	bne.s	.in_range
	moveq.l	#0,d0 ; TODO: move to next phase instead of wrapping
	move.b	#2,draw_phase
.in_range:
	move.w	d0,(a6)
	rts

wave_draw:
	; handle the scroll by skipping lines
	; d7 = position in scroller = lines to skip in whole scroller
	move.l	back_to_draw_data,a6

	rts

wave_compute:
	move.b	#1,compute_wait_phase
	move.l	#wave_update,update_wait_routine
	move.l	#wave_draw,draw_wait_routine

	move.l	#wave_f1,front_drawn_data
	move.l	#wave_f2,front_to_draw_data
	move.l	#wave_f3,back_drawn_data
	move.l	#wave_f4,back_to_draw_data
	move.l	back_to_draw_data,most_recently_updated
	move.l	back_to_draw_data,next_to_update

	move.b	#1,compute_phase
	clr.l	compute_routine
	rts

	.data

	.even

	.bss
	.even
wave_f1:
	ds.w	1
wave_f2:
	ds.w	1
wave_f3:
	ds.w	1
wave_f4:
	ds.w	1
