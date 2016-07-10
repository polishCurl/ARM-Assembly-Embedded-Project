;--------------------------------------------------------------------------------------
; Dispatcher
; Krzysztof Koch
; 28th April 2016
;
; Last edit: 28th April 2016
; 
; User program to present Pulse-Width-Modulation on a given LED.
; 
; (Tab size - 4)
;--------------------------------------------------------------------------------------


dispatcher		MOV 	R5, #GreenLeft
				BL 		pwmOutput

pwmKeyTest		MOV 	R0, #READ_KEYBOARD		; poll the keyboard											
				SVC 	4
				CMP 	R0, #keyNoTotal 		; if no key pressed jump to buttons polling
				BGE 	pwmButtonTest
				MOV		R4, R0 	 				; otherwise, store the character in R4

notReleasedKey	MOV 	R0, #READ_KEYBOARD 		; keep checking if the same key is still pressed
				SVC 	4 						
				CMP		R0, R4 					
				BEQ 	notReleasedKey
				
				MOV 	R0, R4 					; run the method that analyses the key pressed
				BL 		processKey
				BL 		pwmOutput

pwmButtonTest 	MOV 	R0, #READ_BUTTONS 		; poll the on-board buttons
				SVC 	3
				CMP 	R0, #0
				BEQ 	modulate 				; if no button pressed, perform PWM
				MOV 	R4, R0

notReleasedBtn	MOV 	R0, #READ_BUTTONS 		; keep checking if the same button is still pressed
				SVC 	3 						
				CMP		R0, R4 					
				BEQ 	notReleasedBtn

				MOV 	R0, R4 
				TST 	R4, #lowPressed 		
				MOVNE 	R0, #EXIT 				
				SVCNE 	0
				TST 	R4, #upPressed 		
				BNE 	changeLED
				

modulate 		MOV 	R0, R5
				BL 		pwmLED
				B 		pwmKeyTest

	
changeLED 		ADD 	R5, R5, #1
				CMP 	R5, #numberOfLEDs
				MOVEQ 	R5, #0
				B 		modulate

programsToRun 	DEFW 	calcName
				DEFW 	pwmName	

calcName 		DEFB 	"Calculator"
				ALIGN
pwmName			DEFB 	"PWM Tester"
				ALIGN

"PWM Tester"			

