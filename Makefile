# Default target
all:
	zig build

# Clean target
clean:
	rm -f ./bin/titus/opentitus
	rm -f ./bin/titus/opentitus.exe
	rm -f ./bin/moktar/openmoktar
	rm -f ./bin/moktar/openmoktar.exe

# Phony targets
.PHONY: all clean
