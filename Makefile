.DEFAULT_GOAL := debug_local_platform

VERSION ?= "0.0.0"
PREFIX ?= "./zig-out"

debug_local_platform:
	zig build --prefix $(PREFIX)

release:
	@echo "Building OpenTitus $(VERSION)"
	zig build --release=small -Dtarget=x86_64-linux-gnu.2.27 -Dversion=$(VERSION) --prefix $(PREFIX)
	zig build --release=small -Dtarget=x86_64-windows -Dversion=$(VERSION) --prefix $(PREFIX)

test:
	@echo "Running tests..."
	zig build test --summary all

# Clean target
clean:
	@echo "Removing artifacts..."
	rm -f $(PREFIX)/opentitus
	rm -f $(PREFIX)/opentitus.exe
	rm -f $(PREFIX)/TITUS/README.txt
	rm -f $(PREFIX)/MOKTAR/README.txt

# Phony targets
.PHONY: debug_local_platform clean test release
