.include "includes.inc"

.segment "CODE0"
.org $008000


	baseinc $008000, $008100


.proc Native_mode_NMI
	JMP [NMIFarPtr]
.endproc

.proc Native_mode_ABORT
	STP
.endproc

.proc EntryPoint
	SEI
	setaxy8
	LDA #0
	STA PPUNMI
	CLC
	XCE
	setxy16
	LDX #StackBottom
	TXS
	setxy8
	LDA #1
	PHA
	PLB
	LDA #0
	PHA
	PHA
	PLD
	JMP PerformInit
.endproc

	RTI

.proc PerformInit
.a8
	LDA #FORCEBLANK
	STA PPUBRIGHT
	LDA #0
	STA NMITIMEN
	STZ HDMAEN
	LDA #1
	STA f:ICD2CTL
	LDA GamePalettePresent
	STA byte_7E1712
	setxy16

	LDX #0
:
	STZ z:0, X
	INX
	CPX #$800
	BNE :-
	LDX #$F00
:
	STZ z:0, X
	INX
	CPX #$1700
	BNE :-

	LDX #StackBottom
	TXS
	setxy8
	CLD
	JSR ResetIO
	LDA #<Native_mode_IRQ
	STA NMIFarPtr
	LDA #>Native_mode_IRQ
	STA NMIFarPtr+1

	; TODO
.endproc


ResetIO = $0082B1
	baseinc $008166, $0086CE


.proc PollJoypadsTrampoline
	JSR PollJoypads
	RTS
.endproc


	baseinc $0086D2, $008712


.proc PollJoypads
.a8
	JSR PollMulti5
	JSR Multi5ConnectCheck
	LDA IgnorePlayer1Input
	CMP #1
	BEQ :+
	STZ Player1Input
	STZ Player1Input+1
:
	JSR SanitizePlayerDpads
	JSR UpdatePressedAndHeldButtons
	LDA DoCheckButtonSequences
	BEQ :+
	JSR CheckSpeedButtonSequence
	JSR CheckSoundButtonSequence
:
	RTS
.endproc

.proc UpdatePressedAndHeldButtons
	seta16
	LDA Player1HeldButtons
	EOR #$FFFF
	AND Player1Input
	STA Player1PressedButtons
	LDA Player1Input
	STA Player1HeldButtons

	LDA Player2HeldButtons
	EOR #$FFFF
	AND Player2Input
	STA Player2PressedButtons
	LDA Player2Input
	STA Player2HeldButtons
	seta8
	RTS
.endproc

.proc SanitizePlayerDpads
.a8
.i8
	LDX #0
:
	LDA Player1Input+1, X
	AND #$F
	TAY
	LDA Player1Input+1, X
	AND #$F0
	ORA DpadNoUDLRTable, Y
	STA Player1Input+1, X
	INX
	INX
	CPX #8
	BNE :-
	RTS
.endproc

.proc CheckSpeedButtonSequence
.a8
.i8
	LDA SpeedButtonSeqIndex
	ASL
	TAY
	seta16
	LDA SpeedButtonSequenceTable, Y
	CMP Player1HeldButtons
	seta8
	BNE @mismatch
	INC SpeedButtonSeqIndex
	LDA SpeedButtonSeqIndex
	CMP #9
	BNE @done
	STZ SpeedButtonSeqIndex
	LDA CurClockSpeed
	DEC
	AND #3
	STA CurClockSpeed
	JSR WriteICD2CTL
	LDA #SfxA::ROCKET_LAUNCHER_14
	STA SFXANum
	LDA #0
	STA SFXAttrs
	STZ Player1Input+1
@done:
	RTS

@mismatch:
	INC SpeedButtonSeqIndex
	LDA SpeedButtonSeqIndex
	CMP #9
	BNE @fail
	seta16
	LDA Player1HeldButtons
	seta8
	BNE @fail
	STZ Player1Input+1
	LDA CurClockSpeed
	DEC
	AND #3
	BNE :+
	LDA #3
:
	STA CurClockSpeed
	JSR WriteICD2CTL
	LDA #SfxA::ROCKET_LAUNCHER_14
	STA SFXANum
	LDA #0
	STA SFXAttrs
@fail:
	STZ SpeedButtonSeqIndex
	RTS
.endproc

