        icl 'equates.asm'
        icl 'routines.asm'

        org $2000

        .proc main
    
        ;=============================================================
        ; print a string example
        ;
        ;mva #1 csrhinh                  ; hide the cursor
        ;mva #6 rowcrs                   ; set output row
        ;mva #10 colcrs                  ; set output column
        
        ;mva #<string1 strptr_lo         ; low byte of string1 address
        ;mva #>string1 strptr_hi         ; high byte o f string1 address
        ;jsr print_string                ; print the string

        ;jmp stop                        ; stop is inside routines.asm
        ;=============================================================

;======================================================
; draw pixels example
;======================================================

        ; disable BASIC ROM
        sei                 ; disable interrupts during memory switch
        lda $D301           ; read PORTB
        ora #$02            ; set bit 1 = disable BASIC
        sta $D301           ; write back
        cli                 ; re-enable interrupts

; =====================================================================
; STEP 1: Close IOCB6
; Good practice to close before opening — ensures clean state.
; ON ENTRY: X must contain IOCB number × $10 ($60 for IOCB6)
; ON ENTRY: ICCOM must contain the command ($0C = CLOSE)
; ON EXIT:  IOCB6 is closed and ready to be reopened
; =====================================================================
        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$0C                    ; A = $0C        (CLOSE command)
        sta ICCOM,x                 ; ICCOM = $0C    (store command in IOCB6)
        jsr CIOV                    ; CALL CIOV      (execute the close)

; =====================================================================
; STEP 2: Open Graphics Mode 8
; Fills in all IOCB6 fields then calls CIOV to execute the open.
; CIO sets up the display list, allocates screen RAM, configures
; ANTIC — everything needed for graphics mode automatically.
; ON ENTRY: X must contain $60 (IOCB6)
; ON EXIT:  GR.8 screen is active, SAVMSC points to screen RAM
; =====================================================================
        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$03                    ; A = $03        (OPEN command)
        sta ICCOM,x                 ; ICCOM = $03    (store open command)
        lda #<scrname               ; A = low byte of "S:" string address
        sta ICBAL,x                 ; ICBAL = low byte (tell CIO device name location)
        lda #>scrname               ; A = high byte of "S:" string address
        sta ICBAH,x                 ; ICBAH = high byte
        lda #$08                    ; A = $08        (graphics mode 8)
        sta ICAX2,x                 ; ICAX2 = $08    (store graphics mode number)
        lda #$0C                    ; A = $0C        (read/write access)
        sta ICAX1,x                 ; ICAX1 = $0C    (store access mode)
        jsr CIOV                    ; CALL CIOV      (execute open — sets up entire graphics mode!)

; =====================================================================
; STEP 3: Clear Screen RAM to black
; Screen RAM at $B060 may contain garbage from previous programs.
; We fill 256 bytes with $00 (black = all pixels off).
; Note: this only clears the first 256 bytes (one page) of screen RAM.
; Full screen RAM is 3200 bytes — we'd need a 16-bit loop for all of it.
; $00 = %00000000 = all 4 pixels in byte = background color (black)
; =====================================================================

        lda SAVMSC      ; A = memory[$58]  (low byte of screen RAM address from OS)
        sta scrptr_lo   ; store in scrptr_lo ($85)
        lda SAVMSC+1    ; A = memory[$59]  (high byte of screen RAM address from OS)
        sta scrptr_hi   ; store in scrptr_hi ($86)

        ldy #0
clearscreen:
        lda #$00
        sta (scrptr_lo),y   ; write $00 to memory[scrptr + Y]
        iny
        bne clearscreen

        ; defeat attract mode and set colors
        mva #0    ATRACT
        mva #$FF  ATRMSK
        mva #$1E  $02C5     ; COLPF1 = yellow
        mva #$00  $02C6     ; COLPF2 = black
        mva #$00  $02C8     ; COLBK  = black

        ; upper left
        mva #0    plotX_lo
        mva #0    plotX_hi
        mva #0    plotY
        jsr plotPoint

        ; upper right
        mva #$3F  plotX_lo
        mva #$01  plotX_hi
        mva #0    plotY
        jsr plotPoint

        ; lower left
        mva #0    plotX_lo
        mva #0    plotX_hi
        mva #191  plotY
        jsr plotPoint

        ; lower right
        mva #$3F  plotX_lo
        mva #$01  plotX_hi
        mva #191  plotY
        jsr plotPoint

        mva #$1E  $02C8     ; COLBK = bright yellow  (pixels where bit=1)
        mva #$00  $02C6     ; COLPF2 = black         (background where bit=0)

halt:
        mva #0    ATRACT
        mva #$FF  ATRMSK
        mva #$1E  $02C5     ; COLPF1 = bright yellow pixels
        mva #$00  $02C6     ; COLPF2 = black background
        mva #$00  $02C8     ; COLBK  = black border
        jmp halt


        .endp

;===================================================================
; Data section
;===================================================================
        ;.local string1
        ;.byte 'HELLO FROM STRING ONE!',0
        ;.endl


        run main