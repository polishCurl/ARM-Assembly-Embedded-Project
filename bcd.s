;-----------------------------------------------------------------------------------
; BCD - Binary Coded Decimal
; Jim Garside 
; 10th April 2016
;
; Last edit: 6th May 2016 (Krzysztof Koch)
; 
; Binary to Binary Coded Decimal conversion utility. Code by Jim Garside with minor changes
; by Krzysztof Koch
;
; (Tab size - 4)
;-----------------------------------------------------------------------------------


;-------------------------------------CONVERT--------------------------------------
; Convert unsigned binary value in R0 into BCD representation, returned in R0
; Arguments:
; 	R0 - unsigned binary value
; Returns:
; 	R0 - binary coded decimal representation of the argument
; Local registers:
; 	R7 - pointer to conversion table
;	R8 - Accumulates result 	

bcd_convert		PUSH 	{R4-R8, LR} 		
				ADR		R7, dec_table		; Point at conversion table
				MOV		R8, #0				; Zero accumulator

bcd_loop		LDR		R4, [R7], #4		; Get next divisor, step pointer
				CMP		R4, #1				; Termination condition?
				BEQ		bcd_out				;  yes

				BL		bcdDivide			; R0 := R0/R4 (rem. R5)
				ADD		R8, R0, R8, LSL #4	; Accumulate result
				MOV		R0, R5				; Recycle remainder
				B		bcd_loop			;

bcd_out			ADD		R0, R0, R8, LSL #4	; Accumulate result to output
				POP 	{R4-R8, LR}			
				MOV		PC, LR				; Return

dec_table		DCD		1000000000, 100000000, 10000000, 1000000
				DCD		100000, 10000, 1000, 100, 10, 1



;---------------------------32-BIT UNSIGNED DIVISION-------------------------------
; 32-bit unsigned integer division R0/R4. ; Returns quotient FFFFFFFF in case of division 
; by zero. Does not require a stack
; Arguments:
; 	R0 - number to be divided
; 	R4 - divident
; Returns:
; 	R0 - quotient
;	R5 - remainder
; Local Registers:
; 	R5 - AccH
; 	R6 - Number of bits in division

bcdDivide		MOV		R5, #0				; AccH
				MOV		R6, #bitsInDivision	; Number of bits in division
				ADDS	R0, R0, R0			; Shift dividend

bcdDivide1		ADC		R5, R5, R5			; Shift AccH, carry into LSB
				CMP		R5, R4				; Will it go?
				SUBHS	R5, R5, R4			; If so, subtract
				ADCS	R0, R0, R0			; Shift dividend & Acc. result
				SUB		R6, R6, #1			; Loop count
				TST		R6, R6				; Leaves carry alone
				BNE		bcdDivide1			; Repeat as required

				MOV		PC, LR				; Return 



; ---------------------------------DEFINITIONS--------------------------------------	
bitsInDivision 	EQU 	32
