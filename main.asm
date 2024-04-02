INCLUDE "hardware.inc"


def TILES_PER_FRAME equ 90
def FRAME_TILE_DATA_SIZE equ TILES_PER_FRAME * 16
def FRAME_DATA_SIZE equ FRAME_TILE_DATA_SIZE + 360
def FRAME_PER_BANK equ $4000 / FRAME_DATA_SIZE
def FRAME_DATA_SIZE_PER_BANK equ FRAME_PER_BANK * FRAME_DATA_SIZE
def BIN_FILE_NAME equs "\"fire.bin\"";"\"first_part_big_60t.bin\"";"\"test02_01.bin\""
if def(TARGET_MEGADUCK)
    def BANKS_TO_USE equ 1
else
    def BANKS_TO_USE equ 209
endc

if def(TARGET_MEGADUCK)
    ; Duck Entry point is 0x0000
    SECTION "ROM0Duck", ROM0[$0]
    DuckEntryPoint:
        jp   EntryPoint
endc


SECTION "Header", ROM0[$100]

EntryPoint:
        di ; Disable interrupts. That way we can avoid dealing with them, especially since we didn't talk about them yet :p
        jp Start

REPT $150 - $104
    db 0
ENDR

SECTION "constants", ROM0
kMaxBank:
  DB BANKS_TO_USE

SECTION "Game code", ROM0

Start:
; No boot ROM, so can't assume LCD is turned on at startup
if def(TARGET_MEGADUCK)
    ld a, (LCDCF_ON)
    ldh [rLCDC], a
endc

.waitVBlank
  ldh a, [rLY]
  cp 144 ; Check if the LCD is past VBlank
  jr c, .waitVBlank
  xor a ; ld a, 0 ; We only need to reset a value with bit 7 reset, but 0 does the job
  ldh [rLCDC], a ; We will have to write to LCDC again later, so it's not a bother, really.

  ld a, 1
if (!def(TARGET_MEGADUCK))
  ld [rROMB0], a
endc
  ld [vCurrentBank], a
  ld a, 0
if (!def(TARGET_MEGADUCK))
  ld [rROMB1], a
endc

  ld bc, VidData
  ld hl, _VRAM8000
  ld d, 144
  ld a, STATF_MODE00
  ldh [rSTAT], a
  ld a, IEF_LCDC
  ldh [rIE], a

  ld a, %11100100
  ldh [rBGP], a

  ;; turn the screen back on with background enabled
  ld a, (LCDCF_ON | LCDCF_BG8000 | LCDCF_BGON)
  ldh [rLCDC], a

FirstCopy:
.copySetup

;  ld hl, _VRAM8000
  ldh a, [rLCDC]
  bit LCDCB_BG8000, a
  jr nz, :+
  ld hl, _VRAM8000
  jr :++
: ld hl, _VRAM9000
: ld d, (FRAME_TILE_DATA_SIZE / 10);144
.copyTiles
  xor a
  ldh [rIF], a
  halt; wait for hblank
REPT 10
  ld a, [bc]
  ld [hli], a
  inc bc
ENDR
  dec d
  jr nz, .copyTiles

  ;; wait for vblank.
  ;; I want 30 fps video, which is 1 video frame per 2 GB frames.
  ;; wait for the 2nd frame to copy the tilemap
  ld a, IEF_VBLANK
  ldh [rIE], a
  halt
  ldh [rIF], a
  ld a, IEF_LCDC
  ldh [rIE], a

;  ld hl, _SCRN0
;  jr .copyMap
  ldh a, [rLCDC]
  bit LCDCB_BG8000, a
  jr z, :+
  ld hl, _SCRN1
  jr :++
: ld hl, _SCRN0
: ld d, 36
.copyMap
  xor a
  ldh [rIF], a
  halt ; wait for vblank
REPT 10
  ld a, [bc]
  ld [hli], a
  inc bc
ENDR
  bit 0, d
  jr z, .notEndLine
  ld a, d
  ld de, 12
  add hl, de
  ld d, a
.notEndLine
  dec d
  jr nz, .copyMap
  ldh a, [rLCDC]
  xor LCDCF_BG8000 | LCDCF_BG9C00
  ldh [rLCDC], a
  
  ;; wait for vblank so there are no other copies this frame.
  ld a, IEF_VBLANK
  ldh [rIE], a
  xor a
  ldh [rIF], a
  halt
  ldh [rIF], a
  ld a, IEF_LCDC
  ldh [rIE], a

  ld a, high(VidDataEnd)
  cp b
  jp nz, .copySetup
  ld a, low(VidDataEnd)
  cp c
  jp nz, .copySetup
  ld a, [kMaxBank]
  ld b, a
  ld a, [vCurrentBank]
  cp b
  jr nz, .notEndOfBanks
  ld a, 2
  jr .storeBank
.notEndOfBanks
  inc a
.storeBank
if (!def(TARGET_MEGADUCK))
  ld [rROMB0], a
endc
  ld [vCurrentBank], a
  ld bc, VidData
  
  

  jp .copySetup

  xor a
  ldh [rIE], a
  ldh [rIF], a
  halt

FOR N, 0, BANKS_TO_USE;;128;;208
  SECTION "Video Data {N}", ROMX,BANK[N + 1]

  IF N == 0
    VidData:
  ENDC

  VidTileData\@:
    incbin BIN_FILE_NAME, N * FRAME_DATA_SIZE_PER_BANK, FRAME_DATA_SIZE_PER_BANK
  .end
ENDR
VidDataEnd:

SECTION "Work RAM", wram0
vCurrentBank:
  ds 1