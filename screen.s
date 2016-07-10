;---------------------------------------------------------------------------------
; LCD screen utility methods
; Krzysztof Koch
; 19th Feb 2016
;
; Last edit: 13th April 2016
; 
; Methods to communicate with the HD44780 LCD controler. 
; 
; (Tab size - 4)
;---------------------------------------------------------------------------------


; ----------------------------------SET UP LCD------------------------------------
; Clear the screen, set the cursor to upper-left position and make it move to the right
; arguments:
;	R0 - SVC call number
; 	R1 - command issued to the LCD screen controller
;	R2 - makes HD44780 controller interpret R1 value as command
; local registers:
; 	R4 - pointer to the SETUP commands table
; 	R5 - loop counter for the table

LCDSetup 		PUSH	{R4-R5, LR} 		
				ADR 	R4, setUpCommands 		; load the pointer to the table with commands for
				MOV 	R5, #0 					; LCD init, zero the offset register (loop counter)
nextLCDCommand	LDRB 	R1, [R4, R5] 			; load the next command		
				MOV 	R0, #MaxSVC 			; load other arguments
				MOV		R2, #LCDCommand
				BL 		printChar 				; issue the command
				ADD 	R5, R5, #1 				; update offset, increment the counter
				CMP 	R5, #noOfSetupCmds 		
				BLT 	nextLCDCommand
				POP 	{R4-R5, LR} 			; return if no more commands to set up the LCD
				MOV 	PC, LR					



;---------------------------------PRINT CHARACTER------------------------------ 
; Output the given character or issue a command to the HD44780 LCD controller
; Arguments:
; 	R0 - the previous mode (supervisor or user) from which the call was made. We need 
;      	 to know which LR to use and which mode to come back to.
;      	 If R0 == (number of SVC calls implemented) then come back to user mode. Otherwise
;      	 R0 should be 1 as thats the number of SVC call for printChar
; 	R1 - character or command to be written to LCDs controller
; 	R2 - controls the behaviour of LCD once character is being written
; Local Registers:
; 	R4 - pointer to LEDs data register (status + 4) / pointer to character count memory location 
; 	R5 - contains the bitmask for testing the readiness of LCD controller / characters already printed
; 	R6 - used to check if LCD controller ready 

printChar		CMP 	R0, #MaxSVC				; POP old R4 (before SVC table pointer) if this 
				POPNE 	{R4} 					; is the SVC call
				PUSH 	{R4-R6}					; push the registers used in the subroutine on stack
				MOV		R4, #IOspace			; load the address of LCDs data register
				MOV		R5, #readyCtlr 			; Set to read ‘control’ with data bus direction 
				STRB	R5, [R4, #ctrlReg]		; as input {R/W=1, RS=0} (Port B)

notReady		ORR		R5, R5, #enableBus		; Enable bus (E :=1)  (Port B)
				STRB	R5, [R4, #ctrlReg]
				LDRB	R6, [R4, #dataReg]    	; Read LCD status byte)	(Port A)
				AND 	R5, R5, #disableBus		; Disable bus (E :=0) (Port B)
				STRB	R5, [R4, #ctrlReg]    
				ANDS 	R6, R6, #isReady
				BNE		notReady				; If bit 7 of status byte was high repeat from  
												; notReady
				STRB	R2, [R4, #ctrlReg]		; set the control according to contents of R2
				STRB	R1, [R4, #dataReg]		; output desired byto onto data bus (Port A)
				ORR		R2, R2, #enableBus 		; Enable bus (E :=1)  (Port B)
				STRB	R2, [R4, #ctrlReg]
				AND 	R2, R2, #disableBus		; Disable bus (E :=0) (Port B)
				STRB	R2, [R4, #ctrlReg]	
 			
finishPrint		POP 	{R4-R6}  				; pop registers from stack
				CMP		R0, #MaxSVC    			; if past mode was priviliged, return using 
				MOVEQ   PC, LR 					; LR_{priviliged}
				MOVS 	PC, LR 					; table in OS) and return using LR_user



;-----------------------------PRINT BINARY CODED DECIMAL-----------------------------
; Prints number in Binary Coded Decimal form in R0
; arguments: 	
;	R0 - Binary coded decimal to print
; local regs: 
; 	R4 - temporarily holds the BCD number to print
; 	R5 - pointer to BCD digit shifts table, which contains information about shifst needed to get
; 		 digit N in the 4 least significant bits
; 	R6 - loop counter and offset for bcdShifts table
; 	R7 - shift value

printBCD  		PUSH 	{R4-R7, LR}
				MOV 	R4, R0				 	; move the argument, otherwise overwritten
				ADR 	R5, bcdShifts 			; load the pointer to the bcdShifts
				MOV 	R6, #0 					; reset the loop counter

nextBCD			LDRB	R7, [R5, R6] 			; load the next shift value
				LSR 	R0, R4, R7 				; print the bcd digit in the 4 lest significant digits
				BL 		printHex
				ADD 	R6, R6, #1 				; update the loop counter and check if all digits 
				CMP 	R6, #bcdCount 			; already. If so terminate
				BLT 	nextBCD

				POP 	{R4-R7, LR} 			; return from the routine restoring registers
				MOV 	PC, LR 					



;----------------------------------PRINT STRING-------------------------------------
; Print String with R0 pointing to it.
; arguments: 	
;	R0 - starting address of the string to print
; local regs: 
; 	R4 - pointer to the table with values to be passed in R2 for SVC call for special command
; 		 issuing
; 	R5 - points to the next character to print

printString		PUSH 	{R4-R5, LR}				; push the registers used in the subroutine on stack
				MOV 	R5 ,R0
nextChar		LDRB	R1, [R5], #1			; load the next character or command
				CMP		R1, #NULL 	 			; check if end of string
				POPEQ 	{R4-R5, LR} 			
				MOVEQ 	PC, LR          		; return from routine 

				CMP 	R1, #noOfCmdsImpl
				MOVGE	R2, #ctrlWriteChar
				MOVLT 	R2, #LCDCommand
				ADRLT 	R4, LCDCmdsCodes
				LDRLTB 	R1, [R4, R1] 					
				MOV 	R0, #PRINT_CHAR
				SVC 	1  						; print character
				B 		nextChar	 			; branch back for another call to PrintChar




;------------------------------HEXADECIMAL PRINT------------------------------
; Display a hexadecimal digit on the LCD screen
; arguments: 	
;	R0 - hex value to print
; local registers
;	R4 - control signal for print char

printHex		PUSH 	{R4, LR} 				
				AND 	R0, R0, #maskOtherDigits ; get rid of other digits
				ADD 	R1, R0, #ASCIIoffset 	; convert from BCD to ASCII	
				MOV 	R0, #PRINT_CHAR			; change SVC vector to print chars
				MOV 	R2, #ctrlWriteChar 		; set controls to printing chars
				SVC 	1						; print
				POP 	{R4, LR} 				; return from the routine restoring
				MOV 	PC, LR 					; registers



; ---------------------------------DEFINITIONS--------------------------------------		
dataReg 		EQU 	0 						; offset from IO space base to LCD data reg
ctrlReg  		EQU 	4 						; offset from IO space base to LCD control reg
readyCtlr		EQU		0x24					; setup for checking readiness of controller
isReady			EQU		0x80 					; bitmask to test LCDs readiness
enableBus		EQU 	0x01 					; enable the bus between LCD controller mem space
disableBus		EQU 	0xFE 					; disable the bus between LCD controller mem space

; Two types of operations that can be performed on the LCD controller
LCDCommand 		EQU 	0x20 					; control bitmask for issueing a command
ctrlWriteChar	EQU		0x22 					; control bitmask for writing an ordinary character

; ASCII codes for various special characters - commands to controller
NULL			EQU		0x00  					; End of string 
FF 				EQU 	0x01					; Form Feed 	
FFdata			EQU		0x01									
LF 		 		EQU		0x02					; Line Feed 
LFdata 			EQU		0xC0			
END 			EQU     0x03 					; Jump to the last cell on the LCD screen
ENDdata			EQU		0xCF							
HOME 			EQU     0x04 					; Cursor Home	
HOMEdata		EQU		0x80									
BACK 			EQU     0x05 					; Backwards Entry mode 									
FORW 			EQU		0x06 	 				; Forwards Entry mode
		 			


noOfCmdsImpl 	EQU 	7 						; number of control commands for LCD implemented
LCDCmdsCodes 	DEFB 	0x00, 0x01, 0xC0, 0xCF 	; control bit patterns for various special ASCII
				DEFB 	0x80, 0x07, 0x06 		; ASCII characters
				ALIGN 

; Commands for LCD setup
noOfSetupCmds 	EQU 	2 						; number of commands
setUpCommands 	DEFB 	0x01, 0x06 				; commands to be issued to the LCD at setup
				ALIGN

; Binary Coded Decimals printing definitions
maskOtherDigits	EQU 	0x0000000F 				; clear all bits except for 4 least significant
ASCIIoffset 	EQU 	48 						; ASCII value for '0'
bcdCount		EQU 	8 						; BCD digits that can be displayed (fit in 1 register)
bcdShifts 		DEFB 	28, 24, 20, 16 			; shifts needed to get BCD digits for printing
				DEFB 	12,	8, 4, 0