.proc CheckSoundButtonSequence
.a8
.i8
	LDA SoundButtonSeqIndex
	ASL
	TAY
	seta16
	LDA SoundButtonSequenceTable, Y
	CMP Player1HeldButtons
	seta8
	BNE @fail
	INC SoundButtonSeqIndex
	LDA SoundButtonSeqIndex
	CMP #8
	BNE @done
	STZ SoundButtonSeqIndex
	LDA ButtonSequenceSoundToggle
	INC
	AND #1
	STA ButtonSequenceSoundToggle
	BNE :+
	LDA #SfxB::SFXB_82
	STA SFXBNum
@done:
	RTS

@fail:
	STZ SoundButtonSeqIndex
	RTS

:
	LDA #SfxB::SFXB_81
	STA SFXBNum
	RTS
.endproc


.proc EmptyFunc00881F
	RTS
.endproc


	baseinc $008820, $00A781


.proc ApplyControllerMovement
.a8
	LDA WhichActiveController
	BEQ @p1
	CMP #1
	BNE @p2
	LDA IsMouseConnected+1
	LSR
	BCC @noController
	JSR ApplyHorizontalMouseMovement
	JSR ApplyVerticalMouseMovement
@noController:
	RTS

@p2:
	LDA Player2HeldButtons+1
@pad:
	JSR ApplyPadMovement
	RTS

@p1:
	LDA Player1HeldButtons+1
	BRA @pad
.endproc

.proc ApplyHorizontalMouseMovement
.a8
	LDA HorizontalMouseMovement+1
	BMI @moveUp
	LDA MenuSprites + Sprite::xPos, X
	CLC
	ADC HorizontalMouseMovement+1
	BCS :+
	CMP #$FD
	BCC :++
:
	LDA #$FD
:
	STA MenuSprites + Sprite::xPos, X
	RTS

@moveUp:
	AND #$7F
	STA MouseMotionRadius
	LDA MenuSprites + Sprite::xPos, X
	SEC
	SBC MouseMotionRadius
	BCC :+
	CMP #0
	BCS :++
:
	LDA #0
:
	STA MenuSprites + Sprite::xPos, X
	RTS
.endproc

.proc ApplyVerticalMouseMovement
.a8
	LDA VerticalMouseMovement+1
	BMI @moveUp
	LDA MenuSprites + Sprite::yPos, X
	CLC
	ADC VerticalMouseMovement+1
	BCS :+
	CMP #$D2
	BCC :++
:
	LDA #$D2
:
	STA MenuSprites + Sprite::yPos, X
	RTS

@moveUp:
	AND #$7F
	STA MouseMotionRadius
	LDA MenuSprites + Sprite::yPos, X
	SEC
	SBC MouseMotionRadius
	BCC :+
	CMP #2
	BCS :++
:
	LDA #2
:
	STA MenuSprites + Sprite::yPos, X
	RTS
.endproc

	baseinc $00A7FF, $00A873

.proc IsAHeld
.a8
	LDA WhichActiveController
	BEQ @p1
	CMP #1
	BNE @p2
	LDA Player2Input
	AND #$F
	BEQ @done
	LDA CurrentMouseButtons+1
	AND #1 ; Left button
@done:
	RTS

@p1:
	LDA Player1HeldButtons
	AND #$80 ; A
	BNE @done
	LDA MapSNES_BToGB_A
	BEQ @done
	LDA Player1HeldButtons+1
	AND #$80 ; B
	RTS

@p2:
	LDA Player2Input
	AND #$F
	BNE @nope
	LDA Player2HeldButtons
	AND #$80 ; A
	BNE @done
	LDA MapSNES_BToGB_A
	BEQ @done
	LDA Player2HeldButtons+1
	AND #$80 ; B
	RTS
@nope:
	LDA #0
	RTS
.endproc

	baseinc $00A8B7, $0A90F

.proc ApplyPadMovement
	seta16
	AND #$F
	ASL
	ASL
	TAY
	LDA CursorMovementVectors + CoordPair::xCoord, Y
	BMI @moveUp
	CLC
	ADC MenuSprites + Sprite::xPos, X
	CMP #$FD
	BCC @storeXPos
	LDA #$FD
@storeXPos:
	STA MenuSprites + Sprite::xPos, X

	LDA CursorMovementVectors + CoordPair::yCoord, Y
	CLC
	ADC MenuSprites + Sprite::yPos, X
	CMP #$D2
	BCS @hitBottom
	CMP #2
	BCS @storeYPos
	LDA #2
