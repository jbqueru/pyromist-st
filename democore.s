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

; Save palette, paint it black
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.copy_palette:
	move.w	(a0),(a1)+
	move.w	#0,(a0)+
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

; Set up threading system

; Save stack
	move.l	sp,save_stack

	lea.l	main_thread_stack_top,sp
	move.b	#1,main_thread_ready

	lea.l	update_thread_stack_top,a0
	move.l	#update_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,update_thread_current_stack

	lea.l	draw_thread_stack_top,a0
	move.l	#draw_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,draw_thread_current_stack

; Enable interrupts
;	move.b	#1,$fffffa07.w
	move #$2300,sr

main_loop:

; Swap framebuffers
; TODO: what if the VBL happens between the two writes?
;	move.l	back_buffer,d0
;	move.l	front_buffer,back_buffer
;	move.l	d0,front_buffer
;	lsr.w	#8,d0
;	move.b	d0,$ffff8203.w
;	swap.w	d0
;	move.b	d0,$ffff8201.w

; Wait for next VBL
;.waitvbl:
;	stop	#$2300
;	tst.b	vbl_reached
;	beq.s	.waitvbl

	move.w	#$007,$ffff8240.w
	clr.w	$ffff8240.w

; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	beq.s	.exit

	move.w	#$2700,sr
	jsr	switch_threads

	bra.s	main_loop
.exit:

; Disable interrupts
	move.w	#$2700,sr
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w

; Restore stack
	move.l	save_stack,sp

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

; Restore status register, exit
	move.w	save_sr,sr
	rts

vbl:
	move.b	#1,vbl_reached
	rte

hbl:
	rte

switch_threads:
	move.w	#$2300,-(sp)
	rte

update_thread_entry:
	move.w	#$2700,sr
	clr.b	update_thread_ready
	jsr	switch_threads
	bra.s	update_thread_entry

draw_thread_entry:
	move.w	#$2700,sr
	clr.b	draw_thread_ready
	jsr	switch_threads
	bra.s	draw_thread_entry

; Uninitialized memory
	.bss
start_bss:

save_stack:
	ds.l	1
save_hbl:
	ds.l	1
save_vbl:
	ds.l	1

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

	.even
front_buffer:
	ds.l	1
back_buffer:
	ds.l	1


vbl_reached:
	ds.b	1

	.even
update_thread_current_stack:
	ds.l	1
update_thread_stack_bottom:
	ds.b	1024
update_thread_stack_top:
update_thread_ready:
	ds.b	1

	.even
draw_thread_current_stack:
	ds.l	1
draw_thread_stack_bottom:
	ds.b	1024
draw_thread_stack_top:
draw_thread_ready:
	ds.b	1

	.even
main_thread_current_stack:
	ds.l	1
main_thread_stack_bottom:
	ds.b	1024
main_thread_stack_top:
main_thread_ready:
	ds.b	1

	.even
current_thread:
	ds.l	1

	.even
raw_buffer:
	ds.b	32000*2+254

end_bss:
