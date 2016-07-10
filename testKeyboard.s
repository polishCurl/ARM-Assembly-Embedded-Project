;-----------------------------------------------------------------------------------
; Keyboard test program
; Krzysztof Koch
; 10th April 2016
;
; Last edit: 13th April 2016
; 
; Polls the keyboard until a key is pressed and then released. Then prints its corresponding 
; ASCII representation on the LCD screen.
;
; Register use:
; 	R4 - pointer to the table with ASCII codes of each button - value to be printed on screen
; 	R5 - holds the returned value from READ_KEYBOARD for comparison with R0 to see if key has been
; 		 released
; 
; (Tab size - 4)
;-----------------------------------------------------------------------------------

	
testKeyboard 	ADR 	SP, userStack 			; load the user stack pointer
				ADR 	R4, keyASCIICodes		; load the pointer to the table with ASCII 
												; representations of characters on the keypad
main 			MOV 	R0, #READ_KEYBOARD		; poll the keyboard											
				SVC 	4
				CMP 	R0, #keyboardKeyNo 		; if no button pressed repeat from main
				BGE 	main
				MOV		R5, R0 	 				; otherwise, store the character in R5

stillPressed	MOV 	R0, #READ_KEYBOARD 		; keep checking if the same key is still pressed
				SVC 	4 						
				CMP		R0, R5
				BEQ 	stillPressed

				MOV 	R0, #PRINT_CHAR 		; as long as the key is released, print it
				LDRB 	R1, [R4,R5]
				MOV 	R2, #ctrlWriteChar
				SVC 	1
				B 		main  					; repeat the procedure



; ---------------------------------DEFINITIONS--------------------------------------	
keyASCIICodes 	DEFB 	0x31, 0x32, 0x33, 0x34  ; ASCII values for each key on the keyboard returned by
				DEFB 	0x35, 0x36, 0x37, 0x38 	; getKey SVC call, can be used directly by the user program
				DEFB 	0x39, 0x2A, 0x30, 0x23 	; or remapped to print other characters
				ALIGN
