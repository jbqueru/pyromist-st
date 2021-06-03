;   Copyright 2021 Jean-Baptiste M. "JBQ" "Djaybee" Queru
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

	move.w	#$700,$ffff8242.w
	move.w	#$740,$ffff8244.w
	move.w	#$770,$ffff8246.w
	move.w	#$070,$ffff8248.w
	move.w	#$077,$ffff824a.w
	move.w	#$007,$ffff824c.w
	move.w	#$707,$ffff824e.w

	move.b	#1,compute_phase
	clr.l	compute_routine
	rts

wave_update:
	move.l	most_recently_updated,a5
	move.l	next_to_update,a6

	; advance 1 frame
	move.w	(a5),d0
	addq.w	#1,d0
	cmp.w	#1024,d0
	bne.s	.in_range
	move.b	#2,draw_phase
.in_range:
	move.w	d0,(a6)
	rts

wave_draw:
	move.l	back_to_draw_data,a6
	move.w	(a6),d0

	move.l	back_buffer,a0

	move.w	#12,d7		; elements in a column
	move.w	d0,d1

.copy_element:
	move.w	d1,d2
	andi.w	#120,d2

	move.l	#wave_gfx,a1
	adda.w	d2,a1

	move.w	#12,d6
.copy_line:
	move.w	(a1)+,(a0)+
	move.w	(a1)+,(a0)+
	move.w	(a1)+,(a0)+
	move.w	(a1)+,(a0)+
	adda.w	#152,a0
	dbra.w	d6,.copy_line

	adda.w	#320,a0
	add.w	d0,d1
	dbra.w	d7,.copy_element

	rts

	.data
	.even
wave_gfx:
	dc.w	$fff,0,0,0
	dc.w	$fff,0,0,0
	dc.w	0,$fff,0,0
	dc.w	0,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	0,0,$fff,0
	dc.w	0,0,$fff,0
	dc.w	$fff,0,$fff,0
	dc.w	$fff,0,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	$fff,$fff,$fff,0
	dc.w	$fff,$fff,$fff,0
	dc.w	$fff,0,0,0
	dc.w	$fff,0,0,0
	dc.w	0,$fff,0,0
	dc.w	0,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	$fff,$fff,0,0
	dc.w	0,0,$fff,0
	dc.w	0,0,$fff,0
	dc.w	$fff,0,$fff,0
	dc.w	$fff,0,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	0,$fff,$fff,0
	dc.w	$fff,$fff,$fff,0
	dc.w	$fff,$fff,$fff,0

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
