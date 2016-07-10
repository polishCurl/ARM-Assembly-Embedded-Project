;-----------------------------------------------------------------------------------
; System timing utility methods
; Krzysztof Koch
; 10th April 2016
;
; Last edit: 17th April 2016
; 
; Methods to handle system timing by causing timer Interrupts every 1ms and storing the time elapsed
; since system initalisation (in milliseconds) in timestampAdr memory location
; 
; (Tab size - 4)
;-----------------------------------------------------------------------------------



; ------------------------------------POLL TIMESTAMP----------------------------------
; Poll the timestamp memory location to get the time elapsed since system initialisation
; in ms.
; Arguments:
; 	R0 - SVC call number, if called from supervisor mode then equal to MaxSVC
; Returns:  
;	R0,R1 - timestamp value
; Local register:
; 	R4 - pointer to timestampAdr memory location

timestampPOLL	CMP 	R0, #MaxSVC				; Check if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4}
				ADR 	R4, timestampAdr 		; load the address of the timer	
				LDR 	R0, [R4]  	 			; read the current timer value
				LDR 	R1, [R4, #4]
				POP 	{R4}
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]



; -----------------------------------UPDATE TIMESTAMP--------------------------------
; Set a new timing checkpoint for the hardware timer (every milisecond) and update the timestamp
; value every 100ms. It is done by storing the 100ms counter at [ms100CounterAdr]
; local registers:
; 	R4 - pointer to the base of I/O address space
;	R5 - new timing checkpoint / first word in timestampAdr memory location
; 	R6 - second word in timestamp memory location

timestamp		PUSH 	{R4-R6}
				MOV 	R4, #IOspace 			; load the I/O space base address
				LDRB 	R5, [R4, #timerCompAdr]	; load the old timer checkpoint
				ADD 	R5, R5, #1 				; Calculate the new timing checkpoint
				CMP 	R5, #maxTimerVal 		
				SUBHS 	R5, R5, #maxTimerVal 	; Do the modulo reduction if required.
				STRB 	R5, [R4, #timerCompAdr] ; update the value of timer compare register

				ADR 	R4, timestampAdr 		; Update the timestamp value by incrementing
				LDR 	R5, [R4] 				; it by 1, bearing in mind that it is a long (64 bit)
				LDR 	R6, [R4, #4] 			; number
				ADDS 	R5, R5, #1
				ADC 	R6, R6, #0	
				STR 	R5, [R4]
				STR 	R6, [R4, #4]
				POP 	{R4-R6}	
				MOV 	PC, LR 					; return [OS.s]



; ------------------------------------WAIT----------------------------------------
; Delay execution by R0 number of milliseconds
; Arguments:
; 	R0 - time to wait (in milliseconds)
; Local registers:
; 	R4,R5 - time target to reach
; 	R6 - temporarily holds the time to wait

wait			CMP 	R0, #0 					; check if we should be waiting at all
				MOVLT  	PC, LR
				PUSH 	{R4-R6, LR}
				MOV 	R6, R0 					; move the value in R0 so it is not overwritten
				MOV 	R0, #TIME
				SVC 	2 						; get the current timestamp value and move it to
				MOV 	R4, R0 					; local registers
				MOV 	R5, R1
				ADD 	R4, R4, R6 				; calculate the time target
				ADC 	R5, R5, #0

notYet			MOV 	R0, #TIME 				; keep checking if the timestampAdr value has
				SVC 	2 						; reached the target. If so, return from method
				CMP 	R0, R4
				CMPEQ 	R1, R5
				BLT 	notYet

				POP 	{R4-R6, LR}
				MOV   	PC, LR  					



; ---------------------------------DEFINITIONS--------------------------------------		
timeHardwareAdr EQU 	0x8 					; timer offser
timerCompAdr 	EQU 	0xC 					; timer compare register offset
maxTimerVal 	EQU 	0x100 					; maximum value of timer, the Modulo


timestampAdr	DEFW	0 						; timestamp value memory location (value in ms)
				DEFW 	0
