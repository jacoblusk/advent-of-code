LINK_LIBRARIES := kernel32.lib shlwapi.lib

day1.exe: day1.asm
	ml64 $< /Zi /link /subsystem:windows $(LINK_LIBRARIES) /entry:main

run: day1.exe
	python -c "import subprocess; print(subprocess.call(['day1.exe']))"

clean:
	rm -f day1.exe

.PHONY: run clean