.DEFAULT_GOAL := debug_local_platform

debug_local_platform:
	zig build

release:
	zig build --release=safe -Dtarget=x86_64-linux-gnu.2.27
	zig build --release=safe -Dtarget=x86_64-windows

test:
	zig build test --summary all

# Clean target
clean:
	rm -f ./bin/titus/opentitus
	rm -f ./bin/titus/opentitus.exe
	rm -f ./bin/moktar/openmoktar
	rm -f ./bin/moktar/openmoktar.exe

# Phony targets
.PHONY: debug_local_platform clean test
