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


; Swap framebuffers
	move.l	back_buffer,d0
	move.l	front_buffer,back_buffer
	move.l	d0,front_buffer
	lsr.w	#8,d0
	move.b	d0,$ffff8203.w
	swap.w	d0
	move.b	d0,$ffff8201.w

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
	ds.b	32000+32000+255

end_bss:
