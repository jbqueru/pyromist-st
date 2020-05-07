# PyromiST
I am Djaybee from the MegaBuSTers

This is an attempt at building an Atari ST demoscreen in 2020, after
almost 25 years of not writing any such code.

Since I don't have access to actual hardware, this is being developed
on Hatari (currently v2.1.0) with EmuTOS (0.9.12, 192k US), using
RMAC as the assembler.

My Hatari configuration:

	hatari --confirm-quit no --machine st --memsize 512 --compatible yes --cpu-exact yes --spec512 512 --tos ~/develop/bin/emutos/emutos-192k-0.9.12/etos192us.img --fast-boot yes --harddrive out/

My RMAC configuration:

	rmac -s -v -p pyromist.s -o out/pyromist.prg
