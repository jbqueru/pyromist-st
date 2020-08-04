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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Save and set up interrupts
;;;;;;;;
core_int_save_setup:
	move.w	sr,save_sr
	move.w	#$2700,sr

; Save MFP
; Save active status
	move.b	$fffffa07.w,save_mfp_active_a
	move.b	$fffffa09.w,save_mfp_active_b
	move.b	$fffffa13.w,save_mfp_mask_a
	move.b	$fffffa15.w,save_mfp_mask_b
	move.b	$fffffa17.w,save_mfp_vector
; Save timers
	move.b	$fffffa19.w,save_mfp_timer_a_control
	move.b	$fffffa1f.w,save_mfp_timer_a_data	; ???
	move.b	$fffffa1b.w,save_mfp_timer_b_control
	move.b	$fffffa21.w,save_mfp_timer_b_data	; ???

; Deactivate all MFP interrupts, set auto-clear
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
; Activate and sync our interrupts
;;;;;;;;
core_int_activate:
; Sync interrupts

	stop	#$2300			; wait for VBL

	move.b	#$1,$fffffa07.w		; activate timer B
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
; Deactivate our interrupts
;;;;;;;;
core_int_deactivate:
; Deactivate MFP
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
	move.b	save_mfp_active_a,$fffffa07.w
	move.b	save_mfp_active_b,$fffffa09.w

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

; Uninitialized memory

	.bss
	.even
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

save_mfp_active_a:
	ds.b	1
save_mfp_active_b:
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
