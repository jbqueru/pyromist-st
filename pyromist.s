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
	move.l	#raw_fb+255,d0
	clr.b	d0
	move.l	d0,back_buffer
	add.l	#32000,d0
	move.l	d0,front_buffer
	move.b	front_buffer+1,$ffff8201.w
	move.b	front_buffer+2,$ffff8203.w

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

	bsr	draw_fast_line
	bsr	draw_faster_line

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

; Line-drawing routine
draw_line:
; Get line coordinates in (d0,d1) and (d2,d3)

; Swap line ends if necessary so that d0 >= d2, to draw lines right-to-left
; Drawing right-to-left is faster, because the fastest way to shift a 16-bit
; register by 1 is to add it to itself, but that only works to the left
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
; Adjust delta-y to be positive, negative values move in the other direction between lines
	bge.s	.adjusted_dy ; d3 >= d1
	neg.w	d3
	neg.w	d4
.adjusted_dy:

; d0,d1 are x,y of the left end
; d2,d3 are the pixel offset to the right end, both positive
; d4 is the address offset when changing lines.

; Compute start address and start pixel pattern
	move.l	back_buffer,a0
	mulu.w	#160,d1
	lea.l	(a0,d1.w),a0
	move.w	d0,d1
	lsr.w	#1,d0
	and.w	#248,d0
	lea.l	2(a0,d0.w),a0
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

; Skeleton for fast line drawing (by segments) for vertical-ish lines

; It's faster to draw lines right to left when drawing one pixel at a time.

; When running a partial routine, it's easier to execute only the end
; (by jumping in the middle of the code) than only the begninning
; (because that requires patching the code then fixing the patch).

; As a consequence, it's easier to anchor on the address at the end of the
; segment, because that way it's always pointing to a pixel drawn in that
; segment even when drawing a partial segment.

; If the segments are less than 17 pixels wide, they all fit within 2 pixel
; blocks, so that there's only 1 address change in the middle of the block.
; If the starting pixel was already drawn by the previous segment, that only
; allows 16 pixels of width, and from there 16 pixels of height at 45 degrees.
; 16 high is convenient for multiplications (when computing or processing
; the slope.

; Segments of 16 high
; Start drawing from the right side
; Start long line with partial segment
; After a segment, address (and mask) point to the last pixel
; (i.e. the last instruction of a segment is typically "or.w d0,(a0)"
; The beginning of a full segment updates the address.
; The various computations must go from the outer corners of the pixels
; (in the general direction of the line)

draw_fast_line:
	move.l	back_buffer,a0

; This computes the address of the first pixel
	adda.w	#162,a0
	moveq.l	#1,d0
; There's magic here, jump in the middle of the segment
	adda.w	#160*15-8,a0
	bsr.s	draw_vseg_d_8_0_0

	bsr.s	draw_vseg_d_8_8
	bsr.s	draw_vseg_d_8_0
	bsr.s	draw_vseg_d_8_8
	bsr.s	draw_vseg_d_8_0
	bsr.s	draw_vseg_d_8_8
	bsr.s	draw_vseg_d_8_0
	bsr.s	draw_vseg_d_8_8
	bsr.s	draw_vseg_d_8_0
	bsr.s	draw_vseg_d_8_8
	bsr.s	draw_vseg_d_8_0
	bsr.s	draw_vseg_d_8_8
	rts

; This segment is moves down when moving left
; This segment moves left by 8 pixels over its entire length
; This segment assumes that the previous pixel was at offset 0
draw_vseg_d_8_0:
	adda.w	#160*16-8,a0
	moveq.l	#1,d0

; Jump before drawing pixel #0
draw_vseg_d_8_0_0:
	or.w	d0,-15*160(a0)
; Jump before drawing pixel #1
draw_vseg_d_8_0_1:
	or.w	d0,-14*160(a0)
	add.w	d0,d0
	or.w	d0,-13*160(a0)
	or.w	d0,-12*160(a0)
	add.w	d0,d0
	or.w	d0,-11*160(a0)
	or.w	d0,-10*160(a0)
	add.w	d0,d0
	or.w	d0,-9*160(a0)
	or.w	d0,-8*160(a0)
	add.w	d0,d0
	or.w	d0,-7*160(a0)
	or.w	d0,-6*160(a0)
	add.w	d0,d0
	or.w	d0,-5*160(a0)
	or.w	d0,-4*160(a0)
	add.w	d0,d0
	or.w	d0,-3*160(a0)
	or.w	d0,-2*160(a0)
	add.w	d0,d0
	or.w	d0,-1*160(a0)
draw_vseg_d_8_0_15a:
draw_vseg_d_8_0_16b:
	or.w	d0,(a0)
	rts

draw_vseg_d_8_8:
	adda.w	#160*16,a0
	add.w	d0,d0
	or.w	d0,-15*160(a0)
	or.w	d0,-14*160(a0)
	add.w	d0,d0
	or.w	d0,-13*160(a0)
	or.w	d0,-12*160(a0)
	add.w	d0,d0
	or.w	d0,-11*160(a0)
	or.w	d0,-10*160(a0)
	add.w	d0,d0
	or.w	d0,-9*160(a0)
	or.w	d0,-8*160(a0)
	add.w	d0,d0
	or.w	d0,-7*160(a0)
	or.w	d0,-6*160(a0)
	add.w	d0,d0
	or.w	d0,-5*160(a0)
	or.w	d0,-4*160(a0)
	add.w	d0,d0
	or.w	d0,-3*160(a0)
	or.w	d0,-2*160(a0)
	add.w	d0,d0
	or.w	d0,-1*160(a0)
	or.w	d0,(a0)
	rts

; A highly optimized approach to drawing lines.

; Compared to traditional approaches, this eliminates the need to shift
; a bit to match pixel locations, by using all 8 data registers to
; match the 8 bit positions in a byte.

; Each segment

draw_faster_line:
	move.l	back_buffer,a0

; This computes the address of the first pixel
	add.w	#10,a0

	moveq.l	#%10000000,d0
	moveq.l	#%01000000,d1
	moveq.l	#%00100000,d2
	moveq.l	#%00010000,d3
	moveq.l	#%00001000,d4
	moveq.l	#%00000100,d5
	moveq.l	#%00000010,d6
	moveq.l	#%00000001,d7

; There's magic here, jump in the middle of the segment
	adda.w	#160*15,a0
	bsr.s	draw_vf_d_8_0_16

	bsr.s	draw_vf_d_8_8
	bsr.s	draw_vf_d_8_0
	bsr.s	draw_vf_d_8_8

	rts

;	jsr	draw_vf_d_8_0		; 3 words, 5 nops
draw_vf_d_8_0:
	adda.w	#160*16+8,a0		; 2 words, 3 nops
draw_vf_d_8_0_16:
	or.b	d0,-15*160(a0)		; 2 words, 4 nops
	or.b	d0,-14*160(a0)		; 2 words, 4 nops
	or.b	d1,-13*160(a0)		; 2 words, 4 nops
	or.b	d1,-12*160(a0)		; 2 words, 4 nops
	or.b	d2,-11*160(a0)		; 2 words, 4 nops
	or.b	d2,-10*160(a0)		; 2 words, 4 nops
	or.b	d3,-9*160(a0)		; 2 words, 4 nops
	or.b	d3,-8*160(a0)		; 2 words, 4 nops
	or.b	d4,-7*160(a0)		; 2 words, 4 nops
	or.b	d4,-6*160(a0)		; 2 words, 4 nops
	or.b	d5,-5*160(a0)		; 2 words, 4 nops
	or.b	d5,-4*160(a0)		; 2 words, 4 nops
	or.b	d6,-3*160(a0)		; 2 words, 4 nops
	or.b	d6,-2*160(a0)		; 2 words, 4 nops
	or.b	d7,-1*160(a0)		; 2 words, 4 nops
	or.b	d7,(a0)			; 1 word, 3 nops
	rts				; 1 word, 4 nops

; 2 + 15*2 + 1 + 1 = 34 words
; 5 + 3 + 15*4 + 3 + 4 = 75 nops

;	jsr	draw_vf_d_8_8		; 3 words, 5 nops
draw_vf_d_8_8:
	adda.w	#160*16,a0		; 2 words, 3 nops
	or.b	d0,-15*160+1(a0)	; 2 words, 4 nops
	or.b	d0,-14*160+1(a0)	; 2 words, 4 nops
	or.b	d1,-13*160+1(a0)	; 2 words, 4 nops
	or.b	d1,-12*160+1(a0)	; 2 words, 4 nops
	or.b	d2,-11*160+1(a0)	; 2 words, 4 nops
	or.b	d2,-10*160+1(a0)	; 2 words, 4 nops
	or.b	d3,-9*160+1(a0)		; 2 words, 4 nops
	or.b	d3,-8*160+1(a0)		; 2 words, 4 nops
	or.b	d4,-7*160+1(a0)		; 2 words, 4 nops
	or.b	d4,-6*160+1(a0)		; 2 words, 4 nops
	or.b	d5,-5*160+1(a0)		; 2 words, 4 nops
	or.b	d5,-4*160+1(a0)		; 2 words, 4 nops
	or.b	d6,-3*160+1(a0)		; 2 words, 4 nops
	or.b	d6,-2*160+1(a0)		; 2 words, 4 nops
	or.b	d7,-1*160+1(a0)		; 2 words, 4 nops
	or.b	d7,1(a0)		; 2 words, 4 nops
	rts

; 2 + 16*2 + 1 = 35 words
; 5 + 3 + 16*4 + 4 = 76 nops

; Initialized data
	.data
my_palette:
	dc.w	0,$657,$741,$741,0,0,0,0,0,0,0,0,0,0,0,0

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
	ds.b	512
stack_top:

raw_fb:
	ds.b	32000*9+255

end_bss:
