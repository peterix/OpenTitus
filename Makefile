.DEFAULT_GOAL := debug_local_platform

VERSION ?= "0.0.0"

debug_local_platform:
	zig build

release:
	@echo "Building OpenTitus $(VERSION)"
	zig build --release=small -Dtarget=x86_64-linux-gnu.2.27 -Dversion=$(VERSION)
	zig build --release=small -Dtarget=x86_64-windows -Dversion=$(VERSION)

test:
	@echo "Running tests..."
	zig build test --summary all

# Clean target
clean:
	@echo "Removing artifacts..."
	rm -f ./zig-out/opentitus
	rm -f ./zig-out/opentitus.exe
	rm -f ./zig-out/TITUS/README.txt
	rm -f ./zig-out/MOKTAR/README.txt

# Phony targets
.PHONY: debug_local_platform clean test release
