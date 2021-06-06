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
; Format of precomputed graphics for the waveform spheres
;
; heap offset 0
; 256 bitmaps, 16*12 pixels, 3 bitplanes.
; total 18432 bytes
;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Format of precomputed graphics for the surrounding cubes
;
; heap offset 18432
; 256*64 bitmaps, 16*16 pixels, 1 bitplane
; total 524288 bytes
; TODO: would 128*32 work?
;;;;;;;;



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
	moveq.l	#11,d6		; 12 rows per image
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
	sub.b	d7,d3		; sub byte, wraparound, still 0-255
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

;;; Precompute cubes
; d0-d2: x0/y0/z0
; d3-d5: compute x/y/z (2 accumulators + 1 trig scratch)
; d6: scratch for trig lookups
; d7: angles (alpha in low word, beta in high word) (!!!)
	lea.l	wave_sine,a6
	lea.l	heap+18432,a0
	move.w	#127,d7
.cube_frame_beta:
	swap.w	d7
	move.w	#127,d7
.cube_frame_alpha:
	move.w	#1086,d0	; x0 - 256 * 3  * sqrt(2)
	move.w	#1086,d1	; y0
	move.w	#1086,d2	; z0

; rotate by alpha around z - d5 is trig scratch

; x = x0 * cos(alpha) - y0 * sin(alpha)
	move.w	d0,d3		; x0
	move.l	d7,d6		; alpha
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(alpha) * 32k

	move.w	d1,d5		; y0
	move.l	d7,d6		; alpha
	add.w	d6,d6
	muls	(a6,d6.w),d5	; y0 * sin(alpha) * 32k

	sub.l	d5,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

; y = y0 * cos(alpha) + x0 * sin(alpha)
	move.w	d1,d4		; y0
	move.l	d7,d6		; alpha
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(alpha) * 32k

	move.w	d0,d5		; x0
	move.l	d7,d6		; alpha
	add.w	d6,d6
	muls	(a6,d6.w),d5	; x0 * sin(alpha) * 32k

	add.l	d5,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

	move.w	d3,d0		; update x0
	move.w	d4,d1		; update y0

; rotate by beta around x - d3 is trig scratch

; y = y0 * cos(beta) - z0 * sin(beta)
	move.w	d1,d4		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(beta) * 32k

	move.w	d2,d3		; z0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	d6,d6
	muls	(a6,d6.w),d3	; z0 * sin(beta) * 32k

	sub.l	d3,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

; z = z0 * cos(beta) + y0 * sin(beta)
	move.w	d2,d5		; z0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; z0 * cos(beta) * 32k

	move.w	d1,d3		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	d6,d6
	muls	(a6,d6.w),d3	; y0 * sin(beta) * 32k

	add.l	d3,d5		; new z * 32k
	add.l	d5,d5		; new z * 64k
	swap.w	d5		; new z

	move.w	d4,d1		; update y0
	move.w	d5,d2		; update z0

; rotate by alpha around y - d4 is trig scratch

; z = z0 * cos(alpha) - x0 * sin(alpha)
	move.w	d2,d5		; z0
	move.l	d7,d6		; alpha
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d5	; z0 * cos(alpha) * 32k

	move.w	d0,d4		; x0
	move.l	d7,d6		; alpha
	add.w	d6,d6
	muls	(a6,d6.w),d4	; x0 * sin(alpha) * 32k

	sub.l	d4,d5		; new z * 32k
	add.l	d5,d5		; new z * 64k
	swap.w	d5		; new z

; x = x0 * cos(alpha) + z0 * sin(alpha)
	move.w	d0,d3		; x0
	move.l	d7,d6		; alpha
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(alpha) * 32k

	move.w	d2,d4		; z0
	move.l	d7,d6		; alpha
	add.w	d6,d6
	muls	(a6,d6.w),d4	; z0 * sin(alpha) * 32k

	add.l	d4,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

	move.w	d5,d2		; update z0
	move.w	d3,d0		; update x0

; rotate by beta around z - d5 is trig scratch

; x = x0 * cos(beta) - y0 * sin(beta)
	move.w	d0,d3		; x0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d3	; x0 * cos(beta) * 32k

	move.w	d1,d5		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	d6,d6
	muls	(a6,d6.w),d5	; y0 * sin(beta) * 32k

	sub.l	d5,d3		; new x * 32k
	add.l	d3,d3		; new x * 64k
	swap.w	d3		; new x

; y = y0 * cos(alpha) + x0 * sin(alpha)
	move.w	d1,d4		; y0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	#32,d6
	andi.w	#127,d6
	add.w	d6,d6
	muls	(a6,d6.w),d4	; y0 * cos(beta) * 32k

	move.w	d0,d5		; x0
	move.l	d7,d6
	swap.w	d6		; beta
	add.w	d6,d6
	muls	(a6,d6.w),d5	; x0 * sin(beta) * 32k

	add.l	d5,d4		; new y * 32k
	add.l	d4,d4		; new y * 64k
	swap.w	d4		; new y

	move.w	d3,d0		; update x0
	move.w	d4,d1		; update y0



	add.w	#2048,d0	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d0
	moveq.l	#1,d5
	lsl.w	d0,d5

	swap.w	d1
	add.w	#2048,d1	; 7.5*256 (center) + 0.5*256 (nearest)
	asr.w	#8,d1

	add.w	d1,d1
	move.w	d5,(a0,d1.w)
	adda.w	#32,a0
	dbra.w	d7,.cube_frame_alpha
	swap.w	d7
	dbra.w	d7,.cube_frame_beta

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
; MORE: investigate whether drawing diagonally is faster
;	advantage is that each cell type gets read once (36 -> 11)
;	drawback is the complexity of updating pointers at end of row
;	maybe just precompute and store the offsets?
; MORE: investigate whether code-generation is faster
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
	.rept	16
;	move.w	#$700,$ffff8240.w
	move.w	#$000,$ffff8240.w
	.endr

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

	move.w	#5,d7		; elements in a column (x2)
	move.w	d0,d1
.copy_row:
	move.w	#5,d6		; elements in a row (x2)
	move.w	d1,d2

.copy_element:
; Compute address of graphics to read (heap + frame % 256 * 72)
	moveq.l	#0,d3
	move.b	d2,d3
	lsl.w	#3,d3		; x8
	move.w	d3,d4
	lsl.w	#3,d4		; x64
	add.w	d4,d3		; x72
	move.l	a5,a4
	adda.w	d3,a4

; Draw 4 spheres
	move.l	(a4)+,d4	; read gfx 1 (2 planes)
	move.w	(a4)+,d5	; read gfx 2 (1 plane)
	move.l	d4,(a0)		; write planes 0-1
	move.w	d5,4(a0)	; write plane 2
	move.l	d4,(a1)		; repeat for other 3 quadrants
	move.w	d5,4(a1)
	move.l	d4,(a2)
	move.w	d5,4(a2)
	move.l	d4,(a3)
	move.w	d5,4(a3)

	move.l	(a4)+,d4	; unrolled 12 times
	move.w	(a4)+,d5
	move.l	d4,160(a0)
	move.w	d5,164(a0)
	move.l	d4,160(a1)
	move.w	d5,164(a1)
	move.l	d4,160(a2)
	move.w	d5,164(a2)
	move.l	d4,160(a3)
	move.w	d5,164(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,320(a0)
	move.w	d5,324(a0)
	move.l	d4,320(a1)
	move.w	d5,324(a1)
	move.l	d4,320(a2)
	move.w	d5,324(a2)
	move.l	d4,320(a3)
	move.w	d5,324(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,480(a0)
	move.w	d5,484(a0)
	move.l	d4,480(a1)
	move.w	d5,484(a1)
	move.l	d4,480(a2)
	move.w	d5,484(a2)
	move.l	d4,480(a3)
	move.w	d5,484(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,640(a0)
	move.w	d5,644(a0)
	move.l	d4,640(a1)
	move.w	d5,644(a1)
	move.l	d4,640(a2)
	move.w	d5,644(a2)
	move.l	d4,640(a3)
	move.w	d5,644(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,800(a0)
	move.w	d5,804(a0)
	move.l	d4,800(a1)
	move.w	d5,804(a1)
	move.l	d4,800(a2)
	move.w	d5,804(a2)
	move.l	d4,800(a3)
	move.w	d5,804(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,960(a0)
	move.w	d5,964(a0)
	move.l	d4,960(a1)
	move.w	d5,964(a1)
	move.l	d4,960(a2)
	move.w	d5,964(a2)
	move.l	d4,960(a3)
	move.w	d5,964(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1120(a0)
	move.w	d5,1124(a0)
	move.l	d4,1120(a1)
	move.w	d5,1124(a1)
	move.l	d4,1120(a2)
	move.w	d5,1124(a2)
	move.l	d4,1120(a3)
	move.w	d5,1124(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1280(a0)
	move.w	d5,1284(a0)
	move.l	d4,1280(a1)
	move.w	d5,1284(a1)
	move.l	d4,1280(a2)
	move.w	d5,1284(a2)
	move.l	d4,1280(a3)
	move.w	d5,1284(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1440(a0)
	move.w	d5,1444(a0)
	move.l	d4,1440(a1)
	move.w	d5,1444(a1)
	move.l	d4,1440(a2)
	move.w	d5,1444(a2)
	move.l	d4,1440(a3)
	move.w	d5,1444(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1600(a0)
	move.w	d5,1604(a0)
	move.l	d4,1600(a1)
	move.w	d5,1604(a1)
	move.l	d4,1600(a2)
	move.w	d5,1604(a2)
	move.l	d4,1600(a3)
	move.w	d5,1604(a3)

	move.l	(a4)+,d4
	move.w	(a4)+,d5
	move.l	d4,1760(a0)
	move.w	d5,1764(a0)
	move.l	d4,1760(a1)
	move.w	d5,1764(a1)
	move.l	d4,1760(a2)
	move.w	d5,1764(a2)
	move.l	d4,1760(a3)
	move.w	d5,1764(a3)

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


	move.l	back_buffer,a0
	adda.w	#678,a0
	moveq.l	#11,d7
.cube_row:
	moveq.l	#11,d6
.cube_column:
;	lea.l	wave_cube,a1
	lea.l	heap+18432,a1

	move.l	back_to_draw_data,a6
	move.w	(a6),d0
	andi.w	#127,d0
	lsl.w	#5,d0
	adda.w	d0,a1

	move.w	(a1)+,(a0)
	move.w	(a1)+,160(a0)
	move.w	(a1)+,320(a0)
	move.w	(a1)+,480(a0)
	move.w	(a1)+,640(a0)
	move.w	(a1)+,800(a0)
	move.w	(a1)+,960(a0)
	move.w	(a1)+,1120(a0)
	move.w	(a1)+,1280(a0)
	move.w	(a1)+,1440(a0)
	move.w	(a1)+,1600(a0)
	move.w	(a1)+,1760(a0)
	move.w	(a1)+,1920(a0)
	move.w	(a1)+,2080(a0)
	move.w	(a1)+,2240(a0)
	move.w	(a1)+,2400(a0)
	addq.l	#8,a0
	dbra.w	d6,.cube_column
	adda.w	#2464,a0
	dbra.w	d7,.cube_row

	.rept	16
;	move.w	#$070,$ffff8240.w
	move.w	#$000,$ffff8240.w
	.endr

	rts

	.data

; Sphere rotation data
; computed in Google Sheets
; =ROUND(ACOS((13-2*$A2)/12/SQRT(1-((13-2*B$1)/12)^2))*128/PI())
wave_sphere:
	dc.b	0,0,0,0,13,16,16,13,0,0,0,0
	dc.b	0,0,16,24,28,29,29,28,24,16,0,0
	dc.b	0,20,31,36,38,39,39,38,36,31,20,0
	dc.b	0,36,42,45,46,46,46,46,45,42,36,0
	dc.b	36,48,51,53,53,54,54,53,53,51,48,36
	dc.b	55,59,60,60,60,61,61,60,60,60,59,55
	dc.b	73,69,68,68,68,67,67,68,68,68,69,73
	dc.b	92,80,77,75,75,74,74,75,75,77,80,92
	dc.b	0,92,86,83,82,82,82,82,83,86,92,0
	dc.b	0,108,97,92,90,89,89,90,92,97,108,0
	dc.b	0,0,112,104,100,99,99,100,104,112,0,0
	dc.b	0,0,0,0,115,112,112,115,0,0,0,0

	.even
; Sine curve, 128 steps, scaled by 32767
; computed in Google Sheets
; =ROUND(SIN(2*PI()*$A24/128)*32767)
; MORE: easy to unfold, especially if offset a tiny bit.
wave_sine:
	dc.w	0,1608,3212,4808,6393,7962,9512,11039
	dc.w	12539,14010,15446,16846,18204,19519,20787,22005
	dc.w	23170,24279,25329,26319,27245,28105,28898,29621
	dc.w	30273,30852,31356,31785,32137,32412,32609,32728
	dc.w	32767,32728,32609,32412,32137,31785,31356,30852
	dc.w	30273,29621,28898,28105,27245,26319,25329,24279
	dc.w	23170,22005,20787,19519,18204,16846,15446,14010
	dc.w	12539,11039,9512,7962,6393,4808,3212,1608
	dc.w	0,-1608,-3212,-4808,-6393,-7962,-9512,-11039
	dc.w	-12539,-14010,-15446,-16846,-18204,-19519,-20787,-22005
	dc.w	-23170,-24279,-25329,-26319,-27245,-28105,-28898,-29621
	dc.w	-30273,-30852,-31356,-31785,-32137,-32412,-32609,-32728
	dc.w	-32767,-32728,-32609,-32412,-32137,-31785,-31356,-30852
	dc.w	-30273,-29621,-28898,-28105,-27245,-26319,-25329,-24279
	dc.w	-23170,-22005,-20787,-19519,-18204,-16846,-15446,-14010
	dc.w	-12539,-11039,-9512,-7962,-6393,-4808,-3212,-1608


wave_cube:
	dcb.w	16,0
	dc.w	$0
	dc.w	$7ffe
	dcb.w	12,$4002
	dc.w	$7ffe
	dc.w	$0

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