@storeYPos:
	STA MenuSprites + Sprite::yPos, X
	seta8
	RTS

.a16
@moveUp:
	CLC
	ADC MenuSprites + Sprite::xPos, X
	CMP #$FD
	BCC @storeXPos
	LDA #0
	BRA @storeXPos

@hitBottom:
	LDA #$D2
	BRA @storeYPos
.endproc


	baseinc $00A958, $00AC43


.proc UploadDefaultAPUProgram
.a8
	LDA #<DefaultAPUProgram
	STA FramebufferFarPtr
	LDA #>DefaultAPUProgram
	STA FramebufferFarPtr+1
	LDA #^DefaultAPUProgram
	STA FramebufferFarPtr+2
.endproc

.proc UploadAPUProgram
.a8
	JSR GetAPUBlockHeader
	JSR InitAPUUpload

@loop:
	JSR SendAPUProgramBlock
	JSR GetAPUBlockHeader
	seta16
	LDA APUTransferRemainingBytes
	seta8
	BEQ @done
	JSR APUTransferWaitAck
	BRA @loop

@done:
	JSR APUTransferWaitLastACK
	RTS
.endproc

.proc GetAPUBlockHeader
.a8
	LDA [FramebufferFarPtr]
	STA APUTransferRemainingBytes
	JSR IncFarPtr
	LDA [FramebufferFarPtr]
	STA APUTransferRemainingBytes+1
	JSR IncFarPtr
	LDA [FramebufferFarPtr]
	STA APUTransferDest
	JSR IncFarPtr
	LDA [FramebufferFarPtr]
	STA APUTransferDest+1
	JSR IncFarPtr
	RTS
.endproc

.proc IncFarPtr
.a8
	INC FramebufferFarPtr
	BNE @done
	INC FramebufferFarPtr+1
	BNE @done
	LDA #$80
	STA FramebufferFarPtr+1
	INC FramebufferFarPtr+2
@done:
	RTS
.endproc

.proc InitAPUUpload
.a8
	LDA APU0
	CMP #$AA
	BNE InitAPUUpload
	LDA APU1
	CMP #$BB
	BNE InitAPUUpload

	LDA APUTransferDest
	STA APU2
	LDA APUTransferDest+1
	STA APU3
	LDA #1
	STA APU1
	LDA #$CC
	STA APU0

@waitAPUReady:
	LDA APU0
	CMP #$CC
	BNE @waitAPUReady
	RTS
.endproc

.proc SendAPUProgramBlock
.a8
	setxy16
	LDY APUTransferRemainingBytes
	STZ APUTransferIndex

@sendByte:
	LDA [FramebufferFarPtr]
	STA APU1
	LDA APUTransferIndex
	STA APU0
	INC FramebufferFarPtr
	BNE :+
	INC FramebufferFarPtr+1
	BNE :+
	LDA #$80
	STA FramebufferFarPtr+1
	INC FramebufferFarPtr+2
:

	LDA APU0
	CMP APUTransferIndex
	BNE :-
	INC APUTransferIndex
	DEY
	BNE @sendByte
	setxy8
	RTS
.endproc

.proc APUTransferWaitAck
.a8
	LDA #2
	STA APU1
	LDA APUTransferDest
	STA APU2
	LDA APUTransferDest+1
	STA APU3
	INC APUTransferIndex
	BNE :+
	INC APUTransferIndex
:

	LDA APUTransferIndex
	STA APU0
:
	LDA APU0
	CMP APUTransferIndex
	BNE :-
	RTS
.endproc

.proc APUTransferWaitLastACK
.a8
	LDA #0
	STA APU1
	LDA APUTransferDest
	STA APU2
	LDA APUTransferDest+1
	STA APU3
	INC APUTransferIndex
	BNE :+
	INC APUTransferIndex
:

	LDA APUTransferIndex
	STA APU0
:
	LDA APU0
	CMP APUTransferIndex
	BNE :-
	RTS
.endproc


	baseinc $00AD33, $00B50A


.proc Native_mode_IRQ
.a8
	PHA
	PHX
	PHY
	PHB
	PHP
	setaxy8
	LDA #1
	PHA
	PLB
	LDA #INC_DATAHI
	STA PPUCTRL
	seta16
	LDA #$7000
	STA PPUADDR

	; TODO
