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

raw_buffer:
	ds.b	32000*2+255
