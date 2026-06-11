; printing variables and constants
putchar_ptr = $346                      ; CONSTANT: putchar_ptr = $346 (OS character output vector address)
csrhinh     = $2F0                      ; CONSTANT: csrhinh = $2F0 (OS cursor visible/hidden control address)        
rowcrs      = $54                       ; CONSTANT: rowcrs = $54 (OS zero page address that controls cursor row)
colcrs      = $55                       ; CONSTANT: colcrs = $55 (OS zero page address that controls cursor column)
offset_to_char = $30                    ; Offset from integer literal to ATASCII character equivalent of the number

strptr_lo   = $8B                       ; low byte of string address
strptr_hi   = $8C                       ; high byte of string address

; graphics variables and constants
plotX_lo    = $80       ; low byte of X coordinate (0-319 needs 2 bytes!)
plotX_hi    = $81       ; high byte of X coordinate
plotY       = $82       ; Y coordinate (0-191, fits in one byte)
temp_lo     = $83       ; temporary storage low byte
temp_hi     = $84       ; temporary storage high byte
scrptr_lo   = $85       ; calculated screen address low byte
scrptr_hi   = $86       ; calculated screen address high byte
save_lo     = $87       ; saved plotY × 8 low byte
save_hi     = $88       ; saved plotY × 8 high byte
bitpos      = $89       ; bit position within byte (plotX mod 8) that our pixel lives in
bitmask     = $8A       ; save our mask that we will use to turn ONLY our pixel on

; drawLine variables
x1      = $8D       ; start X low byte
x1_hi   = $8E       ; start X high byte
y1      = $8F       ; start Y
x2      = $90       ; end X low byte
x2_hi   = $91       ; end X high byte
y2      = $92       ; end Y
dx_lo   = $93       ; delta X low byte
dx_hi   = $94       ; delta X high byte
dy      = $95       ; delta Y
err_lo  = $96       ; error accumulator low byte
err_hi  = $97       ; error accumulator high byte


; GR.8 color registers
COLPF1  = $02C5     ; foreground pixel color shadow
COLPF2  = $02C6     ; background color shadow
COLBK   = $02C8     ; border color shadow

; =====================================================================
; CIO (Central I/O) constants
; CIO is the Atari OS I/O system. We use it to open graphics mode.
; Each I/O channel uses an IOCB (I/O Control Block) — a fixed block
; of memory containing command, device, buffer address, and aux bytes.
; We use IOCB6 (base address $0360) for graphics.
; X register = $60 tells CIOV which IOCB to use (IOCB6).
; =====================================================================
CIOV    = $E456     ; OS CIO entry point — call jsr CIOV to execute
ICCOM   = $0342     ; IOCB6 command register
                    ;   $03 = OPEN   (open a device)
                    ;   $0C = CLOSE  (close a device)
ICBAL   = $0344     ; IOCB6 buffer address low byte
                    ;   for OPEN: points to device name string "S:"
ICBAH   = $0345     ; IOCB6 buffer address high byte
                    ;   together with ICBAL forms 16-bit pointer to "S:"
ICAX1   = $034A     ; IOCB6 auxiliary byte 1
                    ;   for OPEN: $0C = read/write access mode
ICAX2   = $034B     ; IOCB6 auxiliary byte 2
                    ;   for OPEN: graphics mode number (8 = GR.8)

; =====================================================================
; Screen RAM pointer
; After CIO opens GR.8, the OS stores the address of screen RAM
; in SAVMSC (two bytes). $58 = low byte, $59 = high byte.
; On our 800XL PAL system screen RAM ends up at $B060.
; =====================================================================
SAVMSC  = $58       ; zero page address — low byte of screen RAM address
                    ; $59 automatically contains the high byte

; =====================================================================
; Attract mode constants
; The Atari OS has an attract mode that kicks in after inactivity
; to prevent screen burn-in. It does this by desaturating all colors
; making everything appear as shades of grey/blue.
; We must continuously reset these in our main loop to keep colors!
; =====================================================================
ATRACT  = $4D       ; attract mode counter — OS increments this each frame
                    ; when it reaches a threshold attract mode activates
                    ; we keep writing 0 to prevent it from activating
ATRMSK  = $4E       ; attract mode color mask
                    ; OS ANDs all colors with this value
                    ; $FE strips hue leaving only luminance (grey/blue)
                    ; $FF = full color (no masking) — what we want