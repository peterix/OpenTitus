# Default target
all:
    zig build

# Clean target
clean:
    rm -rdf ./bin

# Phony targets
.PHONY: all clean
