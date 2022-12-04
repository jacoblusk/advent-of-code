LINK_LIBRARIES := kernel32.lib shlwapi.lib

day4.exe: day4.asm
	ml64 $< /Zi /link /subsystem:windows $(LINK_LIBRARIES) /entry:main

run: day4.exe
	python -c "import subprocess; print(subprocess.call(['day4.exe']))"

clean:
	rm -f day4.exe

.PHONY: run clean