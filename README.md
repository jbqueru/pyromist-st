# democore-st
I am Djaybee from the MegaBuSTers

This is the intended nano-kernel core for my Atari ST demos.

This includes basic machine setup, a multitasking threader, and handling
of framebuffer swapping.

Since I don't have access to actual hardware, this is being developed
on Hatari (currently v2.1.0) with EmuTOS (0.9.12, 192k US), using
RMAC as the assembler.

My Hatari configuration:

	hatari --confirm-quit no --machine st --memsize 2048 --cpuclock 8 --compatible yes --cpu-exact yes --spec512 1 --tos ~/develop/bin/emutos/emutos-192k-0.9.12/etos192us.img --harddrive ~/develop/src/atari-st/democore/out

My RMAC configuration:

	rmac -s -v -p democore.s -o out/democore.prg
