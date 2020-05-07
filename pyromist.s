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
; Check that we're in supervisor mode, exit otherwise
	move.w	sr,d0
	btst.l	#13,d0
	bne.s	.super_ok
	rts
.super_ok:
; Save status register, mask all interrupts
	move.w	d0,save_sr
	move.w	#$2700,sr

; TODO: Check for color monitor
; TODO: Set up the stack
; TODO: Initialize BSS
; TODO: Save MFP status, clear MFP interrupts

; Save palette, paint it black
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#16,d0
.copy_palette:
	move.w	(a0),(a1)+
	move.w	#0,(a0)+
	dbra.w	d0,.copy_palette

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

; Wait for a keypress
; NOTE: would be good to do that with an interrupt handler, but I'm lazy
.waitkey:
	cmp.b	#$39,$fffffc02.w
	bne.s .waitkey

; Restore palette
	lea.l	$ffff8240.w,a0
	lea.l	save_palette,a1
	moveq.l	#16,d0
.restore_palette:
	move.w	(a1)+,(a0)+
	dbra.w	d0,.restore_palette

; Restore status register, exit
	move.w	save_sr,sr
	rts

; Uninitialized memory
	.bss

save_sr:
	ds.w	1
save_palette:
	ds.w	16

framebuffer:
	ds.l	1
