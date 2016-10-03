# Firmware for a homemade sound card

### What is this?

This is the firmware for the sound sub-system of a [homemade computer][dhpc]. The said system
is built around an 8bit microcontroller (ATMEGA644). It's a four-bit synthesizer with four channels,
which can be programmed and/or activated independently. Two of the channels are based on a square
wave generator with selectable duty cycle (only two levels are available). The third channel is
based on a triangle wave generator and the fourth relies on a pseudo-random number generator (PRNG).
The firmware provides a basic API for "programming" each channel (setting a note, octave, duration
and effect). The file melody.asm contains a sample melody that uses almost all channels of the
synthesizer -- it's the introduction theme from Taito's arcade game "Bubble Bobble"! This piece of
software, as well as the whole computer, was built as a project for [deltaHacker magazine][delta].

### How can I use it?

In order to use this piece of software in any meaningful way, you have to built the relevant
[hardware][dhpc]. If you have already decided to built the homemade computer and came here for
the GPU firmware, you just have to download "snd-fw.hex". This the only file you need, unless you
want to hack the firmware. In the later case, you'll need the assembler avrasm2.exe, that is
part of [Atmel Studio][studio]. If you're working under Linux, you can use a compatible
assembler like avra.


[delta]:    http://deltahacker.gr                       "ethical hacking magazine"
[dhpc]:     https://github.com/pvar/dhpc_hardware       "schematics and PCB"
[studio]:   http://www.atmel.com/tools/atmelstudio.aspx "Atmel IDE for the AVR microcontrollers"
