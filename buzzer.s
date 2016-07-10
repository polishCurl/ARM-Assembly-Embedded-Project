;-----------------------------------------------------------------------------------
; Piezo Buzzer
; Krzysztof Koch
; 5th May 2016
;
; Last edit: 6th May 2016
; 
; Methods to use the piezo-buzzer attached to one of the keyboards. The buzzer is assumed to 
; be attached to PIO 0 - the S0 connector
;
; (Tab size - 4)
;-----------------------------------------------------------------------------------



;----------------------------------WRITE TO BUZZER----------------------------------
; Write the value in R1 to buzzer memory location
; Arguments:
;	R0 - SVC call number, if called from supervisor mode then equal to MaxSVC
; Local registers:
; 	R4 - pointer to the base of FPGA address space

buzzerWrite 	CMP 	R0, #MaxSVC				; Check if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4}
				MOV 	R4, #FPGAspace 			; write the value to the buzzer byte in FPGA mem space
				STRB 	R1, [R4, #buzzerAdr]
				POP 	{R4}
				CMP 	R0, #MaxSVC
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]	



;---------------------------------BEEP THE BUZZER-----------------------------------
; Beep the buzzer for amount of time specified in R0
; Arguments:
;	R0 - time to beep (in ms)
; Local registers:
; 	R4 - temporarily holds the argument

beep 			PUSH 	{R4, LR} 				
				MOV 	R4, R0
				MOV 	R0, #BUZZER_WRITE 		; turn the buzzer on
				MOV 	R1, #buzzerOn
				SVC 	9
				MOV 	R0, R4
				BL 		wait 					; wait
				MOV 	R0, #BUZZER_WRITE
				MOV 	R1, #buzzerOff 			; turn the buzzer off
				SVC 	9
				POP 	{R4, LR}
				MOV 	PC, LR



;-------------------------------BEEP-BEEP THE BUZZER-------------------------------
; Beep the buzzer number of times specified in R1, each time for number od milliseconds
; in R0.
; Arguments:
;	R0 - time to beep (in ms) each time
; 	R1 - number of beeps
; Local registers:

beepBeep 		PUSH 	{R4-R5, LR}
				MOV 	R4, R0 					; move the arguments so not overwritten
				MOV 	R5, R1
				
beepAgain		MOV 	R0, R4 					; beep for amount of time in R0
				BL 		beep
				MOV 	R0, R4 					; wait for amount of time in R0
				BL 		wait
				SUBS 	R5, R5, #1 				; decrement the beep counter
				BNE 	beepAgain 				; repeat if not all the beeps made

				POP 	{R4-R5, LR}
				MOV 	PC, LR





;------------------------------------DEFINITIONS------------------------------------
buzzerAdr		EQU		0x0 					; Offset from the FPGA base for buzzer PIO
buzzerOn 		EQU 	0xFF 					; value to write to make sound
buzzerOff 		EQU 	0x0 					; value to write to make the buzzer silent
