# wjec-asm-LMC-interpreter
![wjec asm](https://github.com/Squaresweets/WJEC-asm-LMC-interpreter/assets/51029884/9e0336bf-0b11-4481-8c60-0c7600971bcc)

For A Level Electronics (WJEC), we have to use a version of the PICmicro MID-RANGE assembly language. This is an absolutely terrible assembly language, with many annoying quirks.

One of the things I hated most about it was the lack of indirect addressing, it seemed that in some versions of the language you could use the FSR and INDF registers to do this, however, that didn't seem to be supported in the version we were allowed to use. After lots of research and trial and error, I found that you could do this:
```
	INDF   EQU @bptr
	FSR    EQU bptr
```
To restore the use of those registers. This also has the side effect of allowing me to access all of the RAM (not just the first 27 bytes). To take out my anger at this language and to try out indirect addressing, I decided to port [little man computer](https://peterhigginson.co.uk/lmc/), since it is so much better.

The final program is pretty optimised, but nowhere near perfect. There are quite a few inconsistencies between the actual LMC and this interpreter, but it is suitable for most applications. To use it you have to compile a program in LMC, then copy the memory (in the form 901 399 901 199 902) into the [nodeJS thingimabob](https://replit.com/@MatthewCollier2/picklemancomputerconverter). The output can then be pasted into the ldapgrm section of the asm (there is already a simple prime finder program preloaded in there).

Hope you "enjoy" this, cause it was pretty fun to make.

Cya :p
