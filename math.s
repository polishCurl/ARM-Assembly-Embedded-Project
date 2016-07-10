;-----------------------------------------------------------------------------------
; Mathematical utility methods
; Krzysztof Koch
; 16th April 2016
;
; Last edit: 6th May 2016
; 
; Implementation of common mathematical funcions 
; 
; (Tab size - 4)
;-----------------------------------------------------------------------------------


;----------------------------------------ADDITION----------------------------------------
; Add the value in R0 to the one in R1
; Arguments:
; 	R0 - total value to be updated
; 	R1 - to add
; Returns:
; 	R0 - value in R1 after addition

plus			ADD 	R0, R0, R1
				MOV 	PC, LR



;--------------------------------------SUBTRACTION----------------------------------------
; Subtract the value in R0 from the one in R1
; Arguments:
; 	R0 - total value to be updated
; 	R1 - to subtract
; Returns:
; 	R0 - value in R1 after subtraction

minus			SUB 	R0, R0, R1
				MOV 	PC, LR



;-------------------------------------MULTIPLICATION--------------------------------------
; Multiply the value in R1 by the one in R0
; Arguments:
; 	R0 - total
; 	R1 - multilier
; Returns:
; 	R0 - result

multiply		MUL 	R0, R0, R1
				MOV 	PC, LR



;---------------------------------DIVISION WITH REMAINDER---------------------------------
; Divide the value in R0 by the value in R1 (Euclidean division) Returns both the quotient and
; the remainder
; Arguments:
; 	R0 - divident
; 	R1 - divisor
; Returns:
; 	R0 - quotient
; 	R1 - remainder
; Local registers:
; 	R4 - temporarily holds the quotient

divAndMod 		CMP 	R1, #0 					; division by zero not allowed so no division
				MOVEQ 	PC, LR 					; is performed
				PUSH 	{R4}
				MOV 	R4, #0

divisionLoop	CMP 	R0, R1
				SUBGE 	R0, R0, R1
				ADDGE 	R4, R4, #1
				BGE 	divisionLoop	

				MOV 	R1, R0
				MOV 	R0, R4
				POP 	{R4}
				MOV 	PC, LR



;--------------------------------------DIVISION-----------------------------------------
; Divide the value in R0 by the value in R1. Return the quotient
; Arguments:
; 	R0 - divident
; 	R1 - divisor
; Returns:
; 	R0 - quotient

divide 			PUSH 	{LR}
				BL 		divAndMod
				POP 	{PC}



;--------------------------------------MODULO------------------------------------------
; Divide the value in R0 by the value in R1. Return the remainder
; Arguments:
; 	R0 - divident
; 	R1 - divisor
; Returns:
; 	R0 - remainder

modulo 			PUSH 	{LR}
				BL 		divAndMod
				MOV 	R0, R1
				POP 	{PC}



;--------------------------------------POWER-------------------------------------------
; Raise value in R1 to the power in R0
; Arguments:
; 	R0 - base
; 	R1 - power
; Returns:
; 	R0 - result
; Local registers:
; 	R4 - loop counter, number of times multiplication should be performed

power		 	CMP 	R1, #0 					; number raised to 0 power is always 1
				MOVEQ 	R0, #1 					
				MOVEQ 	PC, LR
				PUSH 	{R4, LR}
				MOV 	R4, R1 					; move values in registers so arguments for
				MOV 	R1, R0 					; multiply method are agreed
				
powerLoop		SUBS 	R4, R4, #1 				; repeatedly multiply (power - 1) times
				BLNE 	multiply
				BNE 	powerLoop
				
				POP 	{R4, LR}
				MOV 	PC, LR



;-----------------------------------SQUARE ROOT---------------------------------------
; Calculate te square root of the value in R0. (Newton method of integer square root approximation)
; Arguments:
; 	R0 - number to calculate the square root of
; Returns:
; 	R0 - result
; Local registers:
; 	R4 - res
; 	R5 - bit
; 	R6 - possible new value of num

squareRoot		PUSH 	{R4-R6} 				; res = 0
				MOV 	R4, #0 					; bit = 1 << 30
				MOV 	R5, #1
				LSL 	R5, R5, #30
												; while (bit > num
shiftAgain		CMP 	R5, R0 					; 	bit >>= 2;
				LSRGT 	R5, R5, #2
				BGT 	shiftAgain
 												
rootLoop		CMP 	R5, #0 					; while (bit != 0) 
				BEQ 	rootFound 				; {
				ADD 	R6, R5, R4 				; 	if (num >= res + bit) 
				CMP 	R0, R6 					; 	{
				SUBGE 	R0, R0, R6 				; 		num -= res + bit;
				LSRGE 	R4, R4, #1 				; 		res = (res >> 1) + bit;
				ADDGE 	R4, R4, R5 				; 	} else
				LSRLT 	R4, R4, #1 				; 		res >>= 1;
				LSR 	R5, R5, #2 				; 	bit >>= 2;
				B 		rootLoop 				; }

rootFound 		MOV 	R0, R4
				POP 	{R4-R6}
				MOV 	PC, LR



;----------------------------------GREATEST COMMON DIVISOR------------------------------------
; Calculate the Greates Common Divisor of values in R0 and R1 and return it in R0. (Euclidean
; algorithm)
; Arguments:
; 	R0 - a
; 	R1 - b
; Returns:
; 	R0 - greatest common divisor of a and b

gcd 			CMP 	R0, R1
				SUBGT 	R0, R0, R1
				SUBLT 	R1, R1, R0
				BNE 	gcd

				MOV 	PC, LR



;-------------------------------------FACTORIAL-----------------------------------------
; Calculate factorial of value in R1
; Arguments:
; 	R0 - to calculate factorial of
; Returns:
; 	R0 - result

factorial		PUSH 	{LR}
				CMP 	R0, #0 					; factorial of 0 is 1
				MOVEQ 	R0, #1
				MOVNE 	R1, R0

factorialLoop	SUBNES 	R1, R1, #1 				; repeated miliplication with the multiplier
				BLNE 	multiply 				; decreasing by 1
				BNE 	factorialLoop

				POP 	{PC}



;-------------------------------------RANDOM-----------------------------------------
; Return a random value that can be represented using 8 decimal digits
; Returns:
; 	R0 - result

rand 			PUSH 	{LR} 
				MOV 	R0, #RAND 				; get the 32-bit unsigned random number
				SVC 	5
reduceNumber	LSR 	R0, R0, #6 				; shift necessary so that the random number can
				POP 	{LR} 					; be represented using 8 decimal digits (< 9999999)
				MOV 	PC, LR 					; because of using bcd_convert routine that can only
 												; represent decimals up to 8 digits