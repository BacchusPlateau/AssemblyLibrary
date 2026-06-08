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

        jsr openGR8

        jsr clearScreen

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


halt:
        jsr fightAttract
        jmp halt


        .endp

;===================================================================
; Data section
;===================================================================
        ;.local string1
        ;.byte 'HELLO FROM STRING ONE!',0
        ;.endl


        run main