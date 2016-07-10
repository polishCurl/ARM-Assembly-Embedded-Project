;----------------------------------------------------------------------------------
; Keyboard and Buttons utility methods
; Krzysztof Koch
; 15th March 2016
;
; Last edit: 6th May 2016
; 
; External keyboard and on-board buttons utility methods
; 
; (Tab size - 4)
;----------------------------------------------------------------------------------


; -----------------------------------SET UP KEYBOARD----------------------------------
; Set the pin directions in selected PIO port for scanning keyboards - 4:0 to input and 7:5 to output 
; local registers:
;	R4 - pointer to the starting address of FPGA memory space
; 	R5 - bit pattern to write to data and control registers of keyboard pins

keyboardSetup	PUSH 	{R4-R5}
				MOV 	R4, #FPGAspace 			; load the FPGA base address
				MOV 	R5, #pinDirKeyboard 	; set pin directions for both keyboards
				STRB 	R5, [R4, #keypad1CtrlAdr]
				STRB 	R5, [R4, #keypad2CtrlAdr]
	
				MOV 	R5, #noScan			 	; initially switch off keyboard scans 
				STRB 	R5, [R4, #keypad1DataAdr]
				STRB 	R5, [R4, #keypad2DataAdr]
				POP 	{R4-R5}
				MOV 	PC, LR 					; return [OS.s]



; ----------------------------------SCAN ALL KEYS------------------------------------
; Scan both keyboards and the two buttons on the board. Pass the resulting 26-bits to 'updateKeys' method
; local registers:
; 	R0 - contains current key states, keeps being updated with each method called
; 	R1 - extra argument to called methods (keyboard to scan/button to scan)

				; Scan the keyboard (3 rows) and combine the resulting bit patterns
scanAllKeys		PUSH 	{R0-R1, LR} 	
				MOV 	R0, #0 					; reset bit patterns with currently pressed keys 
				MOV 	R1, #keypad1DataAdr	 	; scan lower left keyboard
				BL  	scanKeyboard		
				MOV 	R1, #lowButtonTst 		; scan lower of the buttons on board
				BL 		scanButton
				MOV 	R1, #upButtonTst 		; scan upper of the buttons on board
				BL 		scanButton
				MOV 	R1, #keypad2DataAdr		; scan lower right keyboard
				BL 		scanKeyboard	 		
				BL 		updateKeys 				; call updateKeys with key states in R0
				POP 	{R0-R1, LR}
				MOV 	PC, LR 					; return to the main IRQ handler [OS.s]



; ----------------------------------SCAN KEYBOARD------------------------------------
; Scan the keyboard specified in R1, and append the result to R0
; arguments:
; 	R0 - current scan result
; 	R1 - offset of the keyboard to scan (from FPGA space start)
; returns:
; 	R0 - updated scan result with the keyboard scan
; local registers:
; 	R4 - pointer to the starting address of FPGA memory space / IO space
; 	R5 - current bitmask for scaning particular row / result of polling buttons on the board 
; 	R6 - output from keyboard or button (key pressed or not)
; 	R7 - pointer to table storing bitmasks for scanning individual keyboard rows
; 	R8 - loop counter 

scanKeyboard	PUSH 	{R4-R8}
				MOV 	R4, #FPGAspace 			; load the FPGA base address
				ADR 	R7, rowScanBitmasks 	; load the table with bitmasks for scanning rows
				MOV 	R8, #noOfRows 			; loop counter to control the number of scans

nextRow			LDRB 	R5, [R7], #1			; load the bitmask to scan the next row
				STRB 	R5, [R4, R1]			; scan next row
				LDRB 	R6, [R4, R1]			; load the button states in tested row
				AND 	R6, R6, #scanRow 		; filter out input bits [3:0]
				ADD 	R0, R6, R0, LSL #4		; add the result of latest scan with the old one
				SUBS 	R8, R8, #1				; shifter by 4 to make space for it. Update loop counter
				BNE 	nextRow 				; Repeat for remainding rows until all are scanned

				MOV 	R5, #noScan 			; switch off keyboard scans until next IRQ
				STRB 	R5, [R4, R1]		
				POP 	{R4-R8}
				MOV 	PC, LR



; -----------------------------------SCAN BUTTONS-------------------------------------
; Scan the button specified in R1, and append the result to R0
; arguments:
; 	R0 - current scan result
; 	R1 - offset of the button to scan (from the base IO space)
; returns:
; 	R0 - updated scan result with the keyboard scan
; local registers:
; 	R4 - pointer to the starting address of the IO space
; 	R5 - pressed (1) / not pressed (0), value to append

scanButton		PUSH 	{R4-R5}
				MOV 	R4, #IOspace 			; load the I/O space base address
				LDRB 	R4, [R4, #buttonsAdr] 	; read the byte from buttons address
				TST 	R4, R1					; test if button pressed and append the  								
				MOVEQ 	R5, #notPressed 		; result to the one already received from scanning
				MOVNE 	R5, #pressed 			; the keyboard
				ADD 	R0, R5, R0, LSL #1 	
				POP 	{R4-R5}
				MOV 	PC, LR



; --------------------------------UPDATE KEY STATES--------------------------------
; Update the keyboards key states using the value in R0. Map this bit pattern to appropriate
; bytes in memory space reserved for storing key states. Update states using the 
; debouncing principle with shifting updated byte's value left by 1 on each update. This means
; we store the history of last eight scans for each button.
; local registers:
;	R4 - pointer to 'key states' memory location
; 	R5 - pointer to the table containing offsets for bytes in 'keyStates'
; 	R6 - counter of keys to update (loop counter)
; 	R7 - the offset read from 'keyAdrOffsets' table, points to byte address we are going to update
;  	R8 - current button state, value we are going to append to a specific byte
; 	R9 - updated key state to be stored in memory
; arguments:
;	R0 - its 26 least significant bits represent 26 current button states (1 for pressed) 

updateKeys		PUSH 	{R4-R9}
				ADR 	R4, keyStates 			; load the pointer to the memory for storing key states and
				ADR 	R5, keyAdrOffsets 		; one to the table containing offsets in 'keyStates'
				MOV 	R6, #totalButtonNo  	; loop counter, counts number of bits still to be considered
				ADD 	R6, R6, #1

nextKey			SUBS 	R6, R6, #1 				; decrement the loop counter
				BEQ 	finishUpdate	 		; terminate loop if all bytes already updated
				LDRB 	R7, [R5], #1 			; otherwise load the byte offset for given character
				LSRS 	R0, R0, #1				; check if given key pressed by shifting left and then
				MOVCS 	R8, #pressed 	 		; investigating the Carry flag to set the value to be
				MOVCC 	R8, #notPressed  		; written to the key's memory location
				LDRB 	R9, [R4, R7]
				ADD 	R9, R8, R9, LSL #1 		; update the key's memory location by dropping the msb
				STRB 	R9, [R4, R7] 			;  and appending the new lsb by shifting the old value left
				B 		nextKey 				; by 1, start the new iteration

finishUpdate	POP 	{R4-R9} 				
				MOV 	PC, LR 					; return [keyboardAndButtons.s]



; ----------------------------------POLL KEYBOARD----------------------------------
; Check if any button is pressed (after debouncing). If so, return the index of first button
; which tested for being pressed is positive.
; argument: 
;	R0 - indicates if the mode from which this method called was priviliged or not
; returns: 
;	R0 - index of the button pressed. If no buttons pressed, returns <the total number of keys> (12).
; local registers:
;	R4 - debounced key states table pointer
; 	R5 - loop counter (contains the current key index we are testing)
; 	R6 - values read from key states table for each key

keyboardPOLL	POP 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4-R6} 				; save registers used in this routine
				
				ADR  	R4, keyStates 			; key states table pointer
				MOV 	R5, #0 					; zero the key counter (loop counter)
												
nextKeyPOLL		LDRB 	R6, [R4, R5] 			; poll the key
				CMP 	R6, #testPressedDeb 	; check if pressed (of course debouncing already done)
				BEQ 	keyPressedFound 		; if so, we've got a key to return so terminate loop
				ADD 	R5, R5, #1 				; increment the loop counter
				CMP 	R5, #keyNoTotal
				BNE  	nextKeyPOLL 			; repeat for the next key
			
keyPressedFound	CMP 	R0, #MaxSVC
				MOV 	R0, R5 					; move the value to be returned
				POP 	{R4-R6}
				MOVEQ   PC, LR 					; if past mode was priviliged, return using LR_{priviliged}
				MOVS 	PC, LR 					; otherwise and return using LR_user [USER_PROGRAM.s]



; -----------------------------------POLL BUTTONS-----------------------------------
; Check if any of the buttons on the board is pressed
; arguments: 
;	R0 - indicates if the mode from which this method called was priviliged or not
; returns: 	
;	R0 - bit 2 raised if lower button pressed, bit 1 raised - upper. Zero otherwise
; local registers: 
;	R4 - pointer to the KeyStates table
; 	R5 - temporarily holds the result of polling buttons
; 	R6 - accumulates the results of polling

buttonsPOLL		POP 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4-R6} 				
				ADR  	R4, keyStates 			; load the keyStates table pointer
				MOV 	R6, #0 					; reset the register that will accumulate polling results
												
				LDRB 	R5, [R4, #lowButtonAdr] ; read the debounced status byte of lower button
				CMP 	R5, #testPressedDeb 	; test if button pressed
				MOVEQ 	R6, #lowPressed
				BEQ 	buttonFound

				LDRB 	R5, [R4, #upButtonAdr] 	; read the debounced status byte of upper button
				CMP 	R5, #testPressedDeb 	; test if button pressed
				MOVEQ 	R6, #upPressed 			; combine this poll result with the previous one

buttonFound		CMP		R4, #MaxSVC    			; check the SVC number to see which mode to come back to
				MOV 	R0, R6 					; the value is returned in R0 so move it
				POP 	{R4-R6} 				
				MOVEQ   PC, LR 					; if past mode was priviliged, return using LR_{priviliged}
				MOVS 	PC, LR 					; otherwise and return using LR_user [USER_PROGRAM.s]



; --------------------------------------DEFINITIONS--------------------------------------
keypad1DataAdr 	EQU 	0x2 					; keypad data register offset (1st keyboard)
keypad1CtrlAdr 	EQU 	0x3 					; keypad control register offset (1st keyboard)
keypad2DataAdr 	EQU 	0xE 					; keypad data register offset (2st keyboard)
keypad2CtrlAdr 	EQU 	0xF 					; keypad control register offset (2st keyboard)
buttonsAdr		EQU 	0x4 					; buttons offset

pinDirKeyboard 	EQU 	0x1F 					; set direction register 4:0 to input and 7:5 to output
totalButtonNo 	EQU 	26 						; total number of keys scanned (12 + 12 keyboard + 2 on silicon)
keyboardKeyNo 	EQU 	12 						; number of keys in a keyboard
keyNoTotal 		EQU 	24 						; total number of keys in both keyboards
noOfRows 		EQU 	3 						; number of rows to scan
scanRow 		EQU 	0x0F 					; bitmask to tests if any button pressed
noScan 			EQU 	0x0 					; bitmask that makes no row be scanned

lowButtonTst 	EQU 	0x80 					; bitmasks for testing if lower button pressed
upButtonTst		EQU 	0x40 					; bitmasks for testing if upper button pressed
testPressedDeb 	EQU 	0xFF 					; 0xFF pressed, not pressed otherwise (after debouncing)
lowButtonAdr 	EQU 	24						; offset for lower button byte in the 'keyStates'
upButtonAdr 	EQU 	25 						; offset for upper button byte in the 'keyStates'
lowPressed		EQU 	0x2 					; bitmask that represents lower button pressed
upPressed  		EQU 	0x1 					; bitmask that represents upper button pressed

pressed 		EQU 	1 						; bit to represent that key is pressed
notPressed 		EQU 	0 						; bit to represent that key is not pressed

rowScanBitmasks DEFB 	0x20, 0x40, 0x80 		; bitmask to scan (no/first/second/third) row
				ALIGN

keyAdrOffsets 	DEFB	12, 15, 18, 21  		; offsets in memory from the keyStates base address	
				DEFB 	13, 16, 19, 22 			; they map the bits from the current scan (26bits) to
				DEFB 	14, 17, 20, 23	  		; 26 'key state' bytes			
				DEFB 	25, 24,	0, 3  			
				DEFB 	6, 9, 1, 4 				
				DEFB 	7, 10, 2, 5  			
				DEFB 	8, 11					
				ALIGN
 
keyStates 		DEFS 	26, 0 					; store the key states as bytes 
				ALIGN							
							
					