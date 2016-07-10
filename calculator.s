;--------------------------------------------------------------------------------------
; Calculator
; Krzysztof Koch
; 12th April 2016
;
; Last edit: 6th April 2016
; 
; Calculator implementing most common integer arithmetic operations. 
; Instructions:
; 	1. You start with total equal to 0 and displayed at the bottom of LCD screen.
; 	2. To input a number, press digit buttons on the left keyboard. As you write the number
; 	   digits should appear in the top row which represents the current value
; 	3. All binary arithmetic operations take tha value from total (bottom) and the current
; 	   input value to perform (addition, division, Greatest Common Divisor etc)
; 	4. All unary operations use just the total value at the bottom (factorial etc)
; 	5. Random number generator just overwrites the total value ot the bottom
; 	6. To clear the sceen as well as all calculator memory (total and current value) press
; 	   the lower button on the on-board
; 	7. To switch the application to another press upper button on board
; 	8. This all implies that there is no '=' operator as in ordinary calculator and you first
; 	   Input a number and then you specify the operation to perform on it
;
; Register use:
;	R4 - holds the last button pressed for comparison to detect when the button was released
; 
; (Tab size - 4)
;--------------------------------------------------------------------------------------


; ===================================CALCULATOR FSM====================================
calculator	 	BL 		showTotal				; stat by displaying the total


; ----------------------------------TEST IF KEY PRESSED--------------------------------
checkKeyboard 	MOV 	R0, #READ_KEYBOARD		; poll the keyboard											
				SVC 	4
				CMP 	R0, #keyNoTotal 		; if no key pressed jump to buttons polling
				BGE 	checkButtons
				MOV		R4, R0 	 				; otherwise, store the character in R4


; --------------------------------WAITING FOR KEY RELEASE------------------------------
stillPressedKey	MOV 	R0, #READ_KEYBOARD 		; keep checking if the same key is still pressed
				SVC 	4 						
				CMP		R0, R4 					
				BEQ 	stillPressedKey


; -----------------------------------INTERPTET THE KEY---------------------------------
				MOV 	R0, R4 					; run the method that analyses the key pressed
				BL 		interptetKey
				B 		checkButtons  			; check the buttons 


; ---------------------------------TEST IF BUTTON PRESSED------------------------------
checkButtons 	MOV 	R0, #READ_BUTTONS 		; poll the on-board buttons
				SVC 	3
				CMP 	R0, #0
				BEQ 	checkKeyboard 			; if no button pressed jump to keyboard polling
				MOV 	R4, R0


; --------------------------------WAITING FOR BUTTON RELEASE---------------------------
stillPressedBtn	MOV 	R0, #READ_BUTTONS 		; keep checking if the same button is still pressed
				SVC 	3 						
				CMP		R0, R4 					
				BEQ 	stillPressedBtn


; -------------------------------INTERPRET THE BUTTON PRESSED--------------------------
				TST 	R4, #upPressed			; if upper button pressed then close the program
				MOVNE 	R0, #EXIT 				; and start the next one
				SVCNE 	0
				TST 	R4, #lowPressed	 		; if its the lower then clear the screen, and 
				BLNE 	clearTotal 				; calculator memory
				B 		checkKeyboard

; =====================================================================================



;---------------------------------------INTERPRET KEY------------------------------------
; Using value in R0 (index of the key pressed). Assign a unique binary value to it and use it
; to either update the number currently being typed (top one on screen) or if it's an arithmetic
; operator then run the method to handle that 
; Arguments:
; 	R0 - index of the key pressed
; Local registers:
; 	R4 - pointer to the table with binary codes

interptetKey	PUSH 	{R4-R6, LR}
				ADR 	R4, binaryValues 		; load the unique code for the key in R0
				LDRB 	R0, [R4, R0]  			
				CMP 	R0, #maxDigit 			; check if the key pressed was a digit or 
				BLLT 	updateDecimal 			; arithmetic operator and run the appropriate
				BLGE  	changeTotal  			
							
				POP 	{R4-R6, LR}
				MOV 	PC, LR



;-----------------------------------------SHOW TOTAL--------------------------------------
; Display the total value calculated
; Local registers:
; 	R4 - pointer to the total memory location that holds the value after arithmetic operations

showTotal 		PUSH 	{R4, LR}
				MOV 	R0, #PRINT_CHAR 		; move cursor down one line to print the result
				MOV 	R1, #LFdata 			; there
				MOV 	R2, #LCDCommand 
				SVC 	1

				ADR 	R4, total 				; load the total value, convert it to Binary Coded
				LDR 	R0, [R4] 				; Decimal and print it
				BL 		bcd_convert
				BL 		printBCD
				MOV 	R0, #PRINT_CHAR 		; move cursor back to top left position
				MOV 	R1, #HOMEdata
				MOV 	R2, #LCDCommand 
				SVC 	1
				POP 	{R4, LR}
				MOV 	PC, LR		



;-----------------------------------------CLEAR TOTAL-------------------------------------
; Reset calculator by clearing both total and currentDecimal memory locations. Also clears the
; screen and moves cursor home.
; Local registers:
; 	R4 - pointer to the total memory location that holds the value after arithmetic operations
; 	R5 - pointer to the currentDecimal that holds the current number to be added/subtracted

clearTotal 		PUSH 	{R4-R5, LR}

				MOV 	R0, #PRINT_CHAR 		; clear screen and move cursor home
				MOV 	R1, #FFdata
				MOV 	R2, #LCDCommand 
				SVC 	1

				ADR 	R4, total 				; zero the total and currentDecimal memory locations
				MOV 	R5, #0
				STR 	R5, [R4]
				ADR 	R4, currentDecimal
				STR 	R5, [R4]
				BL 		showTotal
				MOV 	R0, #beepCalcTime 			; notify that a clear button is pressed with a beep
				BL 		beep

				POP 	{R4-R5, LR}
				MOV 	PC, LR		



;---------------------------------------SHOW OPERATION------------------------------------
; Show the last arithmetic operation performed
; Arguments:
; 	R0 - operation performed (its binary code)
; Local registers:
; 	R4 - temporarily holds the argument in R0
; 	R5 - pointer to the table with ASCII representations of different keys

showOp			PUSH 	{R4-R5, LR}
				MOV 	R4, R0
				MOV 	R0, #PRINT_CHAR 		; move the cursor to the bottom right position
				MOV 	R1, #ENDdata
				MOV 	R2, #LCDCommand 
				SVC 	1

				ADR 	R5, keyASCIICodes 		; load the ASCII representation of the operation				
				LDRB 	R1, [R5, R4]  			; performed and print it
				MOV 	R0, #PRINT_CHAR 		
				MOV 	R2, #ctrlWriteChar
				SVC 	1		
			
				POP 	{R4-R5, LR}
				MOV 	PC, LR



;------------------------------------UPDATE CURRENT NUMBER---------------------------------
; Using the digit in R0 (in binary), update the value in currentDecimal and print the new digit
; Arguments:
; 	R0 - binary representation of the digit to append
; Local registers:
; 	R4 - pointer to the currentDecimal that holds the current number to be changed
; 		 also, pointer to table with ASCII values of buttons
; 	R5 - value in currentDecimal
; 	R6 - multiplier, appending digit means multiplying existing value by 10 and adding the digit
	
updateDecimal  	PUSH 	{R4-R6, LR}
				ADR 	R4, currentDecimal 		; load the current number to be added/subtracted
				LDR 	R5, [R4]
				MOV 	R6, #10 				; append the new digit using multiplication and 
				MLA 	R5, R5, R6, R0 			; addition
				STR 	R5, [R4] 

				ADR 	R4, keyASCIICodes		; load the pointer to the table with ASCII codes
				LDRB 	R1, [R4, R0] 			; print the new digit
				MOV 	R0, #PRINT_CHAR 		
				MOV 	R2, #ctrlWriteChar
				SVC 	1
				POP 	{R4-R6, LR}
				MOV 	PC, LR



