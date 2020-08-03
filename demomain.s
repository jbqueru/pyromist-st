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
;;; This is the main entry point for the demo, when invoked from the OS   ;;;
;;;                                                                       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This comes very first, to surround all BSS in all files
	.bss
start_bss:

	.text
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Userland code. Entry point when invoked from the OS.
;
; 1. Invoke the actual demo code as a supervisor subroutine.
; 2. Exit back to the OS when the supervisor subroutine returns.
;;;;;;;;
core_main_user:
	; Invoke XBIOS(38,core_main_super_check) = Supexec
	pea	core_main_super		; address of subroutine
	move.w	#38,-(sp)		; 38 = Supexec
	trap	#14			; 14 = XBIOS
	addq.l	#6,sp			; pop parameters from the stack

	; Invoke GEMDOS(0) = Pterm0
	move.w	#0,-(sp)		; 0 = Pterm0
	trap	#1			; 1 = GEMDOS
	; Pterm0 returns to the calling process

	.include	"democore.s"

; This comes very last, to surround all BSS in all files
	.bss
end_bss:
