# democore-st
I am Djaybee from the MegaBuSTers

This is the intended nano-kernel core for my Atari ST demos.

This includes basic machine setup, a multithreader, and handling
of framebuffer swapping.

Since I don't have access to actual hardware, this is being developed
on Hatari (currently v2.1.0) with EmuTOS (0.9.12, 192k US), using
RMAC as the assembler.

My Hatari configuration:

	hatari --confirm-quit no --machine st --memsize 2048 --cpuclock 8 --compatible yes --cpu-exact yes --spec512 1 --tos ~/develop/bin/emutos/emutos-192k-0.9.12/etos192us.img --harddrive ~/develop/src/atari-st/democore/out

My RMAC configuration:

	rmac -s -v -p coreuser.s -o out/demo.prg

# Multitasking principles

In a normal interrupt handler, the handler is expected to leave the CPU
registers unchanged between when it enters and when it exits. That can
happen by not touching those registers at all, but that can also happen
by saving the registers on entry and restoring them on exit. The best
practice is to do all the saving on the stack, as that allows to nest
interrupts.

	|
	|
	| regular code
	|
	| --------------------> | interrupt
	                        | save registers (to stack)
	                        | (do interrupts stuff)
	                        | restore registers (from stack)
	| <-------------------- | RTE (return from interrupt)
	|
	| regular code
	|
	|

When switching between threads, the trick is to save the state of the
current thread, and to then restore the state of the thread being switched to.

Starting with the restoring side, obviously PC has to be restored last.
The practical way to restore PC is a return instruction, as long as the stack
can be made to point to the right location. RTE is the most practical way to
return to thread code, as it atomically restores PC and SR while adjusting
SSP, and where (in turn) restoring SR restores interrupts and (if the thread
was in user mode) switches the stack back to USP.

If the threads were in supervisor mode, the interrupt stack is the same as
the thread stack (SSP), which in turn implies that the stack must be
swapped from within the interrupt handler, which is more complex than
switching between user mode threads. However, that also implies that the
supervisor stack is an appropriate location to save other information,
including the other registers (D0-D7, A0-A6 and USP), such that only
the stack must be saved off-stack (!).

Limited by the instruction set, USP can't be handled directly to/from the
stack, it can only go through other address registers, which means that USP
must be restored before restoring other registers, and (for symmetry)
saved after saving other registers.

In practice, that means that SSP gets swapped, then USP gets restored,
then D0-A6 (via a MOVEM), and finally RTE takes care of SR then PC (in
that order) and adjusting SSP back. For symmetry, this means that
PC and SR gets pushed by the interrupt handler, then D0-A6 through a MOVEM,
then USP. SSP gets stored into the thread table.

	|
	|
	| regular code, thread 1
	|
	| --------------------> | interrupt
	                        | save registers (to stack)
	                        | (do interrupts stuff)
	                        | save SSP to structure for thread 1
	                        | restore SSP from structure for thread 2
	                        | restore registers (from stack)
	| <-------------------- | RTE (return from interrupt)
	|
	| regular code, thread 2
	|
	|

Now, that means that we can restore threads that had been interrupted,
but this creates a chicken-and-egg issue: a thread can only be restored
if it had been interrupted, it can only be interrupted if it had been
running, and it can only be running if it had been restored.

That chicken-and-egg gets broken by storing data that pretends that the
thread had been interrupted: where the thread's storage is supposed to be,
store data in the same format as it would have been during an interrupt:
PC (the start address for the thread), SR (status with interrupts enabled),
then random data for D0-A6 and USP.

For simplicity, we'll assume that all interrupts that can switch
threads happen at the same level. Doing otherwise requires some extra
handling of SR to adjust interrupt levels, but also some deep care to
avoid re-entering the thread-switching code via nested interrupts.

It's also necessary to be able to explicitly switch threads outside of an
interrupt. Doing so requires essentially to pretend that an interrupt
happened. From user mode, the easiest approach is to go through a TRAP.
While that also works from supervisor mode, it's potentially easier to do
the switch by hand. This specifically allows to disable interrupts before
jumping to the scheduler routine, and in turn disabling interrupts by hand
allows to modify the thread state (block/unblock threads).

# List of threads

The following threads are supported, in order from highest priority:

1. Music thread. Running on a 50Hz timer, regardless of frame rate.
2. Update thread. As a special thread, it gets unblocked at each VBL,
and is expected to run in less than the duration of a frame.
3. Draw thread. As a special thread, it is tied to the page-flipping
logic in the VBL itself.
4. Background thread. Never expected to block, it uses all the leftover
CPU time from the other thread. This is the main thread.
