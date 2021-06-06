;   Copyright 2021 Jean-Baptiste M. "JBQ" "Djaybee" Queru
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
; Precompute the graphics for the waveform spheres
;;;;;;;;
wave_compute:
; Wait until precompute reaches phase 1 to draw wave
	move.b	#1,compute_wait_phase
; Set the draw routines to use once precompute is done
	move.l	#wave_update,update_wait_routine
	move.l	#wave_draw,draw_wait_routine

; Set the data to match the various screen draw states
	move.l	#wave_f1,front_drawn_data
	move.l	#wave_f2,front_to_draw_data
	move.l	#wave_f3,back_drawn_data
	move.l	#wave_f4,back_to_draw_data
	move.l	back_to_draw_data,most_recently_updated
	move.l	back_to_draw_data,next_to_update

;;; Precompute sphere graphics
; d0,d1,d2: bit planes
; d3: pixel color
; d5-d7: loops
; a0: destination for writes
; a1: data for sphere shape
	lea.l	heap,a0
	move.w	#255,d7		; generate 256 images
.generate_image:
	moveq.l	#5,d6		; 6 rows per image
	lea.l	wave_sphere,a1
.generate_row:
	moveq.l	#11,d5		; 12 active pixels per row
	moveq.l	#0,d0
	moveq.l	#0,d1
	moveq.l	#0,d2
.input_pixel:
	moveq.l	#0,d3
	move.b	(a1)+,d3
	tst.b	d3		; 0 in input = black/trasparent
	beq.s	.computed_pixel
	add.b	d7,d3		; add byte, wraparound, still 0-255
	mulu.w	#1799,d3	; 0-456960 ($6FFF9) (1799 = 65536*7/255)
	swap.w	d3		; 0-6
	addq.w	#1,d3		; 1-7
.computed_pixel:

	lsr.w	d3		; extract bit 0
	roxl.w	d0		; insert
	lsr.w	d3		; bit 1
	roxl.w	d1
	lsr.w	d3		; bit 2
	roxl.w	d2
	dbra.w	d5,.input_pixel

	lsl.w	#2,d0		; shift by 2 pixels to center (12 in 16)
	lsl.w	#2,d1
	lsl.w	#2,d2
	move.w	d0,(a0)+	; store data
	move.w	d1,(a0)+
	move.w	d2,(a0)+
	dbra.w	d6,.generate_row
	dbra.w	d7,.generate_image

;;; Set palette
	lea.l	$ffff8242.w,a0
	move.w	#$711,(a0)+
	move.l	#$7400660,(a0)+
	move.l	#$0700166,(a0)+
	move.l	#$2270717,(a0)+
	move.l	#$7770777,d0
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+

; Done, let the drawing begin
	move.b	#1,compute_phase
	clr.l	compute_routine
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update the coordinates for the waveform spheres
;;;;;;;;
wave_update:
	move.l	most_recently_updated,a5
	move.l	next_to_update,a6

	move.w	(a5),d0
	addq.w	#1,d0
	move.w	d0,(a6)
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Draw the waveform spheres
;;;;;;;;
; TODO: investigate whether drawing diagonally is faster
;	advantage is that each cell type gets read once (36 -> 11)
;	drawback is the complexity of updating pointers at end of row
;	maybe just precompute and store the offsets?
; TODO: investigate whether code-generation is faster
;	drawbacks are complexity and maybe more code
; d0: increment (between columns on 1st row / between rows on 1st column)
; d1: row start
; d2: current cell
; d3: scratch
; d4: data 1
; d5: data 2
; d6: loop x
; d7; loop y
; a0: write 1 (top left)
; a1: write 2 (top right)
; a2: write 3 (bottom left)
; a3: write 4 (bottom right)
; a4: read graphics
; a5: graphics start
; a6: free
wave_draw:
	move.l	back_to_draw_data,a6
	move.w	(a6),d0
	lea.l	heap,a5

; Point to the top row of the centermost spheres
	move.l	back_buffer,a0
	move.l	a0,a1
	move.l	a0,a2
	move.l	a0,a3
	adda.w	#13832,a0
	adda.w	#13840,a1
	adda.w	#16392,a2
	adda.w	#16400,a3

	move.w	#5,d7		; elements in a column
	move.w	d0,d1
.copy_row:
	move.w	#5,d6		; elements in a row
	move.w	d1,d2

.copy_element:
; Compute address of graphics to read (heap + frame % 256 * 36)
	moveq.l	#0,d3
	move.b	d2,d3
	add.w	d3,d3		; x2
	add.w	d3,d3		; x4
	move.w	d3,d4
	lsl.w	#3,d4		; x32
	add.w	d4,d3		; x36
	move.l	a5,a4
	adda.w	d3,a4

; The graphics are mirrorred vertically, read once write twice
	move.l	(a4)+,d4	; read gfx 1 (2 planes)
	move.w	(a4)+,d5	; read gfx 2 (1 plane)
	move.l	d4,(a0)		; write top line planes 0-1
	move.w	d5,4(a0)	; write top line plane 2
	move.l	d4,1760(a0)	; write bottom line planes 0-1
	move.w	d5,1764(a0)	; write bottom line plane 2
	move.l	d4,(a1)		; repeat for other 3 quadrants
	move.w	d5,4(a1)
	move.l	d4,1760(a1)
	move.w	d5,1764(a1)
	move.l	d4,(a2)
	move.w	d5,4(a2)
	move.l	d4,1760(a2)
	move.w	d5,1764(a2)
	move.l	d4,(a3)
	move.w	d5,4(a3)
	move.l	d4,1760(a3)
	move.w	d5,1764(a3)

	move.l	(a4)+,d4	; unrolled 6 times
	move.w	(a4)+,d5
	move.l	d4,160(a0)
	move.w	d5,164(a0)
	move.l	d4,1600(a0)
	move.w	d5,1604(a0)
	move.l	d4,160(a1)
	move.w	d5,164(a1)
	move.l	d4,1600(a1)
	move.w	d5,1604(a1)
	move.l	d4,160(a2)
	move.w	d5,164(a2)
	move.l	d4,1600(a2)
	move.w	d5,1604(a2)
	move.l	d4,160(a3)
	move.w	d5,164(a3)
	move.l	d4,1600(a3)
	move.w	d5,1604(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,320(a0)
	move.w	d5,324(a0)
	move.l	d4,1440(a0)
	move.w	d5,1444(a0)
	move.l	d4,320(a1)
	move.w	d5,324(a1)
	move.l	d4,1440(a1)
	move.w	d5,1444(a1)
	move.l	d4,320(a2)
	move.w	d5,324(a2)
	move.l	d4,1440(a2)
	move.w	d5,1444(a2)
	move.l	d4,320(a3)
	move.w	d5,324(a3)
	move.l	d4,1440(a3)
	move.w	d5,1444(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,480(a0)
	move.w	d5,484(a0)
	move.l	d4,1280(a0)
	move.w	d5,1284(a0)
	move.l	d4,480(a1)
	move.w	d5,484(a1)
	move.l	d4,1280(a1)
	move.w	d5,1284(a1)
	move.l	d4,480(a2)
	move.w	d5,484(a2)
	move.l	d4,1280(a2)
	move.w	d5,1284(a2)
	move.l	d4,480(a3)
	move.w	d5,484(a3)
	move.l	d4,1280(a3)
	move.w	d5,1284(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,640(a0)
	move.w	d5,644(a0)
	move.l	d4,1120(a0)
	move.w	d5,1124(a0)
	move.l	d4,640(a1)
	move.w	d5,644(a1)
	move.l	d4,1120(a1)
	move.w	d5,1124(a1)
	move.l	d4,640(a2)
	move.w	d5,644(a2)
	move.l	d4,1120(a2)
	move.w	d5,1124(a2)
	move.l	d4,640(a3)
	move.w	d5,644(a3)
	move.l	d4,1120(a3)
	move.w	d5,1124(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,800(a0)
	move.w	d5,804(a0)
	move.l	d4,960(a0)
	move.w	d5,964(a0)
	move.l	d4,800(a1)
	move.w	d5,804(a1)
	move.l	d4,960(a1)
	move.w	d5,964(a1)
	move.l	d4,800(a2)
	move.w	d5,804(a2)
	move.l	d4,960(a2)
	move.w	d5,964(a2)
	move.l	d4,800(a3)
	move.w	d5,804(a3)
	move.l	d4,960(a3)
	move.w	d5,964(a3)

	subq.l	#8,a0		; point to next item horizontally
	addq.l	#8,a1
	subq.l	#8,a2
	addq.l	#8,a3
	add.w	d0,d2		; update ball rotation on the row
	dbra.w	d6,.copy_element
	sub.w	#2512,a0	; point to start of next row
	sub.w	#2608,a1
	add.w	#2608,a2
	add.w	#2512,a3
	add.w	d0,d1		; update ball rotation on start of next row
	dbra.w	d7,.copy_row

	rts

	.data

; Sphere rotation data
; computed in Google Sheets
; =round(ACOS((13-2*B$1)/12/SQRT(1-((13-2*$A2)/12)^2))*128/PI())
wave_sphere:
	dc.b	0,0,0,0,36,55,73,92,0,0,0,0
	dc.b	0,0,20,36,48,59,69,80,92,108,0,0
	dc.b	0,16,31,42,51,60,68,77,86,97,112,0
	dc.b	0,24,36,45,53,60,68,75,83,92,104,0
	dc.b	13,28,38,46,53,60,68,75,82,90,100,115
	dc.b	16,29,39,46,54,61,67,74,82,89,99,112

	.bss
	.even
wave_f1:
	ds.w	1
wave_f2:
	ds.w	1
wave_f3:
	ds.w	1
wave_f4:
	ds.w	1
