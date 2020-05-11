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

; This is the userland bootstrap code. Invoke the actual demo code as a
; s(o)upervisor subroutine, and exit back to the OS when that returns
user_start:
	pea	soup
	move.w	#38,-(sp)
	trap	#14
	addq.l	#6,sp
	move.w	#0,-(sp)
	trap	#1

; Start of supervisor code
soup:
; Check that we're in supervisor mode, on a color monitor, exit otherwise
	move.w	sr,d0
	btst.l	#13,d0
	beq.s	.setup_wrong
; TODO: try testing MFP I/O bit 7
	btst.b	#1,$ffff8260.w ; bug in Hatari where this doesn't trigger?
	beq.s	soup2
.setup_wrong:
	rts

; This is the actual start of the demo
soup2:
; Clear BSS
	lea.l	start_bss,a0
	lea.l	end_bss,a1
.clear_bss:
	clr.b	(a0)+
	cmp.l	a0,a1
	bne.s	.clear_bss

; Save status register, disable all interrupts
	move.w	sr,save_sr
	move.w	#$2700,sr

; Set up stack
	move.l	sp,save_stack
	lea.l	stack_top,sp

; Save palette, paint it black
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	lea.l	my_palette,a2
	moveq.l	#15,d0
.copy_palette:
	move.w	(a0),(a1)+
	move.w	(a2)+,(a0)+
	dbra.w	d0,.copy_palette

; Save and set graphics state. It's a European demo, 50Hz FTW
	move.b	$ffff8260.w,save_fb_res
	move.b	$ffff820a.w,save_fb_sync
	move.b	$ffff8201.w,save_fb_high_addr
	move.b	$ffff8203.w,save_fb_low_addr
	move.b	#0,$ffff8260.w
	move.b	#2,$ffff820a.w

; Save MFP enable status, disable all MFP interrupts, set auto-clear
	move.b	$fffffa07.w,save_mfp_enable_a
	clr.b	$fffffa07.w
	move.b	$fffffa09.w,save_mfp_enable_b
	clr.b	$fffffa09.w
	move.b	$fffffa17.w,save_mfp_vector
	move.b	#$40,$fffffa17.w

; Save and set up MFP timer B
; Unmask timer b (this masks other unused ones as a side effect)
	move.b	$fffffa13.w,save_mfp_mask_a
	move.b	#1,$fffffa13.w

; Set the timer b to count events, to fire on every event
	move.b	$fffffa1b.w,save_mfp_timer_b_control
	move.b	#8,$fffffa1b.w
	move.b	$fffffa21.w,save_mfp_timer_b_data
	move.b	#1,$fffffa21.w

; Save interrupt vectors, set ours
	move.l	$70.w,save_vbl
	move.l	$120.w,save_hbl
	move.l	#vbl,$70.w
	move.l	#hbl,$120.w

; Set up our framebuffers
	move.l	#raw_buffer+255,d0
	clr.b	d0
	move.l	d0,back_buffer
	add.l	#32000,d0
	move.l	d0,front_buffer
	move.b	front_buffer+1,$ffff8201.w
	move.b	front_buffer+2,$ffff8203.w

; Generate line-drawing code
	jsr	generate_fast_line_code

; Enable interrupts
;	move.b	#1,$fffffa07.w
	move #$2300,sr

main_loop:
	move.l	back_buffer,a1
	addq.l	#2,a1
	clr.w	d0
	moveq	#99,d1
clear_screen:
	move.w	d0,(a1)
	move.w	d0,8(a1)
	move.w	d0,16(a1)
	move.w	d0,24(a1)
	move.w	d0,32(a1)
	move.w	d0,40(a1)
	move.w	d0,48(a1)
	move.w	d0,56(a1)
	move.w	d0,64(a1)
	move.w	d0,72(a1)
	move.w	d0,80(a1)
	move.w	d0,88(a1)
	move.w	d0,96(a1)
	move.w	d0,104(a1)
	move.w	d0,112(a1)
	move.w	d0,120(a1)
	move.w	d0,128(a1)
	move.w	d0,136(a1)
	move.w	d0,144(a1)
	move.w	d0,152(a1)

	move.w	d0,160(a1)
	move.w	d0,160+8(a1)
	move.w	d0,160+16(a1)
	move.w	d0,160+24(a1)
	move.w	d0,160+32(a1)
	move.w	d0,160+40(a1)
	move.w	d0,160+48(a1)
	move.w	d0,160+56(a1)
	move.w	d0,160+64(a1)
	move.w	d0,160+72(a1)
	move.w	d0,160+80(a1)
	move.w	d0,160+88(a1)
	move.w	d0,160+96(a1)
	move.w	d0,160+104(a1)
	move.w	d0,160+112(a1)
	move.w	d0,160+120(a1)
	move.w	d0,160+128(a1)
	move.w	d0,160+136(a1)
	move.w	d0,160+144(a1)
	move.w	d0,160+152(a1)
	add.w	#320,a1
	dbra	d1,clear_screen

	move.w	#$700,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

	lea.l	scroller_text,a0
	add.w	text_position,a0
	move.l	back_buffer,a1

	move.w	text_sub_position,d1

	lea.l	font,a2
	moveq.l	#0,d2
	move.b	(a0)+,d2
	sub.w	#32,d2
	lsl.w	#5,d2
	add.w	d2,a2
	move	d1,d2
	lsl.w	#1,d2
	add.w	d2,a2

	move.w	#199,d0

.loop_text:
	addq.w	#1,d1
	cmp.w	#16,d1
	bne.s	.draw_line
	moveq.l	#0,d1
	lea.l	font,a2
	moveq.l	#0,d2
	move.b	(a0)+,d2
	sub.w	#32,d2
	lsl.w	#5,d2
	add.w	d2,a2
.draw_line:
	move.w	(a2)+,(a1)
	add.w	#160,a1
	dbra	d0,.loop_text

	addq.w	#1,text_sub_position
	cmp.w	#16,text_sub_position
	bne.s	.done_scroll
	clr.w	text_sub_position
	addq.w	#1,text_position
	cmp.w	#end_text-scroller_text,text_position
	bne.s	.done_scroll
	clr.w	text_position
.done_scroll:

	move.w	#240,d0
	move.w	#100,d1
	move.w	#240+36,d2
	move.w	#100+72,d3
	bsr	draw_fast_line

	move.w	#240,d0
	move.w	#100,d1
	move.w	#240+36,d2
	move.w	#100-72,d3
	bsr	draw_fast_line

	move.w	#160,d0	; x1
	move.w	#100,d1	; y1
	move.w	line_end_x,d2	; x2
	move.w	line_end_y,d3	; y2
	bsr	draw_line

	cmp.w	#0,line_end_x
	beq.s	.left_side
	cmp.w	#199,line_end_y
	beq.s	.bottom_side
	cmp.w	#319,line_end_x
	beq.s	.right_side
	bra.s	.top_side
.left_side:
	cmp.w	#0,line_end_y
	beq.s	.top_side
	subq.w	#1,line_end_y
	bra.s	.line_moved
.bottom_side:
	subq.w	#1,line_end_x
	bra.s	.line_moved
.right_side:
	addq.w	#1,line_end_y
	bra.s	.line_moved
.top_side:
	addq.w	#1,line_end_x
.line_moved:

	movea.l	#sin_table_1024_32768,a0
	move.w	square_rotation,d4
	addi.w	#256,d4
	andi.w	#1023,d4
	add.w	d4,d4
	moveq	#96,d0
	muls	(a0,d4),d0
	add.l	d0,d0
	swap	d0
	move.w	d0,square_cos

	move.w	square_rotation,d4
	add.w	d4,d4
	moveq	#96,d1
	muls	(a0,d4),d1
	add.l	d1,d1
	swap	d1
	move.w	d1,square_sin


	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	add.w	square_cos,d0
	sub.w	square_sin,d1
	add.w	square_sin,d2
	add.w	square_cos,d3
	bsr	draw_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	add.w	square_sin,d2
	add.w	square_cos,d3
	sub.w	square_cos,d0
	add.w	square_sin,d1
	bsr	draw_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	sub.w	square_cos,d0
	add.w	square_sin,d1
	sub.w	square_sin,d2
	sub.w	square_cos,d3
	bsr	draw_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	sub.w	square_sin,d2
	sub.w	square_cos,d3
	add.w	square_cos,d0
	sub.w	square_sin,d1
	bsr	draw_line


	move.w	square_rotation,d0
	addq.w	#7,d0
	and.w	#1023,d0
	move.w	d0,square_rotation

	move.w	#$070,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

; prototype 2D-texture-mapped polygon drawing

	movea.l	#user_start,a0

	movea.l	back_buffer,a1
	adda.w	#52,a1

	.rept 64

	move.w	(a0)+,d0
	andi.w	#$3c3c,d0
	move.w	d0,(a1)
	move.w	(a0)+,d0
	andi.w	#$3c3c,d0
	move.w	d0,8(a1)
	adda.w	#20,a0
	adda.w	#160,a1

	.endr

; Swap framebuffers
	move.l	back_buffer,d0
	move.l	front_buffer,back_buffer
	move.l	d0,front_buffer
	lsr.w	#8,d0
	move.b	d0,$ffff8203.w
	swap.w	d0
	move.b	d0,$ffff8201.w

	move.w	#$777,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

; Wait for next VBL
	clr.b	vbl_reached
.waitvbl:
	stop	#$2300
	tst.b	vbl_reached
	beq.s	.waitvbl
; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	beq.s	.exit
	bra	main_loop
.exit:

; Disable interrupts
	move.w	#$2700,sr
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w

; Restore interrupt vectors
	move.l	save_vbl,$70.w
	move.l	save_hbl,$120.w

; Restore MFP status
	move.b	save_mfp_timer_b_control,$fffffa1b.w
	move.b	save_mfp_timer_b_data,$fffffa21.w
	move.b	save_mfp_mask_a,$fffffa13.w
	move.b	save_mfp_vector,$fffffa17.w
	move.b	save_mfp_enable_a,$fffffa07.w
	move.b	save_mfp_enable_b,$fffffa09.w

; Restore graphics status
	move.b	save_fb_sync,$ffff820a.w
	move.b	save_fb_res,$ffff8260.w
	move.b	save_fb_high_addr,$ffff8201.w
	move.b	save_fb_low_addr,$ffff8203.w

; Clear current framebuffer to avoid flashing on exit
	move.l	front_buffer,a0
	move.w	#7999,d0
.clear_fb_exit:
	clr.l	(a0)+
	dbra	d0,.clear_fb_exit

; Restore palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.restore_palette:
	move.w	(a1)+,(a0)+
	dbra.w	d0,.restore_palette

; Restore stack
	move.l	save_stack,sp

; Restore status register, exit
	move.w	save_sr,sr
	rts

vbl:
	move.b	#1,vbl_reached
	move.w	#0,raster_color
	rte

hbl:
	add.w	#$71,raster_color
	move.w	raster_color,$ffff8240.w
	rte

; ===========================================================================

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
	move.l	back_buffer,a0 ; TODO: pass framebuffer address as parameter
	mulu.w	#160,d1
	lea.l	(a0,d1.w),a0
	move.w	d0,d1
	lsr.w	#1,d0
	and.w	#248,d0
	lea.l	2(a0,d0.w),a0 ; TODO: remove offset when address is param
	move.w	#$8000,d5 ; pixel pattern
	and	#15,d1
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

; ===========================================================================

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
	bge.s	fast_vertical_ish ; d5>=d4, abs(y1-y2)>=abs(x1-x2)
	bra.s	fast_horizontal_ish

; Draw vertical line
fast_vertical:
	rts
; Draw horizonal line
fast_horizontal:
	rts
; Draw diagonal line
fast_diagonal:
	rts
; Draw horizonal_ish line
fast_horizontal_ish:
	rts

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

fast_vertical_ish:

	cmp.w	d1,d3
	ble.s	.ends_ordered	; d3<=d1
	exg	d0,d2
	exg	d1,d3
.ends_ordered:	; from this point the ends are in order, d1>=d3.
	move.w	d1,d5
	sub.w	d3,d5	; d5 is delta-y, guaranteed to be positive
	move.w	d2,d4
	sub.w	d0,d4	; d4 is delta-x
	bpl.s	.positive_slope
	neg.w	d4	; TODO: remember that we're drawing in the other direction
.positive_slope:	; d4 and d5 are positive delta-x and delta-y
	swap.w	d4
	clr.w	d4
	divu.w	d5,d4	; TODO: don't compute the slope for small lines
	swap.w	d4
	clr.w	d4
	swap.w	d4
	lsl.l	#4,d4	; d4 is the Bresenham step for 16 pixels, stored as
			; 16:16, with 12 significant fractional bits

; At the end, need to figure out the coordinates of the last point of
; the first (partial) segment, and need to figure out the size of that
; segment.

; The coordinates of the last point of the line aren't important to keep.
; The x value of the last point of the segment to process is important.
; Chances are, it's in the upper bits of the Bresenham accumulator.

; How to best determine how many lines to draw?
; d5 is delta-y, easy to decrement by 16 and test for small numbers

.next_segment:
	cmp.w	#16,d5 ; getting close to the end of the line?
	blt.s	.last_segment
	sub.w	#16,d5
	pea	df_lcode ; TODO: find which segment to use
	bra.s	.next_segment
.last_segment:
	add.w	d5,d3
	mulu.w	#160,d3
	movea.l	back_buffer,a0	; TODO: get as parameter
	andi.w	#$fff0,d2	; TODO: d2 is NOT the proper x coordinate
	lsr.w	d2
	add.w	d2,d3
	addq.w	#2,d3		; TODO: remove once address is a parameter
	adda.w	d3,a0

	add.w	d5,d5
	add.w	d5,d5
	lea.l	df_lcode+64,a1
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

generate_fast_line_code:
	lea.l	df_lcode,a2

	move	#-150*16,d2
	moveq	#15,d7

	move.w	#%1101000011111100,(a2)+	; ADDA.w #<data>,A0
		; ^^^^                  ADD/ADDA
		;     ^^^               A0
		;        ^^^            .w
		;           ^^^^^^      #<data>
	move.w	#160*16,(a2)+			; <data>

.write_or_loop:
	tst.w	d2
	bne.s	.relative_address

	move.w	#%1000000100010000,(a2)+	; OR.b D0,(A0)
		; ^^^^----------------- OR
		;     ^^^-------------- D0
		;        ^^^----------- .b Dn,<ea>
		;           ^^^-------- (An)
		;              ^^^----- A0

.relative_address:
	move.w	#%1000000100101000,(a2)+	; OR.b D0,d16(A0)
		; ^^^^                  OR
		;     ^^^               D0
		;        ^^^            .b Dn,<ea>
		;           ^^^         d16(An)
		;              ^^^      A0
	move.w	d2,(a2)+			; d16

.or_written:
	add	#160,d2
	dbra	d7,.write_or_loop

	move.w	#%0100111001110101,(a2)+	; RTS
		; ^^^^^^^^^^^^^^^^	RTS

	rts

; Initialized data
	.data
my_palette:
	dc.w	0,$657,$741,$741,$275,$275,$275,$275,0,0,0,0,0,0,0,0

font:
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000
	dc.w	%0000000000000000

	dc.w	%0000000000000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000000000000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000001111000000
	dc.w	%0000000000000000

	.include "sin_table_1024_32768.s"

scroller_text:
	dc.b	"              "
	dc.b	"! ! !   !!! !!! !!!   ! ! !"
end_text:
	dc.b	"              "

; Uninitialized memory
	.bss
start_bss:

save_stack:
	ds.l	1
save_hbl:
	ds.l	1
save_vbl:
	ds.l	1
front_buffer:
	ds.l	1
back_buffer:
	ds.l	1

raster_color:
	ds.w	1

text_position:
	ds.w	1
text_sub_position:
	ds.w	1

line_end_x:
	ds.w	1
line_end_y:
	ds.w	1

square_rotation:
	ds.w	1
square_cos:
	ds.w	1
square_sin:
	ds.w	1

save_sr:
	ds.w	1
save_palette:
	ds.w	16

save_mfp_enable_a:
	ds.b	1
save_mfp_enable_b:
	ds.b	1
save_mfp_mask_a:
	ds.b	1
save_mfp_vector:
	ds.b	1
save_mfp_timer_b_control:
	ds.b	1
save_mfp_timer_b_data:
	ds.b	1
save_fb_low_addr:
	ds.b	1
save_fb_high_addr:
	ds.b	1
save_fb_res:
	ds.b	1
save_fb_sync:
	ds.b	1

vbl_reached:
	ds.b	1

	.even
stack_bottom:
	ds.b	1024
stack_top:

	.even
raw_buffer:
	ds.b	32000*9+254

dl_seg_l_w	== raw_buffer+254+32000+32000
dl_seg_l_p	== dl_seg_l_w+1088	; 1088 is 17*16*4
df_lcode	== dl_seg_l_p+1088

end_bss:
