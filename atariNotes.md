# Atari 800XL 6502 Assembly Project — Working Notes

## Hardware / Environment
- Target: Atari 800XL (128K), PAL, AltirraOS 3.34 for XL/XE/XEGS
- Emulator: Altirra (Altirra/x64 4.10), profile "XL/XE Computer"
- Assembler: MADS, via VSCode build task → produces .xex for Altirra
- Project repo: AssemblyLibrary on GitHub — `equates.asm` + `routines.asm`
  are the reusable library; each new effort clones these into a fresh
  main .asm file (e.g. `pmg.asm`, `lines.asm`, `keyboard.asm`)

## Core gotchas (hard-won, easy to forget)
- dex/dey/inx/iny set the zero flag automatically
No need for a separate cpx #0 after dex — the decrement itself sets the zero flag if the result is zero. So dex / bne loop is the idiomatic pattern: "decrement and keep looping if not zero yet." Same applies to dey, inx, iny, inc, dec, and most arithmetic/logic instructions. The exceptions are store instructions (sta, stx, sty) and branch instructions — those don't touch flags.
- MADS .len operator
.len numbers evaluates to the byte count of a data table at assembly time. Use it in cpx #.len numbers as your loop termination condition so you never have to hardcode or manually count array lengths. If you add or remove values from the table later, the loop automatically adjusts.
- sta supports indexed addressing just like lda
sta numbers,x writes A into memory at numbers + X — same addressing mode you already use for reads. The mva macro can't do this; you need the explicit lda / sta pair when the destination is an indexed address.
- Dual-index loop pattern (e.g. reverse-copy)
When you need one index counting up and another counting down simultaneously, use X for one and Y for the other. Initialize Y to #.len array - 1 (use dey after lda #.len array / tay), then inx / dey each pass.


### Every .proc needs an explicit `rts`
Without it, execution falls through into whatever code follows in
memory — no error, no crash, just silent corruption of whatever that
next code happens to touch. (Real bug: missing `rts` in `printDecimal`
let it fall into `plotPoint`, which clobbered `temp_lo` via `plotY`.)

### MADS labels are case-insensitive
`countDown` (a loop label) and `countdown` (a data label) collide
silently — whichever is defined first wins, no error reported. Use
visually distinct naming (e.g. suffix data labels `_str`, or just
avoid near-homonyms) rather than relying on case to disambiguate.

### GTIA color/position registers are WRITE-ONLY
`$D016`-`$D01A` (COLPF0-3, COLBK) and `$D000`-`$D003`/`$D012`-`$D015`
(HPOSPx, COLPMx) cannot be read back meaningfully with `lda`/`db` —
you'll get garbage unrelated to what you wrote. To inspect live PMG
state, use Altirra debugger's `.gtia` command instead, which reports
GTIA's actual interpreted state, not a raw memory peek.

### SAVMSC must be read at runtime, never hardcoded
Screen RAM's actual address (stored at zero page `$58`/`$59` by the OS
after CIO opens a graphics mode) varies by session/config — we saw
both `$B060` and `$A150` on the *same* hardware depending on context.
Always `lda SAVMSC` / `lda SAVMSC+1` fresh; never assume a fixed value.

### Attract mode fights you continuously, not just once
The OS increments a counter at `$4D` (~every 4 sec) and once it hits
threshold, desaturates colors via a mask at `$4E`. Fix: continuously
re-write `$4D=0` and `$4E=$FF` every frame in any long-running loop
(`fightAttract` proc does this) — a one-time reset doesn't stick.

### PMG hardware registers (HPOSPx, COLPMx) ALSO need continuous refresh
Confirmed empirically (not yet root-caused against the Hardware
Reference Manual): any loop that runs for more than a brief moment —
busy-loop OR frame-synced wait — will cause the Player sprite to
visually drop out unless HPOSP0/COLPM0 are re-written every pass
through that loop. `.gtia` shows the register *does* hold its written
value indefinitely once execution reaches a refreshing loop (like
`stop`) — so the dropout seems tied to extended unrefreshed loops
specifically, not register volatility in general. `waitFrames` now
re-asserts these every frame internally as the working fix.

### plotPoint and drawSprite/drawLine DESTROY their X-coordinate inputs
`plotPoint` divides `plotX_lo`/`plotX_hi` by 8 internally (via
`lsr`/`ror`) and never restores them. Any loop that needs the same
plotX value across multiple `jsr plotPoint` calls (drawLine, drawCircle,
drawSprite) must save/restore plotX_lo/plotX_hi around each call via
the stack (`pha`/`pla` pair), or the second call onward will be wrong.

### drawSprite / eraseSprite must save/restore spritePtr_lo/hi
Both procs advance the sprite data pointer by walking the full byte
table. Without push/pull around the body, a second call to either proc
starts reading from wherever the *first* call left the pointer, not
from byte 0 again.

## PMG (Player-Missile Graphics) memory map — two-line resolution
- `PMBASE` must be 1K-aligned (not just page-aligned) — low byte $00
  AND address divisible by 1024. ($5000 happens to satisfy both.)
- ANTIC's PM base pointer register is `$D407` — write the HIGH byte
  of PMBASE only (PMBASE ÷ 256). No shadow register exists for this;
  write hardware directly.
- Within the PM block, in TWO-LINE resolution (128 bytes/player):
  - Offset `$0000`-`$017F`: unused (first 3 of 8 sections)
  - Offset `$0180`: missile data (all 4 missiles share this section)
  - Offset `$0200`: Player 0 data starts HERE — NOT `$0080`!
  - Offset `$0280`: Player 1
  - Offset `$0300`: Player 2
  - Offset `$0380`: Player 3
- Within a Player's 128-byte section, offset 16 aligns with the visible
  top of the playfield (empirically confirmed, matches bumbershootsoft
  reference for half-speed/two-line DMA mode).
- `DMACTL` ($022F shadow / $D400 hardware) full known-working value:
  `$2E` = playfield width (bits 0-1=2) + missile DMA (bit 2) +
  player DMA (bit 3) + display list DMA (bit 5). Don't just OR in one
  bit on top of CIO's value — CIO's GR.8 setup may not configure bits
  PMG specifically needs.
- `GRACTL` ($D01D) = `%00000011` enables both player and missile DMA
  on the GTIA side — must be set in ADDITION to DMACTL's bits, not
  instead of them. Missing either side causes "odd effects" per the
  Hardware Reference Manual.
- `HPOSP0` ($D000) — single byte, horizontal position, larger = more
  right. Low values (~<40ish) clip/split at the screen edge.

## Zero page map (see equates.asm for authoritative/current version)
Used: $80-$B1 roughly, fully allocated across plotPoint, drawLine,
drawCircle, print16bit, sprite (manual bitmap), and PMG (shipX) needs.
**Always check equates.asm before adding a new variable — multiple
collisions have happened already (temp_lo reused fine deliberately;
shipX vs spriteMask was an accidental real bug).**

## Reusable routines currently in routines.asm
putchar, print_string, printDecimal (0-99), printBigDecimal (0-65535),
plotPoint, erasePoint, drawLine (horizontal/vertical/single-octant
diagonal only — not full 8-octant), drawCircle (Bresenham midpoint,
displays as octagon/diamond due to non-square pixel aspect ratio —
unresolved, accepted as-is), drawSprite/eraseSprite (manual 16-wide
bitmap sprite via plotPoint, now with pointer save/restore), openGR8,
clearScreen, fightAttract, waitFrames (PAL ~50Hz frame-synced, now also
refreshes PMG registers internally), initPMG.

## Known unresolved / parked items
- Circle aspect ratio (renders as octagon, not round) — not fixed,
  accepted as a hardware/display characteristic for now.
- drawLine only handles one octant + horizontal/vertical special
  cases — not full 8-direction support (deliberately deferred, YAGNI
  for current game needs).
- PMG register refresh root cause not confirmed against Hardware
  Reference Manual — only the empirical fix (refresh continuously) is
  established, not *why* it's needed.
- Beowulf (the ship) exists as both a 16-wide manual bitmap sprite
  (drawSprite/eraseSprite, GR.8) AND a separate 8-wide PMG shape
  (`beowulfShape` table) — two different representations for two
  different rendering approaches, not interchangeable.


