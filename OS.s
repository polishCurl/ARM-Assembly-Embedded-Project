;---------------------------------------------------------------------------------------
; Operating system (Supervisor) code  
; Krzysztof Koch
; 2nd Mar 2016
;
; Last edit: 6th May 2016
; 
; The Operating System implemented does the following:
; 1. Allocate memory for Supervisor, Interrupt and User mode stacks
; 2. Create exception vector table (reset, SVC and IRQ)
; 3. Reset the LCD screen (clear it, move cursor home and make cursor go right without shift)
; 4. Create the SVC and IRQ handlers.
; 5. Implements system timer that measures time in 100ms since system initialisation [timestampAdr]
; 6. Scan external keyboard and two button on the board on every timer interrupt (1ms)
; 7. Jump to selected user program after system initialisation 
; 
; Implemented Supervisor Calls:
; 1. switch between user programs
; 2. printing a character to LCD screen
; 3. polling the timer 
; 4. polling the buttons on the board
; 5. polling the external keyboard
; 6. get random unsigned 32-bit number
; 7. switch specified LED on/off
; 8. store the state of LEDs so that they are not affected by printing on LCD
; 9. restore the LEDs state
; 10. write to buzzer
;
; Implemented Interrupt Routines:
; 1. Timer interrupt - every millisecond, scan the keyboards and buttons on the board, 
;    generate a new random number and update the timer 
; 
; (Tab size - 4)
;----------------------------------------------------------------------------------


; ----------------------------INITIALISE EXCEPTION VECTORS-------------------------
				ORG 	0x0000_0000
				B 		reset 					; 00000000 - Reset
				B 		.						; 00000004 - Undefined instruction	
				B 		supervisor 				; 00000008 - SVC 
				B 		.						; 0000000C - Prefetch abort
				B 		.						; 00000010 - Data abort	
				NOP
				B 		interrupt				; 00000018 - IRQ	
				B 		.						; 0000001C - FIQ	



; ---------------------INITIALISE STACK POINTERS AND ALLOCATE STACK---------------
				DEFS 	128, 0					; allocate memory for Supervisor mode stack
superStack 										; supervisor stack pointer
				ALIGN
				DEFS 	128, 0					; allocate memory for IRQ stack
irqStack										; user stack pointer
				ALIGN
				DEFS 	128, 0					; allocate memory for User Mode stack
userStack										; user stack pointer
				ALIGN



; -----------------------------------SVC CALLS-----------------------------------
SVCtable 		DEFW    switchProgram 			; finish user program execution, return to OS
				DEFW   	printChar   			; print Character [LCD.s]
				DEFW   	timestampPOLL 			; poll timer [timer.s]
				DEFW   	buttonsPOLL 			; poll the buttons on board [keyboardAndButtons.s]
				DEFW 	keyboardPOLL 			; poll the external keyboard [keyboardAndButtons.s]
				DEFW 	getRandom 				; return a random 32-bit unsigned number [random.s]
				DEFW 	switchLED 				; turn specified LED on/off [LED.s]
				DEFW 	storeLEDs 				; save the state of LEDs in another mem location [LED.s]
				DEFW 	restoreLEDs 			; load the state of LEDs from another mem location [LED.s]
				DEFW  	buzzerWrite 			; write to buzzer [buzzer.s]



; -----------------------------PROCESS CONTROL BLOCK------------------------------
pcb 			DEFW 	calculator 				; calculator user program [calculator.s]
				DEFW 	pwmTest 				; Pulse-width modulation tester program [PWMtest.s]



; -----------------------------SYSTEM INITIALISATION-------------------------------
; Set up interrupts, and the keyboard. Then jump to code that thas inter-program setup
; methods

reset			ADR  	SP, superStack 			; load supervisor stack pointer
				BL 		IRQsSetup 				; set up interrupts
				BL 		keyboardSetup			; set up the keyboard [keyboardAndButtons.s]
				B 		switchProgram 			; pick a user program to run



; --------------------------------SYSTEM TERMINATION-------------------------------
terminate		B 		terminate				; terminate system



; ----------------------------------PROGRAM SWITCH---------------------------------
; Procedure for switching from one user program to another. Sets up the LCD screen and LEDs
; as these have to be intitialised whenever a new program is run. Then it picks up the next
; program from the PCB table. Then switches back to user mode with interrupts re-enabled
; Register use:
; 	R4 - pointer to the memory location with index of next program to run / pointer to PCB
; 	R5 - index of next program to run / also used to change mode to USR
; 	R6 - used for calculating the index of next program to run

switchProgram	BL 		LCDSetup				; set up the LCD screen [LCDscreen.s]
				BL 		setupLEDs 				; set up LEDs on board [LED.s]
				ADR  	R4, programRunning
				LDR 	R5, [R4] 				; get the next program to run
				ADD 	R6, R5, #1
				CMP 	R6, #noOfUsrPrograms 	; recompute the index of program to follow
				MOVEQ	R6, #0
				STR 	R6, [R4]
				ADR 	R4, pcb 				; load the addres of PCB

				MRS 	R6, CPSR 				; switch to user mode
				BIC 	R6, R6, #clearMode	
				ORR 	R6, R6, #userMode 	
				BIC 	R6, R6, #enableIRQinCPU ; enable interrupts in CPU
				MSR 	CPSR, R6				; update CPSR
				ADR 	SP, userStack 			; reset user mode SP back to the bottom of stack
				MOV 	R0, #switchBeepLen 		; notify the user about the change of program
				MOV 	R1, #switchBeepNo 		; to be executed with a few beeps
				BL 		beepBeep
				LDR 	PC, [R4, R5, LSL #2] 	; load the next program to run



; --------------------------------TRAP ROUTINE FOR SVCs----------------------------
; Identify the SVC call and then run the right handler
; arguments: 	
;	R0 - SVC number
; local regs: 	
;	R4 - pointer to the SVC jump table

supervisor		CMP 	R0, #MaxSVC				; check the SVC call number upper limit 
 				BHS 	terminate 				; terminate if reached
 				PUSH 	{R4} 					; store reg used later used as pointer to SVC table
 				ADR 	R4, SVCtable 			; load SVC table pointer
 				LDR 	PC, [R4, R0, LSL #2]	; calculate SVC table address



; --------------------------------TRAP ROUTINE FOR IRQs----------------------------
; Recognise the interrupt source and then handle it
; local registers:	
; 	R4 - pointer to the base of I/O address space
; 	R5 - bitmask representing the interrupt source
; 	R6 - result of identification test for interrupt source			

interrupt		PUSH 	{R4-R6, LR}				; preserve the state
				MOV 	R4, #IOspace 			; load the Interrupt sources
				LDR 	R5, [R4, #IRQsAdr]		

				ANDS 	R6, R5, #timerIRQVec	; check if timer Interrupt. If so, service it
				BLNE 	timerIRQ				

 				POP 	{R4-R6, LR} 			; restore the register values
				SUBS 	PC, LR, #4				; exit the Interrupt (Decrement the LR first)



; ---------------------------------TIMER IRQ ROUTINE-------------------------------
; Updates the timestamp and scans the keyboard to update key states
; arguments: 	
;	R4 - pointer to Interrutp sources memory location
;	R5 - interrupt source (timer)

timerIRQ 		PUSH 	{R4-R5, LR} 	
				LDR 	R5, [R4, #IRQsAdr]		
				BIC 	R5, R5, #timerIRQVec	; clear the interrupt so it is serviced once
				STRB 	R5, [R4, #IRQsAdr]	
				BL 		timestamp 				; update the timestamp
				BL 		scanAllKeys				; check if any buttons pressed [keyboardAndButtons.s]
				BL 		generateRandom 			; create next pseudo-random number [random.s]

				POP 	{R4-R5, LR} 			
				MOV 	PC, LR



; --------------------------------SET UP INTERRUPTS-------------------------------
; Enable only specific interrupts and set the IRQ stack pointer
; local registers: 	
;	R4 - used for changing ARM mode, also a pointer to the base I/O address space
; 	R5 - interrupts sources enabled

IRQsSetup 		PUSH 	{R4-R5}
				MRS 	R4, CPSR 				; change mode to Interrupt
				BIC 	R4, R4, #clearMode	
				ORR 	R4, R4, #IRQMode 	
				MSR 	CPSR, R4		
				ADR 	SP, irqStack 			; load IRQs stack pointer
				BIC 	R4, R4, #clearMode		; change back to Supervisor mode
				ORR 	R4, R4, #SVCMode 
				MSR 	CPSR, R4

				MOV 	R4, #IOspace 			; load the I/O space base address
				MOV 	R5, #activeIRQs 		; enable only specific iterrupt sources
				STRB 	R5, [R4, #IRQEnablesAdr] 	
				POP 	{R4-R5}
				MOV 	PC, LR 					; return from the method



; ---------------------------------DEFINITIONS--------------------------------------		
; I/O addresses
IOspace 		EQU 	0x10000000				; starting address of I/O address space
IRQsAdr 		EQU 	0x18  					; interrupts active bits offset
IRQEnablesAdr 	EQU 	0x1C  					; interrupt enable bits offset	

; FPGA addresses	
FPGAspace 		EQU 	0x20000000 				; starting address of FPGA address space 

; ARM modes	
userMode   		EQU		0x10 					; append User mode
SVCMode 		EQU 	0x13 					; append Supervisor mode
IRQMode 		EQU 	0x12 					; append Iterrupt mode
clearMode  		EQU		0x1F 					; clear mode field

; IRQ definitions
activeIRQs		EQU		0x01					; enabled IRQs (only timer can interrupt)
enableIRQinCPU 	EQU 	0x80 					; enable IRQs inside the ARM CPU					
timerIRQVec 	EQU 	0x01 					; timer IRQ vector

; SVC calls 
EXIT 			EQU 	0 						; SVC call numbers
PRINT_CHAR		EQU 	1
TIME 			EQU 	2
READ_BUTTONS 	EQU 	3
READ_KEYBOARD 	EQU 	4
RAND 			EQU 	5
LED_WRITE 		EQU 	6
LED_STORE 		EQU 	7
LED_LOAD 		EQU 	8
BUZZER_WRITE 	EQU 	9

; Extra definitions
MaxSVC 			EQU 	10						; upper limit for the index of exception vector		

; Program-switch definitions
noOfUsrPrograms EQU  	2 						; number of user programs loaded into memory
programRunning 	DEFW 	0 						; current user program in execution
switchBeepLen 	EQU 	40
switchBeepNo 	EQU 	4

; ------------------------------------INCLUDES---------------------------------------		
INCLUDE 		bcd.s 							; BCD conversion utility
INCLUDE 		keyboardAndButtons.s 			; Uxternal keyboard and on board buttons utilities
INCLUDE     	LCDscreen.s 					; LCD screen utilities
INCLUDE     	time.s 							; System timing utilities
INCLUDE     	random.s 						; Random numbers utilities
INCLUDE 		math.s 							; Mathematical function utilities
INCLUDE 		LED.s 							; Methods to control the LEDs on board
INCLUDE     	buzzer.s 						; 
INCLUDE     	calculator.s  					; User program - simple calculator
INCLUDE 		PWMtest.s 						; User program - pulse-width modulation tester