;----------------------------------------CHANGE TOTAL------------------------------------
; Using the binary code in R0, run the appropriate arithmetic operation. Then display the symbol
; of the operation performed as well as the updated total
; Arguments:
; 	R0 - arithmetic operation to perform
; Local registers:
; 	R4 - pointer to currentDecimal memory location
; 	R5 - pointer to total memory location
; 	R6 - temporarily holds the argument in R0
; 	R7 - index to the arithmeticOps table where airthmetic op handlers are stored (their pointers)
; 	R8 - pointer to the arithmeticOps table

changeTotal 	PUSH 	{R4-R8, LR} 			; load the current decimal and total values
				MOV 	R6, R0 
				ADR 	R4, currentDecimal
				ADR 	R5, total
				LDR 	R1, [R4]
				LDR 	R0, [R5]

				SUB 	R7, R6, #maxDigit 		; calculate the index and then run the corresponding
				ADR 	R8, arithmeticOps 		; method from arithmeticOps table
				MOV 	LR, PC
				LDR 	PC, [R8, R7, LSL #2]

finishOp		STR 	R0, [R5]  				; clear currentDecimal and update total memory
				MOV 	R7, #0 					; location
				STR 	R7, [R4]		
				MOV 	R0, #PRINT_CHAR 		; clear screen and move cursor home
				MOV 	R1, #FFdata
				MOV 	R2, #LCDCommand 
				SVC 	1

				MOV 	R0, R6 					; display the operation performed (its sign) and the
				BL 		showOp 					; updated total
				BL 		showTotal
				MOV 	R0, #beepCalcTime 			; notify that a key pressed with a beep
				BL 		beep

				POP 	{R4-R8, LR}
				MOV 	PC, LR		
				


; ---------------------------------DEFINITIONS---------------------------------------	
maxDigit 		EQU 	10 						; to differentiate between a digit and arithmetic op
beepCalcTime 	EQU 	100 					; beep time for arithmetic operation or 'Clear' key pressed

keyASCIICodes 	DEFB 	0x30, 0x31, 0x32, 0x33  ; ASCII values for each key on the keyboard returned by
				DEFB 	0x34, 0x35, 0x36, 0x37  ; getKey SVC call, can be used directly by the user 
				DEFB 	0x38, 0x39, 0x2B, 0x2D 	; program or remapped to print other characters
				DEFB 	0x2A, 0x2F, 0x25, 0x5E
				DEFB 	0x73, 0x67, 0x21, 0x72
				ALIGN

binaryValues 	DEFB 	0x1, 0x2, 0x3, 0x4  	; binary values associated with each key on the keyboard
				DEFB 	0x5, 0x6, 0x7, 0x8 		; I use this table so that '*' and '#' get seperated from
				DEFB 	0x9, 0xA, 0x0, 0xB 	 	; the '0' on the keyboard, as the earlier are commands
				DEFB 	0xC, 0xD, 0xE, 0xF 		; and their codes will be used as indexes to arithmeticOps
				DEFB 	0x10, 0x11, 0x12, 0x13
				ALIGN

total 			DEFW	0 						; total value after all arithmetic operations
currentDecimal 	DEFW 	0  						; number that is currently being input


noOfArithmOps 	EQU 	10 						; arithmetic operations implemented
arithmeticOps 	DEFW 	plus  	
				DEFW 	minus 		
				DEFW 	multiply 
				DEFW 	divide
				DEFW 	modulo	
				DEFW 	power
				DEFW 	squareRoot
				DEFW 	gcd
				DEFW 	factorial
				DEFW 	rand
				
				
