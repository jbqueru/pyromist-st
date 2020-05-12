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

; **********************************
; **********************************
; *** BASIC LINE-DRAWING ROUTINE ***
; **********************************
; **********************************
;
; This is a straightforward implementation of Bresenham.
;
; TODO: Add comments
draw_line:
; Get line coordinates in (d0,d1) and (d2,d3)

; Swap line ends if necessary so that d0 >= d2, to draw lines right-to-left
; Drawing right-to-left is faster, because the fastest way to shift a 16-bit
; register by 1 is to add it to itself, but that only works in one direction
	cmp.w	d0,d2
	ble.s	.lines_ordered ; d2 >= d0
	exg	d0,d2
	exg	d1,d3
.lines_ordered:

; Compute end of line relative to start
	move.w	#160,d4	; addr_offset
	sub.w	d0,d2	; dx
	neg.w	d2	; TODO: re-org registers to avoid this
	sub.w	d1,d3	; dy
; Adjust delta-y to be positive, adjust line offset accordingly
	bge.s	.adjusted_dy ; d3 >= d1
	neg.w	d3
	neg.w	d4
.adjusted_dy:

; d0,d1 are x,y of the left end
; d2,d3 are the pixel offset to the right end, both positive
; d4 is the address offset when changing lines.

; Compute start address and start pixel pattern
	mulu.w	#160,d1
	adda.w	d1,a0
	move.w	d0,d1
	lsr.w	#1,d0
	and.w	#248,d0
	adda.w	d0,a0
	move.w	#$8000,d5 ; pixel pattern
	andi.w	#15,d1
	lsr.w	d1,d5

; Check which type of line we're drawing
	cmp.w	d2,d3
	blt.s	draw_h_line ; d3 < d2
	beq.s	draw_d_line ; d3 = d2 - includes single-pixel lines

; Draw a vertical-ish line
draw_v_line:
	swap.w	d2
	clr.w	d2
	divu	d3,d2
	move.w	#$7fff,d6

.draw_v_pixel:
	or.w	d5,(a0)
	add.w	d2,d6
	bcc.s	.done_v_adjust
	add.w	d5,d5
	bne.s	.done_v_adjust
	subq.l	#8,a0
	moveq.l	#1,d5
.done_v_adjust:
	add.w	d4,a0
	dbra	d3,.draw_v_pixel
	rts

draw_h_line:
; Draw a horizontal-ish line
setup_h_slope:
	swap.w	d3
	clr.w	d3
	divu	d2,d3
	move.w	#$7fff,d6

.draw_h_pixel:
	or.w	d5,(a0)
	add.w	d3,d6
	bcc.s	.done_h_adjust1
	add.w	d4,a0
.done_h_adjust1:
	add.w	d5,d5
	bne.s	.done_h_adjust2
	subq.l	#8,a0
	moveq.l	#1,d5
.done_h_adjust2:
	dbra	d2,.draw_h_pixel
	rts

draw_d_line:
.draw_d_pixel:
	or.w	d5,(a0)
	add.w	d5,d5
	bne.s	.done_d_adjust
	subq.l	#8,a0
	moveq.l	#1,d5
.done_d_adjust:
	add.w	d4,a0
	dbra	d3,.draw_d_pixel
	rts
