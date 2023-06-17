# FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
# Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
# SPDX-License-Identifier: GPL-3.0-only

# f256.bin is the kernel bundled with a simple shell.
# v2basiic.bin is the kernel bundled with a C64 BASIC ROM.
# YOU MUST SUPPLY THE ROM YOURSELF.

always: f256.bin v2basic.bin

COPT = -C -Wall -Werror -Wno-shadow --verbose-list

KERNAL	= \
	kernal/dummy.asm \
	kernal/err.asm \
	kernal/iec.asm \
	kernal/io.asm \
	kernal/kbd.asm \
	kernal/keys.asm \
	kernal/mem.asm \
	kernal/rtc.asm \
	kernal/vectors.asm \


F256	= \
	platforms/f256/f256.asm \
	platforms/f256/interrupt_def.asm \
	platforms/f256/irq.asm \
	platforms/f256/screen.asm \
	hardware/hardware.asm \
	hardware/device.asm \
	hardware/ps2_kbd2.asm \
	hardware/ps2_f256.asm \
	platforms/f256/hardware.asm \
	platforms/f256/iec.asm \
	

CLI	= \
	cli/cli.asm \
	cli/cli_list.asm \
	cli/vectors.asm \

cli.bin:	Makefile $(CLI) 
kernal.bin:	Makefile $(F256) $(KERNAL)
f256.bin:	Makefile utils/bundle_cli.asm kernal.bin cli.bin
v2basic.bin:	Makefile utils/bundle_basic.asm kernal.bin roms/cbm_patched.bin

%.bin:
	 64tass $(COPT) $(filter %.asm, $^) -b -L $(basename $@).lst -o $@ 
	 

####### Rules for fetching a CBM BASIC ROM ####################################

WGET            ?= wget
CURL            ?= curl
CBM_BASIC       = 64c.251913-01.bin
CBM_ARCHIVE     = http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64

roms/%.bin:
	@echo
	@echo You must supply your own CBM ROMs.
	@echo Typing \"make curl-cbm\" or \"make wget-cbm\"
	@echo will fetch the default CBM BASIC ROM from
	@echo the web.
	@false

wget-cbm:
	$(WGET) $(CBM_ARCHIVE)/$(CBM_BASIC) -O roms/$(CBM_BASIC)

curl-cbm:
	$(CURL) -L $(CBM_ARCHIVE)/$(CBM_BASIC) >roms/$(CBM_BASIC)

# Patch CBM BASIC V2 to fix the floating-point multiply bug:
# https://www.c64-wiki.com/wiki/Multiply_bug
roms/cbm_patched.bin: utils/patch_cbm.asm roms/$(CBM_BASIC)
	@echo Patching CBM BASIC V2 to fix the multiply bug.
	64tass -b $< -I . -D basic=\"$(filter roms/%.bin, $^)\" -o $@
	@echo
