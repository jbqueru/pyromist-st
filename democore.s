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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                       ;;;
;;; This is the kernel of the demo                                        ;;;
;;; This includes:                                                        ;;;
;;;   * Machine setup                                                     ;;;
;;;   * Interrupts                                                        ;;;
;;;   * Threading                                                         ;;;
;;;   * Inputs                                                            ;;;
;;;   * Page flipping                                                     ;;;
;;;                                                                       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start of supervisor code.
;
; 1. Check that we're in supervisor mode.
; 2. Check that we're on a color monitor.
; 3. Invoke real code if everything is fine.
;
; This routine doesn't change any state. Therefore, if we trust everything
; to be set up correctly, it can be skipped in theory.
;
; TODO: investigate whether to check the MFP pin for monochrome monitor.
;;;;;;;;
core_main_super:
	; Check for supervisor mode
	move.w	sr,d0
	btst.l	#13,d0		; bit #13 of SR is supervisor ($2000)
	beq.s	.exit		; bit = 0 : we're not in supervisor, exit

	; Check for color monitor
	btst.b	#1,$ffff8260.w	; bit #1 of $8260.w is monochrome mode ($02)
	bne.s	.exit		; bit != 0 : we're in monochrome, exit

	bsr.s	core_main	; invoke inner code.
.exit:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; True entry point of the demo code.
; This is the first active code that is used in all environments.
;
; 1. Clear BSS.
; 2. Set up stack.
; 3. Invoke inner code.
; 4. Restore stack.
;
; The stack setup is difficult to separate in subroutines.
; Note: this routine assumes that there's already enough stack set up to
; invoke a subroutine.
;;;;;;;;
core_main:
	; This has to come first, before anything gets saved to BSS
	bsr.s	core_bss_clear

	; Save stack
	move.l	sp,save_stack

	; Set up our stack
	lea.l	main_thread_stack_top,sp

	; Invoke real code
	bsr.s	core_main_inner

	; Restore stack
	move.l	save_stack,sp

	; Exit
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This is the actual start of the demo.
;;;;;;;;
core_main_inner:
	bsr.s	core_int_save_setup
	bsr	core_gfx_save_setup
	bsr	core_thr_setup
	bsr	core_int_enable

	bsr	main_thread_entry

	bsr	core_int_disable
	bsr	core_gfx_restore
	bsr	core_int_restore
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clear the BSS
;
; Caution: this makes assumptions about the way source files are organized,
;	all included source files must be between start_bss and end_bss
;;;;;;;;
core_bss_clear:
	lea.l	start_bss,a0
	lea.l	end_bss,a1
.clear_bss:
	clr.b	(a0)+
	cmp.l	a0,a1
	bne.s	.clear_bss
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Save and set up interrupts
;;;;;;;;
core_int_save_setup:
	move.w	sr,save_sr
	move.w	#$2700,sr

; Save MFP
; Save enable status
	move.b	$fffffa07.w,save_mfp_enable_a
	move.b	$fffffa09.w,save_mfp_enable_b
	move.b	$fffffa13.w,save_mfp_mask_a
	move.b	$fffffa15.w,save_mfp_mask_b
	move.b	$fffffa17.w,save_mfp_vector
; Save timers
	move.b	$fffffa19.w,save_mfp_timer_a_control
	move.b	$fffffa1f.w,save_mfp_timer_a_data	; ???
	move.b	$fffffa1b.w,save_mfp_timer_b_control
	move.b	$fffffa21.w,save_mfp_timer_b_data	; ???

; Disable all MFP interrupts, set auto-clear
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w
	move.b	#$40,$fffffa17.w

; Save interrupt vectors
	move.l	$68.w,save_hbl
	move.l	$70.w,save_vbl
	move.l	$118.w,save_input
	move.l	$120.w,save_timer_b
	move.l	$134.w,save_timer_a

; Set our interrupt vectors
	lea.l	empty_interrupt,a0
	move.l	a0,$68.w
	move.l	a0,$70.w
	move.l	a0,$118.w
	move.l	a0,$120.w
	move.l	a0,$134.w