.endproc


	baseinc $00B522, $00B9BE


.proc ReadCHRRows
.a8
	LDA f:ICD2CURROW
	STA CurLYAndBufNum
	LDA f:ICD2CURROW
	CMP CurLYAndBufNum
	BNE ReadCHRRows
	; Check if this "row" was VBlank
	CMP #$12 << 3
	BCS @done
	; Divide by 8
	LSR
	LSR
	LSR
	STA CurLCDCHRRow
	LDA CurLCDCHRRow
	SEC
	SBC CurCHRRow
	BEQ @done
	BPL @noWrap
	LDA #$12
	SEC
	SBC CurCHRRow
	CLC
	ADC CurLCDCHRRow
@noWrap:
	STA RemainingCHRRows
	CMP #4
	BCS @giveUp

@readRow:
	JSR ReadCHRRow
	INC CurCHRRow
	LDA CurCHRRow
	CMP #$12
	BCC @sameBuffer
	STZ CurCHRRow
	JSR ExchangeFramebufferPtrs
@sameBuffer:
	DEC RemainingCHRRows
	BNE @readRow

@done:
	RTS

@giveUp:
	LDA CurLCDCHRRow
	STA CurCHRRow
	RTS
.endproc

.proc ReadCHRRow
.a8
.i8
	LDA CurLYAndBufNum
	SEC
	SBC RemainingCHRRows
	AND #%11
	STA f:ICD2ROWSEL
	STZ WMADDH
	seta16
	LDA CurCHRRow
	ASL
	TAX
	LDA MultBy0x140Table,X
	CLC
	ADC PtrToOtherFramebuffer
	STA WMADDL ; And WMADDM
	LDA #<WMDATA << 8 | DMA_CONST
	STA DMAMODE + $40 ; Also DMAPPUREG
	LDA #ICD2CHR
	STA DMAADDR + $40 ; Also DMAADDRHI
	LDA #<$140 << 8 | ^ICD2CHR
	STA DMAADDRBANK + $40 ; Also DMALEN
	LDA #>$140
	STA DMALENHI + $40 ; Also a dummy write after
	seta8

	LDA SomeMutex
	BNE :+++++    ; -+
	LDY #1         ; |
	LDA PPUSTATUS2 ; |
	LDA GETXY   ;    |
	LDA YCOORD  ;    |
	CMP #$DF    ;    |
	BCS :++   ;   -+ |
	CMP #$DC  ;    | |
	BCC :++++ ; -+ | |
	STY RunGDMA4;| | |
	           ; | | |
:	           ; | | |
	LDA IRQAck ; | | |
	BEQ :-     ; | | |
	STZ RunGDMA4;| | |
	RTS    ;     | | |
	       ;     | | |
:	       ;   <-|-+ |
	BNE :++ ; -+ |   |
:	        ;  | |   |
	LDA IRQAck;| |   |
	BEQ :- ;   | |   |
:	       ; <-+-+   |
	LDA #1 << 4   ;  |
	STA COPYSTART ;  |
	RTS           ;  |
	             ;   |
:	             ; <-+
	LDA #1 << 4
	STA COPYSTART
	RTS
.endproc

.proc ExchangeFramebufferPtrs
	LDA WhichFramebuffer
	EOR #1
	STA WhichFramebuffer
	BNE :+

	LDA #>Framebuffer_7E5000
	STA PtrToOtherFramebuffer+1
	LDA #>Framebuffer_7E6800
	STA PtrToFramebuffer+1
	RTS

:
	LDA #>Framebuffer_7E6800
	STA PtrToOtherFramebuffer+1
	LDA #>Framebuffer_7E5000
	STA PtrToFramebuffer+1
	RTS
.endproc


	baseinc $00BAA4, $00BB7B


.proc WriteICD2CTL
.a8
	LDA CurClockSpeed
	AND #3
	STA ICD2CTLTemp
	LDA CurNbControllers
	AND #$30
	ORA ICD2CTLTemp
	ORA #$80
	STA f:ICD2CTL
	RTS
.endproc


	baseinc $00BB90, $00BC7F


.proc SendInputsToGB
.a8
.i8
	LDA MultiplayerControl
	BEQ :+
	LDX #1
	JSR SendPlayerInputToGB
	LDA MultiplayerControl
	CMP #1
	BEQ :+
	LDX #2
	JSR SendPlayerInputToGB
	LDX #3
	JSR SendPlayerInputToGB
:
	LDX #0
	JSR SendPlayerInputToGB
	RTS
.endproc

.proc SendPlayerInputToGB
.a8
.i8
	LDA TransmitOnlyStartSelect
	BNE @onlyStartSelect
	TXA
	ASL
	TAY
	LDA Player1Input, Y
	AND #$F
	BNE @disconnected
	LDA Player1Input  , Y
	STA PlayerInput
	LDA Player1Input+1, Y
	STA PlayerInput+1
	JSR ConvertSNESInputToGB
	RTS

@disconnected:
	LDA #$FF
	STA P1GBInput
	STA f:ICD2P1, X
	RTS

@onlyStartSelect:
	TXA
	ASL
	TAY
	LDA Player1Input+1, Y ; Possible mistake?
	AND #$F
	BNE @disconnected
	STZ PlayerInput
	LDA Player1Input+1, Y
	AND #$30
	STA PlayerInput+1
	JSR ConvertSNESInputToGB
	RTS
.endproc

.proc ConvertSNESInputToGB
.a8
	STZ GBInput
	LDA PlayerInput
	AND #$80 ; A
	LSR
	LSR
	LSR
	TSB GBInput
	LDA PlayerInput+1
	AND #$80 ; B
	LSR
	LSR
	LDY MapSNES_BToGB_A
	BEQ :+
	LSR
:
	TSB GBInput
	LDA PlayerInput+1
	AND #$10 ; Start
	ASL
	ASL
	ASL
	TSB GBInput
	LDA PlayerInput+1
	AND #$20 ; Select
	ASL
	TSB GBInput
	LDA PlayerInput+1
	AND #8 ; Up
	LSR
	TSB GBInput
	LDA PlayerInput+1
	AND #4 ; Down
	ASL
	TSB GBInput
	LDA PlayerInput+1
	AND #$40 ; Y
	LSR
	TSB GBInput
	LDA PlayerInput+1
	AND #3 ; Left and Right
	ORA GBInput
	EOR #$FF
	STA P1GBInput
	STA f:ICD2P1, X
	RTS
.endproc


	baseinc $00BD2C, $00C573


.proc ProcessSOU_TRN
.a8
	LDA #$FF
	STA APU0
	JSR WaitFramebufferFilled
	LDA PtrToFramebuffer
	STA FramebufferFarPtr
	LDA PtrToFramebuffer+1
	STA FramebufferFarPtr+1
	LDA #$7E
	STA FramebufferFarPtr+2
	JSR UploadAPUProgram
	RTS
.endproc

.proc WaitFramebufferFilled
.a8
	SEI
	LDA #1
	STA SomeMutex
	LDA PtrToFramebuffer+1
	STA TmpFramebufPtrHigh

:
	JSR ReadCHRRows
	LDA PtrToFramebuffer+1
	CMP TmpFramebufPtrHigh
	BEQ :-

:
	JSR ReadCHRRows
	LDA PtrToFramebuffer+1
	CMP TmpFramebufPtrHigh
	BNE :-

	STZ SomeMutex
	LDA DoCheckButtonSequences
	BEQ :+
	LDA TIMEUP ; $4211
	CLI
:
	RTS
.endproc


	baseinc $00C5BC, $00C9F0


	.byte "START OF MULTI5 BIOS"
.proc PollMulti5
	PHP
	setaxy8
	STZ Multi5Present
:	; Wait for auto-poll to end
	LDA VBLSTATUS
	AND #1
	BNE :-
	LDA JOY1CUR+1
	STA Player1Input+1
	LDA JOY1CUR
	STA Player1Input
	AND #$F
	STA IgnorePlayer1Input
	LDA f:JOY0
	LSR
	ROL IgnorePlayer1Input

	LDA JOY2CUR+1
	STA Player2Input+1
	LDA JOY2CUR
	STA Player2Input
	AND #$F
	STA IgnorePlayer2Input

	LDA JOY2B1CUR+1
	STA Player3Input+1
	LDA JOY2B1CUR
	STA Player3Input
	AND #$F
	STA IgnorePlayer3Input
	LDA f:JOY1
	LSR
	ROL IgnorePlayer2Input
	LSR
	ROL IgnorePlayer3Input

	LDA #$7F
	STA WRIO
	LDY #$10
:
	LDA f:JOY1
	seta16
	LSR
	ROL Player4Input
	LSR
	ROL Player5Input
	seta8
	DEY
	BNE :-
	LDA Player4Input
	AND #$F
	STA IgnorePlayer4Input
	LDA Player5Input
	AND #$F
	STA IgnorePlayer5Input
	LDA f:JOY1
	LSR
	ROL z:$001E ; `IgnorePlayer4Input` is at $0F1E, this looks like a typo
	LSR
	ROL IgnorePlayer5Input

	LDA #$FF
	STA WRIO
	PLP
	RTS
.endproc
	.byte "NINTENDO SHVC MULTI5 BIOS Ver2.10"
	.byte "END OF MULTI5 BIOS"

	.byte "START OF MULTI5 CONNECT CHECK"
.proc Multi5ConnectCheck
	PHP
	setaxy8
	STZ Multi5Present
:	; Wait for auto-poll to end
	LDA VBLSTATUS
	AND #1
	BNE :-

	; Enable strobe
	STZ JOY0
	LDA #1
	STA f:JOY0
	LDX #8
:
	LDA f:JOY0
	LSR
	LSR
	ROL Multi5LeftPortStrobed
	LDA f:JOY1
	LSR
	LSR
	ROL Multi5RightPortStrobed
	DEX
	BNE :-

	; Disable strobe and repoll
	STZ JOY0
	LDX #8
:
	LDA f:JOY0
	LSR
	LSR
	ROL Multi5LeftPortStrobeless
	LDA f:JOY1
	LSR
	LSR
	ROL Multi5RightPortStrobeless
	DEX
	BNE :-

	LDA Multi5LeftPortStrobed
	CMP #$FF
	BNE :+
	LDA Multi5LeftPortStrobeless
	CMP #$FF
	BEQ :+
	LDA #$80
	STA Multi5Present
:

	LDA Multi5RightPortStrobed
	CMP #$FF
	BNE :+
	LDA Multi5RightPortStrobeless
	CMP #$FF
	BEQ :+
	LDA #$40
	ORA Multi5Present
	STA Multi5Present
:

	PLP
	RTS
.endproc
	.byte "NINTENDO SHVC MULTI5 CONNECT CHECK Ver1.00"
	.byte "END OF MULTI5 CONNECT CHECK"

	.byte "START OF MOUSE BIOS"
	; TODO


	baseinc $00CBAE, $00D73B


.proc CheckLAndRPressed
.a8
	LDA Player1Input+1
	BNE @p1NotJustLR
	LDA Player1Input
	AND #$FF
	CMP #$30 ; L and R
	BNE @p1NotJustLR
	LDA #$FF
	STA PlayerRequestedClosing

@p1NotJustLR:
	LDA CurrentMouseButtons+1
	AND #3
	CMP #3
	BNE @mouseNotLR
	LDA #$FF
	STA PlayerRequestedClosing

@mouseNotLR:
	LDA Player2Input+1
	BNE @p2NotJustLR
	LDA Player2Input
	AND #$FF
	CMP #$30 ; L and R
	BNE @p2NotJustLR
	LDA #$FF
	STA PlayerRequestedClosing

@p2NotJustLR:
	RTS
.endproc


.proc UpdateHeldButtons
	STZ AHeld
	STZ BHeld
	LDA MenuController
	ASL
	TAX
	LDA MapSNES_BToGB_A
	BEQ :+
	JSR (UpdateHeldButtonsAB_YTable, X)
	RTS

:
	JSR (UpdateHeldButtonsA_BYTable, X)
	RTS
.endproc

UpdateHeldButtonsAB_YTable:
	.word CheckP1AB_Y
	.word CheckMouseAB
	.word CheckP2AB_Y

.proc CheckP1AB_Y
.a8
	LDA Player1Input
	AND #$F
	BEQ @connected
	RTS

@connected:
	seta16
	LDA Player1Input
	BIT #$8080 ; A or B
	BEQ @neitherANorB
	seta8
	LDA #1
	STA AHeld
	RTS

@neitherANorB:
	seta8
	seta16
	LDA Player1Input
	BIT #$4000 ; Y
	BEQ @noButton
	seta8
	LDA #1
	STA BHeld
	RTS

