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
; Set up thread
;;;;;;;;
core_thr_setup:
; Set up threading system
	lea.l	music_thread_stack_top,a0
	move.l	#music_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,music_thread_current_stack

	lea.l	draw_thread_stack_top,a0
	move.l	#draw_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,draw_thread_current_stack

	lea.l	main_thread_stack_top,a0
	move.l	#main_thread_entry,-(a0)	; PC
	move.w	#$2300,-(a0)			; SR
	suba.w	#64,a0				; D0-A6, USP
	move.l	a0,main_thread_current_stack

	move.l	#update_thread_current_stack,current_thread

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

; Uninitialized memory

	.bss

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
