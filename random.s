;-----------------------------------------------------------------------------------
; Random numbers utility methods
; Krzysztof Koch
; 16th April 2016
;
; Last edit: 6th May 2016
; 
; Methods to generate pseudo-random numbers using the Linear Feedback Shift Register software 
; emulation, and to read the latest radom number generated. LFSR is emulated in software and 
; generate next random number at timer interrupts (every millisecond)
; 
; (Tab size - 4)
;-----------------------------------------------------------------------------------



;--------------------------------"RANDOM" NUMBER GENERATOR------------------------------- 
; Software implementation of the Linear Feedback Shift Register. Generates a new pseudo-random
; 32-bit value whenever called and stores it at lfsr memory location
; Local Registers:
; 	R4 - pointer to the lfsr memory location, which stores the current random number generated
; 	R5 - pointer to the table with the feedback polynomial / final updated value stored in lfsr
; 	R6 - value in lfsr memory location, gets shifted multiple times
; 	R7 - loop counter and offset in the polynomial table
; 	R8 - current shift value (no of bits)
; 	R9 - XORed value of shifting results
; 	R10 - result of shifting

generateRandom 	PUSH	{R4-R10}
				ADR 	R4, lfsr 				
				ADR 	R5, polynomial
				LDR 	R6, [R4] 				; load the last random value
				MOV 	R7, #0 					; initialise the loop counter/offset

				LDRB 	R8, [R5, R7] 			; generate the bit to be prepended as the most significant
				LSR 	R9, R6, R8 				; by shifting the original random number by bit offsets
				ADD 	R7, R7, #1 				; specified in the polynomial table and XOR these results
 												; together
nextTerm		LDRB 	R8, [R5, R7]
				LSR 	R10, R6, R8
				EOR 	R9, R9, R10
				ADD 	R7, R7, #1
				CMP 	R7, #termsInPoly
				BLT 	nextTerm 

				AND	 	R5, R9, #1 				; "1" in the feedback polynomial - x^32 + x^22 + x^2 + x^1 + 1
				LSL 	R5, R5, #31 			; now shift the old number by 1 to the right and prepend
				LSR 	R6, R6, #1 				; the calculated bit in R5 as the most significant bit
				ORR 	R5, R5, R6
				STR 	R5, [R4]
				POP 	{R4-R10}
				MOV 	PC, LR



;-----------------------------------GET RANDOM NUMBER----------------------------------
; Return the next random number generated by the LFSR register
; returns:
; 	R0 - random number (pseudo)
getRandom 		CMP 	R0, #MaxSVC				; Chek if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				ADR 	R0, lfsr 				; load the address of the random number
				LDR 	R0, [R0]  	 			; read the current random number
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]



;------------------------------------DEFINITIONS------------------------------------
lfsr 			DEFW	0xA3E902FF 				; starting value fo the pseudo-random number generator
												; chosen by me, quite arbitralily
termsInPoly 	EQU 	4
polynomial		DEFB 	0, 10, 30, 31 			; feedback polynomial - x^32 + x^22 + x^2 + x^1. (+1)
												; values are "taps" that affect output	