@noButton:
	seta8
	RTS
.endproc

.proc CheckP2AB_Y
.a8
	LDA Player2Input
	AND #$F
	BEQ @connected
	RTS

@connected:
	seta16
	LDA Player2Input
	BIT #$8080 ; A or B
	BEQ @neitherANorB
	seta8
	LDA #1
	STA AHeld
	RTS

@neitherANorB:
	seta8
	seta16
	LDA Player2Input
	BIT #$4000 ; Y
	BEQ @noButton
	seta8
	LDA #1
	STA BHeld
	RTS

@noButton:
	seta8
	RTS
.endproc

.proc CheckMouseAB
.a8
	LDA Player2Input
	AND #$F
	CMP #1
	BEQ @connected
	RTS

@connected:
	LDA CurrentMouseButtons+1
	BIT #1
	BEQ @rightNotHeld
	LDA MouseRightHoldCounter
	INC
	CMP #3
	BEQ @heldRightLongEnough
	STA MouseRightHoldCounter
	BRA @rightNotHeld
@heldRightLongEnough:
	LDA #1
	STA AHeld

@rightNotHeld:
	LDA CurrentMouseButtons+1
	BIT #2
	BEQ @leftNotHeld
	LDA MouseLeftHoldCounter
	INC
	CMP #3
	BEQ @heldLeftLongEnough
	STA MouseLeftHoldCounter
	BRA @leftNotHeld
@heldLeftLongEnough:
	LDA #1
	STA BHeld
@leftNotHeld:

	; Reset hold counters if buttons were released
	LDA CurrentMouseButtons+1
	BIT #1
	BNE @notHoldingRight
	STZ MouseRightHoldCounter
@notHoldingRight:
	LDA CurrentMouseButtons+1
	BIT #2
	BNE @notHoldingLeft
	STZ MouseLeftHoldCounter
@notHoldingLeft:
	RTS
.endproc


UpdateHeldButtonsA_BYTable:
	.word CheckP1A_BY
	.word CheckMouseAB
	.word CheckP2A_BY

.proc CheckP1A_BY
.a8
	LDA Player1Input
	AND #$F
	BEQ @connected
	RTS

@connected:
	seta16
	LDA Player1Input
	BIT #$0080 ; A
	BEQ @notA
	seta8
	LDA #1
	STA AHeld
	RTS

@notA:
	seta8
	seta16
	LDA Player1Input
	BIT #$C000 ; B or Y
	BEQ @noButton
	seta8
	LDA #1
	STA BHeld
	RTS

@noButton:
	seta8
	RTS
.endproc

.proc CheckP2A_BY
.a8
	LDA Player2Input
	AND #$F
	BEQ @connected
	RTS

@connected:
	seta16
	LDA Player2Input
	BIT #$0080 ; A
	BEQ @notA
	seta8
	LDA #1
	STA AHeld
	RTS

@notA:
	seta8
	seta16
	LDA Player2Input
	BIT #$C000 ; Y
	BEQ @noButton
	seta8
	LDA #1
	STA BHeld
	RTS

@noButton:
	seta8
	RTS
.endproc


	baseinc $00D8A9, $00FFC0


.segment "HEADER"
	; No extended header here, instead are some jumps
.org $00FFC0

snes_header:
	.byte "Super GAMEBOY        "
	.byte $20   ; LoROM mapping, 200ns access time
	.byte $E3   ; Extra hardware
	.byte 8	 ; ROM size
	.byte 0	 ; RAM size
	.byte 0	 ; Destination code (Japan)
	.byte 1	 ; Publisher
	.byte rom_version
	.res 2	  ; Checksum complement
	.res 2	  ; Checksum

	.word $F4F4
	.word $F4F4
	.word $F4F4 ; Native mode COP
	.word $F4F4 ; Native mode BRK
	.addr Native_mode_ABORT
	.addr Native_mode_NMI
	.addr EntryPoint ; Native mode RESET
	.addr Native_mode_IRQ

	.word $F4F4
	.word $F4F4
	.word $F4F4 ; Emulation mode COP
	.word $F4F4
	.addr Native_mode_ABORT
	.addr Native_mode_NMI
	.addr EntryPoint ; Emulation mode RESET
	.addr Native_mode_IRQ

