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

; d0: increment
; d1: row start
; d2: current cell
; d3
; d4: data 1
; d5: data 2
; d6: loop x
; d7; loop y
; a0: write 1 (top left)
; a1: write 2 (top right)
; a2: write 3 (bottom left)
; a3: write 4 (bottom right)
; a4: read graphics
wave_draw:
	move.l	back_to_draw_data,a6
	move.w	(a6),d0

	move.l	back_buffer,a0
	move.l	a0,a1
	move.l	a0,a2
	move.l	a0,a3
	adda.w	#13832,a0
	adda.w	#13840,a1
	adda.w	#16392,a2
	adda.w	#16400,a3

	move.w	#5,d7		; elements in a column
	move.w	d0,d1
.copy_row:
	move.w	#5,d6		; elements in a row
	move.w	d1,d2

.copy_element:
	move.w	d2,d3
	lsr.w	#1,d3
	andi.w	#120,d3

	move.l	#wave_gfx,a4
	adda.w	d3,a4

	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,(a0)
	move.w	d5,4(a0)
	move.l	d4,1760(a0)
	move.w	d5,1764(a0)
	move.l	d4,(a1)
	move.w	d5,4(a1)
	move.l	d4,1760(a1)
	move.w	d5,1764(a1)
	move.l	d4,(a2)
	move.w	d5,4(a2)
	move.l	d4,1760(a2)
	move.w	d5,1764(a2)
	move.l	d4,(a3)
	move.w	d5,4(a3)
	move.l	d4,1760(a3)
	move.w	d5,1764(a3)
	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,160(a0)
	move.w	d5,164(a0)
	move.l	d4,1600(a0)
	move.w	d5,1604(a0)
	move.l	d4,160(a1)
	move.w	d5,164(a1)
	move.l	d4,1600(a1)
	move.w	d5,1604(a1)
	move.l	d4,160(a2)
	move.w	d5,164(a2)
	move.l	d4,1600(a2)
	move.w	d5,1604(a2)
	move.l	d4,160(a3)
	move.w	d5,164(a3)
	move.l	d4,1600(a3)
	move.w	d5,1604(a3)
	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,320(a0)
	move.w	d5,324(a0)
	move.l	d4,1440(a0)
	move.w	d5,1444(a0)
	move.l	d4,320(a1)
	move.w	d5,324(a1)
	move.l	d4,1440(a1)
	move.w	d5,1444(a1)
	move.l	d4,320(a2)
	move.w	d5,324(a2)
	move.l	d4,1440(a2)
	move.w	d5,1444(a2)
	move.l	d4,320(a3)
	move.w	d5,324(a3)
	move.l	d4,1440(a3)
	move.w	d5,1444(a3)
	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,480(a0)
	move.w	d5,484(a0)
	move.l	d4,1280(a0)
	move.w	d5,1284(a0)
	move.l	d4,480(a1)
	move.w	d5,484(a1)
	move.l	d4,1280(a1)
	move.w	d5,1284(a1)
	move.l	d4,480(a2)
	move.w	d5,484(a2)
	move.l	d4,1280(a2)
	move.w	d5,1284(a2)
	move.l	d4,480(a3)
	move.w	d5,484(a3)
	move.l	d4,1280(a3)
	move.w	d5,1284(a3)
	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,640(a0)
	move.w	d5,644(a0)
	move.l	d4,1120(a0)
	move.w	d5,1124(a0)
	move.l	d4,640(a1)
	move.w	d5,644(a1)
	move.l	d4,1120(a1)
	move.w	d5,1124(a1)
	move.l	d4,640(a2)
	move.w	d5,644(a2)
	move.l	d4,1120(a2)
	move.w	d5,1124(a2)
	move.l	d4,640(a3)
	move.w	d5,644(a3)
	move.l	d4,1120(a3)
	move.w	d5,1124(a3)
	move.l	(a4)+,d4
	move.l	(a4)+,d5
	swap.w	d5
	move.l	d4,800(a0)
	move.w	d5,804(a0)
	move.l	d4,960(a0)
	move.w	d5,964(a0)
	move.l	d4,800(a1)
	move.w	d5,804(a1)
	move.l	d4,960(a1)
	move.w	d5,964(a1)
	move.l	d4,800(a2)
	move.w	d5,804(a2)
	move.l	d4,960(a2)
	move.w	d5,964(a2)
	move.l	d4,800(a3)
	move.w	d5,804(a3)
	move.l	d4,960(a3)
	move.w	d5,964(a3)

	subq.l	#8,a0
	addq.l	#8,a1
	subq.l	#8,a2
	addq.l	#8,a3
	add.w	d0,d2
	dbra.w	d6,.copy_element
	sub.w	#2512,a0
	sub.w	#2608,a1
	add.w	#2608,a2
	add.w	#2512,a3
	add.w	d0,d1
	dbra.w	d7,.copy_row

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
