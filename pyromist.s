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
	btst.b	#1,$ffff8260.w ; bug in Hatari where this doesn't trigger?
	beq.s	soup2
.setup_wrong:
	rts
soup2:
; Save status register, mask all interrupts
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

; Save MFP status, disable all MFP interrupts
	move.b	$fffffa07.w,save_mfp_a
	clr.b	$fffffa07.w
	move.b	$fffffa09.w,save_mfp_b
	clr.b	$fffffa09.w

; Save interrupt vectors
	move.l	$68.w,save_hbl
	move.l	$70.w,save_vbl
	move.l	$120.w,save_mfp_hbl
	move.l	#vbl,$70.w

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

; Enable VBL interrupt
	move #$2300,sr

; Wait for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
.waitkey:
	cmp.b	#$39,$fffffc02.w
	bne.s .waitkey

; Mask interrupts
	move.w	#$2700,sr

; Restore interrupt vectors
	move.l	save_hbl,$68.w
	move.l	save_vbl,$70.w
	move.l	save_mfp_hbl,$120.w

; Restore MFP enable status
	move.b	save_mfp_a,$fffffa07.w
	move.b	save_mfp_b,$fffffa09.w

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
save_mfp_hbl:
	ds.l	1
framebuffer:
	ds.l	1

save_sr:
	ds.w	1
save_palette:
	ds.w	16

save_mfp_a:
	ds.b	1
save_mfp_b:
	ds.b	1
save_res:
	ds.b	1
save_sync:
	ds.b	1