; Set up MFP timer B
; Unmask interrupts we use (this masks other unused ones as a side effect)
	move.b	#$21,$fffffa13.w	; unmask timers A and B ($20 and $01)
	move.b	#$40,$fffffa15.w	; unmask keyboard/midi
; Set timer a close to 50 Hz
	clr.b	$fffffa19.w		; timer A off
; Set the timer b to count events, to fire on every event
	clr.b	$fffffa1b.w
	move.b	#1,$fffffa21.w

	stop	#$2300			; in case there's a spurious event
	stop	#$2300

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Enable and sync our interrupts
;;;;;;;;
core_int_enable:
; Sync interrupts

	stop	#$2300			; wait for VBL

	move.b	#$1,$fffffa07.w		; enable timer B
	move.b	#$8,$fffffa1b.w		; set timer B to count events
	move.b	#199,$fffffa21.w	; count to the last line

	stop	#$2300			; wait for last line

	move.b	#200,$fffffa21.w	; count every 200 lines (= 1 screen)
	move.l	#hbl,$120.w		; set up real interrupt routine

	move.b	#$7,$fffffa19.w
	move.b	#246,$fffffa1f.w	; timer A counts 246 events
	move.l	#timer,$134.w
	move.b	#$21,$fffffa07.w

	move.l	#input,$118.w
	move.b	#$40,$fffffa09.w

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Disable our interrupts
;;;;;;;;
core_int_disable:
; Disable MFP
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Restore interrupts
;;;;;;;;
core_int_restore:
	move.w	#$2700,sr
; Restore interrupt vectors
	move.l	save_hbl,$68.w
	move.l	save_vbl,$70.w
	move.l	save_input,$118.w
	move.l	save_timer_b,$120.w
	move.l	save_timer_a,$134.w

; Restore MFP status
	move.b	save_mfp_timer_a_control,$fffffa19.w
	move.b	save_mfp_timer_a_data,$fffffa1f.w
	move.b	save_mfp_timer_b_control,$fffffa1b.w
	move.b	save_mfp_timer_b_data,$fffffa21.w
	move.b	save_mfp_mask_a,$fffffa13.w
	move.b	save_mfp_mask_b,$fffffa15.w
	move.b	save_mfp_vector,$fffffa17.w
	move.b	save_mfp_enable_a,$fffffa07.w
	move.b	save_mfp_enable_b,$fffffa09.w

	move.w	save_sr,sr
	rts

empty_interrupt:
	rte

input:
	btst.b	#7,$fffffc00.w
	beq	.done
	btst.b	#0,$fffffc00.w
	beq	.done
	tst.b	$fffffc02.w
	move.w	#$777,$ffff8240.w
	.rept	124
	nop
	.endr
.done:
	rte

timer:
	move.b	#1,music_thread_ready
	bra.s	switch_from_int

hbl:
	move.b	#1,update_thread_ready
	bra.s	switch_from_int

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set up thread
;;;;;;;;
core_thr_setup:
; Set up threading system
	lea.l	music_thread_stack_top,a0
	move.l	#music_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,music_thread_current_stack

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

	move.l	#main_thread_current_stack,current_thread

	rts

switch_from_int:
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)
	bra.s	switch_and_return

switch_threads:
	move.w	#$2300,-(sp)
	movem.l	d0-a6,-(sp)
	move.l	usp,a0
	move.l	a0,-(sp)

switch_and_return:
	move.l	current_thread,a0
	move.l	sp,(a0)
.try_music_thread:
	tst.b	music_thread_ready
	beq.s	.try_update_thread
	lea.l	music_thread_current_stack,a0
	bra.s	.thread_selected
.try_update_thread:
	tst.b	update_thread_ready
	beq.s	.try_draw_thread
	lea.l	update_thread_current_stack,a0
	bra.s	.thread_selected
.try_draw_thread:
	tst.b	draw_thread_ready
	beq.s	.use_main_thread
	lea.l	draw_thread_current_stack,a0
	bra.s	.thread_selected
.use_main_thread:
	lea.l	main_thread_current_stack,a0
.thread_selected:
	move.l	(a0),sp
	move.l	a0,current_thread
	move.l	(sp)+,a0
	move.l	a0,usp
	movem.l	(sp)+,d0-a6
	rte

music_thread_entry:
	.rept	1000
	move.w	#$770,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	clr.b	music_thread_ready
	jsr	switch_threads
	bra	music_thread_entry

update_thread_entry:
	.rept	1000
	move.w	#$070,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	move.b	#1,draw_thread_ready
	clr.b	update_thread_ready
	jsr	switch_threads
	bra	update_thread_entry

draw_thread_entry:
	.rept	1000
	move.w	#$700,$ffff8240.w
	clr.w	$ffff8240.w
	.endr
	move.w	#$2700,sr
	clr.b	draw_thread_ready
	jsr	switch_threads
	bra	draw_thread_entry

main_thread_entry:
main_loop:
	move.w	#$007,$ffff8240.w
	clr.w	$ffff8240.w

; Check for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
	cmp.b	#$39,$fffffc02.w
	bne.s	main_loop
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Save and set up graphics
;;;;;;;;
core_gfx_save_setup:
; Save palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.copy_palette:
	move.w	(a0)+,(a1)+
	dbra.w	d0,.copy_palette

; Save graphics state.
	move.b	$ffff8260.w,save_fb_res
	move.b	$ffff820a.w,save_fb_sync
	move.b	$ffff8201.w,save_fb_high_addr
	move.b	$ffff8203.w,save_fb_low_addr

; Set up our framebuffers
	move.l	#raw_buffer+255,d0
	clr.b	d0
	move.l	d0,back_buffer
	add.l	#32000,d0
	move.l	d0,front_buffer
	move.b	front_buffer+1,$ffff8201.w
	move.b	front_buffer+2,$ffff8203.w

	stop	#$2300

; Set graphics state It's a European demo, 50Hz FTW
	move.b	#0,$ffff8260.w
	move.b	#2,$ffff820a.w

; Clear palette
	lea.l	$ffff8240.w,a0
	moveq.l	#15,d0
.clear_palette:
	clr.w	(a0)+
	dbra.w	d0,.clear_palette

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Restore graphics
;;;;;;;;
core_gfx_restore:
	stop	#$2300
; Clear palette
	lea.l	$ffff8240.w,a0
	moveq.l	#15,d0
.clear_palette2:
	clr.w	(a0)+
	dbra.w	d0,.clear_palette2

; Restore graphics status
	move.b	save_fb_sync,$ffff820a.w
	move.b	save_fb_res,$ffff8260.w
	move.b	save_fb_high_addr,$ffff8201.w
	move.b	save_fb_low_addr,$ffff8203.w
	stop	#$2300
; Restore palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#15,d0
.restore_palette:
	move.w	(a1)+,(a0)+
	dbra.w	d0,.restore_palette
	rts



; Uninitialized memory

	.bss
save_stack:
	ds.l	1
save_sr:
	ds.w	1

save_timer_a:
	ds.l	1
save_timer_b:
	ds.l	1
save_input:
	ds.l	1
save_vbl:
	ds.l	1
save_hbl:
	ds.l	1

save_mfp_enable_a:
	ds.b	1
save_mfp_enable_b:
	ds.b	1
save_mfp_mask_a:
	ds.b	1
save_mfp_mask_b:
	ds.b	1
save_mfp_vector:
	ds.b	1
save_mfp_timer_b_control:
	ds.b	1
save_mfp_timer_b_data:
	ds.b	1
save_mfp_timer_a_control:
	ds.b	1
save_mfp_timer_a_data:
	ds.b	1

	.even
save_palette:
	ds.w	16
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

	.even
music_thread_current_stack:
	ds.l	1
music_thread_stack_bottom:
	ds.b	1024
music_thread_stack_top:
music_thread_ready:
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

	.even
current_thread:
	ds.l	1

raw_buffer:
	ds.b	32000*2+255
