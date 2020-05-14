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
	jsr	fast_line_init

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

	bra	done_m_lines

	move.w	#31,d0
	move.w	#0,d1
	move.w	#0,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	bsr	draw_line

	move.w	#37,d0
	move.w	#0,d1
	move.w	#176,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	bsr	draw_line

	move.w	#282,d0
	move.w	#0,d1
	move.w	#143,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	bsr	draw_line

	move.w	#288,d0
	move.w	#0,d1
	move.w	#319,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	bsr	draw_line

	move.w	#$007,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

	move.w	#34,d0
	move.w	#0,d1
	move.w	#3,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#40,d0
	move.w	#0,d1
	move.w	#179,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#279,d0
	move.w	#0,d1
	move.w	#140,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#285,d0
	move.w	#0,d1
	move.w	#316,d2
	move.w	#198,d3
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#$077,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

done_m_lines:

	move.w	#160,d0	; x1
	move.w	#100,d1	; y1
	move.w	line_end_x,d2	; x2
	move.w	line_end_y,d3	; y2
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

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

	move.w	#$707,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

	bra	done_square

	movea.l	#sin_table_1024_32768,a0
	move.w	square_rotation,d4
	addi.w	#256,d4
	andi.w	#1023,d4
	add.w	d4,d4
	moveq	#64,d0
	muls	(a0,d4),d0
	add.l	d0,d0
	swap	d0
	move.w	d0,square_cos

	move.w	square_rotation,d4
	add.w	d4,d4
	moveq	#64,d1
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
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	add.w	square_sin,d2
	add.w	square_cos,d3
	sub.w	square_cos,d0
	add.w	square_sin,d1
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	sub.w	square_cos,d0
	add.w	square_sin,d1
	sub.w	square_sin,d2
	sub.w	square_cos,d3
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line

	move.w	#160,d2
	move.w	#100,d3
	move.w	d2,d0
	move.w	d3,d1
	sub.w	square_sin,d2
	sub.w	square_cos,d3
	add.w	square_cos,d0
	sub.w	square_sin,d1
	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line


	move.w	square_rotation,d0
	addq.w	#7,d0
	and.w	#1023,d0
	move.w	d0,square_rotation

	move.w	#$070,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

done_square:

	lea.l	sin_table_1024_32768,a0

	move.w	cube_rotation_y,d7
	addi.w	#256,d7
	andi.w	#1023,d7
	add.w	d7,d7
	move	(a0,d7.w),d0

	move.w	cube_rotation_y,d7
	add.w	d7,d7
	move	(a0,d7.w),d1

	move.w	cube_rotation_z,d7
	addi.w	#256,d7
	andi.w	#1023,d7
	add.w	d7,d7
	move	(a0,d7.w),d2

	move.w	cube_rotation_z,d7
	add.w	d7,d7
	move	(a0,d7.w),d3

; /  d0*d2  d1   d0*d3  \  _x
; | -d1*d2  d0  -d1*d3  |  _y
; \    -d3   0      d2  /  _z
;       x_  y_      z_

	move.w	d0,y_y
	move.w	d1,y_x
	move.w	d2,z_z

	move.w	d0,d6
	muls.w	d3,d6
	swap.w	d6
	add.w	d6,d6
	move.w	d6,z_x

	neg.w	d3
	move.w	d3,x_z

	muls.w	d1,d3
	swap.w	d3
	add.w	d3,d3
	move.w	d3,z_y

	muls.w	d2,d0
	swap.w	d0
	add.w	d0,d0
	move.w	d0,x_x

	muls.w	d2,d1
	swap.w	d1
	add.w	d1,d1
	neg.w	d1
	move.w	d1,x_y

	move.w	#$770,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

	move.w	#64,d4
	move.w	d4,d5
	move.w	d4,d6
	muls.w	x_x,d4	; x*32k
	asr.l	#8,d4	; x*128 (good for range -255..255)
	muls.w	x_y,d5	; y*32k
	asr.l	#8,d5	; y*128 (good for range -255..255)
	muls.w	x_z,d6	; z*32k
	asr.l	#8,d6	; z*128 (good for range -255..255)
	asr.l	#7,d6	; z
	add.w	#128,d6

	move.l	d4,d0
	divs.w	d6,d0
	add.w	#160,d0
	move.l	d5,d1
	divs.w	d6,d1
	add.w	#100,d1

	move.w	#64,d4
	move.w	d4,d5
	move.w	d4,d6
	muls.w	y_x,d4	; x*32k
	asr.l	#8,d4	; x*128 (good for range -255..255)
	muls.w	y_y,d5	; y*32k
	asr.l	#8,d5	; y*128 (good for range -255..255)
	muls.w	y_z,d6	; z*32k
	asr.l	#8,d6	; z*128 (good for range -255..255)
	asr.l	#7,d6	; z
	add.w	#128,d6

	move.l	d4,d2
	divs.w	d6,d2
	add.w	#160,d2
	move.l	d5,d3
	divs.w	d6,d3
	add.w	#100,d3

	bra.s	.ok_all

	tst.w	d0
	bpl.s	.ok1
	clr.w	d0
.ok1:
	cmp.w	#319,d0
	ble.s	.ok2
	move.w	#319,d0
.ok2:
	tst.w	d1
	bpl.s	.ok3
	clr.w	d1
.ok3:
	cmp.w	#199,d1
	ble.s	.ok4
	move.w	#199,d1
.ok4:
	tst.w	d2
	bpl.s	.ok5
	clr.w	d2
.ok5:
	cmp.w	#319,d2
	ble.s	.ok6
	move.w	#319,d2
.ok6:
	tst.w	d3
	bpl.s	.ok7
	clr.w	d3
.ok7:
	cmp.w	#199,d3
	ble.s	.ok8
	move.w	#199,d3
.ok8:
.ok_all:

	move.w	#$770,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

	movea.l	back_buffer,a0
	addq.l	#2,a0
	bsr	draw_fast_line


	move.w	cube_rotation_y,d0
	addq.w	#5,d0
	and.w	#1023,d0
	move.w	d0,cube_rotation_y

	move.w	cube_rotation_z,d0
	addq.w	#3,d0
	and.w	#1023,d0
	move.w	d0,cube_rotation_z

	move.w	#$770,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

; prototype 2D-texture-mapped polygon drawing

	movea.l	#user_start,a0

	movea.l	back_buffer,a1
	adda.w	#76,a1

	.rept 32

	move.w	(a0)+,d0
	andi.w	#$3ffc,d0
	move.w	d0,(a1)
	move.w	(a0)+,d0
	andi.w	#$a5a5,d0
	move.w	d0,8(a1)
	adda.w	#20,a0
	adda.w	#160,a1

	.endr

	move.w	#$777,$ffff8240.w
	.rept	124
	nop
	.endr
	move.w	#0,$ffff8240.w

; Swap framebuffers
; TODO: what if the VBL happens between the two writes?
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
	move.l	back_buffer,a1
	move.w	#7999,d0
.clear_fb_exit:
	clr.l	(a0)+
	clr.l	(a1)+
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
	rte

hbl:
	rte

; ===========================================================================

	.include "drawline.s"

; ===========================================================================

	.include "fastline.s"

; ===========================================================================

	.text
; Initialized data
	.data
my_palette:
	dc.w	0,$657,$741,$741,$275,$275,$275,$275,0,0,0,0,0,0,0,0

	.include "sin_table_1024_32768.s"

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

cube_rotation_y:
	ds.w	1
cube_rotation_z:
	ds.w	1

x_x:
	ds.w	1
x_y:
	ds.w	1
x_z:
	ds.w	1
y_x:
	ds.w	1
y_y:
	ds.w	1
y_z:
	ds.w	1
z_x:
	ds.w	1
z_y:
	ds.w	1
z_z:
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

; addresses for fast line-drawing code

fl_vi_seg_addr	== raw_buffer+254+32000+32000
fl_vi_code	== fl_vi_seg_addr+2176		; 34*16*4
end_fl_vi_code	== fl_vi_code + 38080		; 34*16*70 (~1600 to squeeze?)

end_bss:
