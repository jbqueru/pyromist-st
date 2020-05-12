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

; **************************************
; **************************************
; *** OPTIMIZED LINE-DRAWING ROUTINE ***
; **************************************
; **************************************
;
; This is a modified Bresenham algorithm, which moves by 16 pixels at a time.
;
; Each unit of 16 pixels is drawn as a bitmap with a hard-coded shape,
; with generated code for all possible bitmaps.
;
; Compared to traditional Bresenham, this is slightly less precise as it
; forces every 16th pixel to align on a grid, and draw segments between those.
;
; It would be possible to improve precision with partial pixel alignments,
; at the expense of memory usage.
;
; Segments that are mostly vertical are drawn byte-by-byte, avoiding the need
; to shift data, by using all 8 data registers to represent the 8 possible
; positions of a bit within a byte.
;
; TODO: Segments that are mostly horizontal are drawn word by word, with
; imemdiate values.
;
; TODO: Evaluate whether diagonals must be handled separately, because of
; risks of overflow in fixed-point Bresenham.
;
; TODO: Evaluate whether to special-case exact verticals and horizontals,
; for speed.
;
; Parameters:
; d0,d1: (x1,y1), coordinates of one end of the line
; d2,d3: (x2,y2), coordinates of the other end of the line
; a0: base address of the framebuffer
;
; Registers modified: All

draw_fast_line:

; Determine absolute value of dx and dy to compute overall direction
	move.w	d0,d4
	sub.w	d2,d4
	beq.s	fast_vertical ; d0=d2, x1=x2, vertical line (or single)
	bpl.s	.positive_dx
	neg.w	d4
.positive_dx: ; from this point d4 is abs(x1-x2)
	move.w	d1,d5
	sub.w	d3,d5
	beq.s	fast_horizontal ; d1=d3, y1=y2, horizontal line
	bpl.s	.positive_dy
	neg.w	d5
.positive_dy: ; from this point d5 is abs(y1-y2)
	cmp.w	d4,d5
	beq.s	fast_diagonal ; abs(y1-y2)=abs(x1-x2), diagonal line
	bge.s	fl_vertical_ish ; d5>=d4, abs(y1-y2)>=abs(x1-x2)
	bra.s	fast_horizontal_ish

; Draw vertical line
fast_vertical:
	bra	draw_line
; Draw horizonal line
fast_horizontal:
	bra	draw_line
; Draw diagonal line
fast_diagonal:
	bra	draw_line
; Draw horizonal_ish line
fast_horizontal_ish:
	bra	draw_line

; **************************
; * Draw vertical-ish line *
; **************************
;
; Lines are drawn top-to-bottom, in segments of 16. The segments to be
; drawn are determined in opposite order, starting at the bottom.
;
; The code to draw all possible segments is pre-generated.
;
; The algorithm obviously requires to draw partial segments. It is easier to
; draw the end of a segment than the beginning: the former can be achieved
; by jumping into the middle of the code, while the latter would require to
; patch the code in place.
;
; Executing the code for all segments is achieved by pushing the addresses
; of all the segments (in reverse order) on the stack. Using "rts" takes
; care at the same time of fetching the target address, jumping to it, and
; pointing to the following address, without having to worry about the end
; of the chain which is handled as the counterpart of a traditional jsr.
;
; When drawing a segment, the address register points to the last pixel to
; be drawn. This allows to adjust the address within the segment, without
; having to know the address of the first pixel of the next segment.
;
; The code works with positive numbers. Lines that are drawn along the
; second diagonal are essentially handled by symmetry. This results in
; minor duplication of code for vertical segments, but the separation is
; advantageous as it makes each set of generated code smaller than 32kB,
; which is cleaner to address with straight 16-bit offsets.
;
; Parameters: Same as overall fast line routine, with the constraint
; that abs(y1-y2)>abs(x1-x2).
;
; Registers modified: All

fl_vertical_ish:
	cmp.w	d1,d3
	ble.s	.ends_ordered	; d3<=d1
	exg	d0,d2
	exg	d1,d3
.ends_ordered:	; from this point the ends are in order, d1>=d3.
	lea.l	fl_vi_seg_addr,a6
	move.w	d1,d5
	sub.w	d3,d5	; d5 is delta-y, guaranteed to be positive
	move.w	d2,d4
	sub.w	d0,d4	; d4 is delta-x
	bpl.s	.positive_slope
	neg.w	d4
	adda.w	#1088,a6	; TODO: more work for other diagonal
.positive_slope:	; d4 and d5 are positive delta-x and delta-y
	swap.w	d4
	clr.w	d4
	divu.w	d5,d4	; TODO: don't compute the slope for small lines
	swap.w	d4
	clr.w	d4
	swap.w	d4
	lsl.l	#4,d4	; d4 is the Bresenham step for 16 pixels, stored as
			; 16:16, with 12 significant fractional bits

	swap d0
	move.w	#$7fff,d0

; At the end, need to figure out the coordinates of the last point of
; the first (partial) segment, and need to figure out the size of that
; segment.

; The coordinates of the last point of the line aren't important to keep.
; The x value of the last point of the segment to process is important.
; Chances are, it's in the upper bits of the Bresenham accumulator.

; How to best determine how many lines to draw?
; d5 is delta-y, easy to decrement by 16 and test for small numbers

; d0 is x position, in 16:16
; d1 is unused?
; d2 is x of top end of line
; d3 is y of top end of line
; d4 is Bresenham in 16:16
; d5 is number of pixels that haven't been processed yet
; d6 is unused
; d7 is unused

.next_segment:
	cmp.w	#16,d5 ; getting close to the end of the line?
	blt.s	.last_segment
	sub.w	#16,d5 ; segment done, 16 fewer pixels to go.

; Draw a whole segment
	swap.w	d0
	move.w	d0,d7
	andi.w	#15,d7
	swap.w	d0

	move.l	d0,d1
	add.l	d4,d1
	swap.w	d0
	swap.w	d1
	sub.w	d1,d0
	swap.w	d1
	neg.w	d0
	lsl.w	#4,d0
	add.w	d0,d7

	add.w	d7,d7
	add.w	d7,d7
	move.l	(a6,d7.w),-(a7)

	move.l	d1,d0

	bra.s	.next_segment

.last_segment:
	add.w	d5,d3
	mulu.w	#160,d3

	move.l	d0,d4
	swap.w	d4
	andi.w	#$fff0,d4
	lsr.w	d4
	add.w	d4,d3
	adda.w	d3,a0		; a0 is the address where we draw

	swap.w	d0
	move.w	d0,d7
	andi.w	#15,d7
	swap.w	d0
	add.w	d7,d7
	add.w	d7,d7
	move.l	(a6,d7.w),a1

	add.w	d5,d5
	add.w	d5,d5
	sub.w	#64,d5
	suba.w	d5,a1

	moveq.l	#%10000000,d0
	moveq.l	#%01000000,d1
	moveq.l	#%00100000,d2
	moveq.l	#%00010000,d3
	moveq.l	#%00001000,d4
	moveq.l	#%00000100,d5
	moveq.l	#%00000010,d6
	moveq.l	#%00000001,d7

	jmp	(a1) ; TODO: find which segment to use

; ***********************************
; * Generator for line-drawing code *
; ***********************************

; TODO: re-organize registers

; 4 nested loops:
; - direction (outer, 2 values, not necessarily implemented as a loop)
;	stored in d7
; - line size (middle, 17 possible values, expressed as Bresenham steps)
;	stored in d6
; - pixel alignment (inner, 16 possible values)
;	stored in d5
; - row counter
;	stored in d4

; write function pointers in a6
; write code in a5
; Bresenham values in a4

; Bresenham steps in d3
; Address offset in d2
; Pixel x position within word in d1

; temp: pointer to code being written (a0)
; temp: shifted pixel mod 8, as data register number (d0)
; temp: byte-level address from word-level address (d0)

; TODO: eliminate duplicate vertical segments.

fast_line_init:
	lea.l	fl_vi_seg_addr,a6
	lea.l	fl_vi_code,a5
	moveq.l	#1,d7	; x increment. positive = right (top-right)
.loop_direction:
	lea.l	fl_bresenham_patterns,a4
	moveq.l	#16,d6
.loop_line_width:
	move.w	(a4)+,d3 ; Bresenham steps. MSB = bottom.
	moveq.l	#15,d5
.loop_horiz_alignment:
	moveq.l	#15,d4	; line counter
	moveq.l	#0,d2	; address offset to address of end of line
	moveq.l	#15,d1	; x offset within word. 0 = left (MSB)
	sub.w	d5,d1

	move.l	a5,(a6)+

	btst.l	#3,d1
	bne.s	.long_code
	adda.w	#68,a5
	bra.s	.loop_length_ok
.long_code:
	adda.w	#70,a5
.loop_length_ok:
	move.l	a5,a0

	move.w	#%0100111001110101,-(a0)	; RTS
		; ^^^^^^^^^^^^^^^^-------------- RTS

	btst.l	#3,d1
	bne.s	.write_or_loop

	move.l	d1,d0
	andi.w	#7,d0
	swap	d0
	lsr.l	#7,d0
	or.w	#%1000000100010000,d0	; OR.b Dn,(A0)
		; ^^^^------------------ OR
		;     ^^^--------------- Dn
		;        ^^^------------ .b Dn,<ea>
		;           ^^^--------- (An)
		;              ^^^------ A0
	move.w	d0,-(a0)
	bra.s	.or_written

.write_or_loop:
	move.w	d2,d0
	btst.l	#3,d1
	beq.s	.address_adjusted
	addq.w	#1,d0
.address_adjusted:
	move.w	d0,-(a0)		; d16

	move.l	d1,d0
	andi.w	#7,d0
	swap	d0
	lsr.l	#7,d0
	or.w	#%1000000100101000,d0	; OR.b D0,d16(A0)
		; ^^^^------------------ OR
		;     ^^^--------------- D0
		;        ^^^------------ .b Dn,<ea>
		;           ^^^--------- d16(An)
		;              ^^^------ A0
	move.w	d0,-(a0)

.or_written:
	btst.l	d4,d3
	beq.s	.bresenham_done
	add.w	d7,d1
	bmi.s	.underflow
	btst.l	#4,d1
	beq.s	.word_address_ok
	andi.w	#15,d1
	addq.w	#8,d2
	bra.s	.word_address_ok
.underflow:
	andi.w	#15,d1
	subq.w	#8,d2
.word_address_ok:
.bresenham_done:
	sub	#160,d2
	dbra	d4,.write_or_loop

	neg.w	d2
	move.w	d2,-(a0)			; <data>
	move.w	#%1101000011111100,-(a0)	; ADDA.w #<data>,A0
		; ^^^^-------------------------- ADD/ADDA
		;     ^^^----------------------- A0
		;        ^^^-------------------- .w
		;           ^^^^^^-------------- #<data>

	dbra	d5,.loop_horiz_alignment
	dbra	d6,.loop_line_width
	tst.w	d7
	bpl.s	.second_direction

	rts
.second_direction:
	moveq.l	#-1,d7
	bra	.loop_direction

	.data

; 17 Bresenham patterns, n x 16 pixels for n between 0 and 16 inclusive.
; This is too small to be worth computing on the fly.
fl_bresenham_patterns:
	dc.w	%0000000000000000
	dc.w	%0000000100000000
	dc.w	%0001000000010000
	dc.w	%0010000100000100
	dc.w	%0100010001000100
	dc.w	%0100100100010010
	dc.w	%0101001001010010
	dc.w	%0101010100101010
	dc.w	%1010101010101010
	dc.w	%1010101101010101
	dc.w	%1011010110110101
	dc.w	%1011011101101101
	dc.w	%1101110111011101
	dc.w	%1101111101111011
	dc.w	%1111011111110111
	dc.w	%1111111101111111
	dc.w	%1111111111111111
