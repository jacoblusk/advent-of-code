day7.exe: day7.c
	clang $< -o $@

format: day7.c
	clang-format -i -style=Microsoft $<

clean: day7.exe
	rm $<

.PHONY: format clean