;   Copyright 2020 JBQ
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

; This is the actual start of the demo.
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
soup2:
; Save status register, disable all interrupts
	move.w	sr,save_sr
	move.w	#$2700,sr

; TODO: Set up the stack
; TODO: Initialize BSS

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
	move.b	$ffff8260.w,save_res
	move.b	$ffff820a.w,save_sync
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

; Get framebuffer address from hardware registers
; TODO: Set up our own framebuffer instead
	moveq.l	#0,d0
	move.b	$ffff8201.w,d0
	swap.w	d0
	move.b	$ffff8203.w,d0
	lsl.w	#8,d0
	move.l	d0,framebuffer

; Clear the framebuffer
	move.l	d0,a0
	move.w	#8000,d1
	moveq.l	#0,d0
.clear_framebuffer:
	move.l	d0,(a0)+
	dbra.w	d1,.clear_framebuffer

; Enable interrupts
	move.b	#1,$fffffa07.w
	move #$2300,sr

; Wait for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
.waitkey:
	cmp.b	#$39,$fffffc02.w
	bne.s .waitkey

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
	move.b	save_sync,$ffff820a.w
	move.b	save_res,$ffff8260.w

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
	move.w	#0,$ffff8240.w
	rte

hbl:
	not.w	$ffff8240.w
	rte

; Initialized data
	.data
my_palette:
	dc.w	0,$002,$004,$006,0,$020,$040,$060,0,$200,$400,$600,0,$222,$444,$666

; Uninitialized memory
	.bss
save_hbl:
	ds.l	1
save_vbl:
	ds.l	1
framebuffer:
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
save_res:
	ds.b	1
save_sync:
	ds.b	1
