always: f256.bin

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

cli.bin:    Makefile $(CLI) 
kernal.bin: Makefile $(F256) $(KERNAL)
f256.bin:   Makefile load.asm kernal.bin cli.bin

%.bin:
	 64tass $(COPT) $(filter %.asm, $^) -b -L $(basename $@).lst -o $@ 
	 

