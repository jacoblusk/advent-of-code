LINK_LIBRARIES := kernel32.lib shlwapi.lib

day5.exe: day5.asm
	ml64 $< /Zi /link /subsystem:windows $(LINK_LIBRARIES) /entry:main

run: day5.exe
	python -c "import subprocess; print(subprocess.call(['day5.exe']))"

clean:
	rm -f day5.exe

.PHONY: run clean