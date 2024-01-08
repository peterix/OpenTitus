const std = @import("std");
const Allocator = std.mem.Allocator;

const ParseOptions = std.json.ParseOptions;
const innerParse = std.json.innerParse;
const innerParseFromValue = std.json.innerParseFromValue;
const Value = std.json.Value;

pub fn ManagedJSON(comptime T: type) type {
    return struct {
        value: T,
        arena: *std.heap.ArenaAllocator,

        const Self = @This();

        pub fn fromJson(parsed: std.json.Parsed(T)) Self {
            return .{
                .arena = parsed.arena,
                .value = parsed.value,
            };
        }

        pub fn deinit(self: Self) void {
            const arena = self.arena;
            const allocator = arena.child_allocator;
            arena.deinit();
            allocator.destroy(arena);
        }
    };
}

/// A thin wrapper around `std.StringArrayHashMapUnmanaged` that implements
/// `jsonParse`, `jsonParseFromValue`, and `jsonStringify`.
/// This is useful when your JSON schema has an object with arbitrary data keys
/// instead of comptime-known struct field names.
pub fn JsonList(comptime T: type) type {
    return struct {
        list: std.ArrayListUnmanaged(T) = .{},

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.list.deinit(allocator);
        }

        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            var list = std.ArrayListUnmanaged(T){};
            errdefer list.deinit(allocator);

            if (.array_begin != try source.next()) return error.UnexpectedToken;
            while (true) {
                switch (try source.peekNextTokenType()) {
                    .array_end => {
                        // consume the array end
                        _ = try source.next();
                        break;
                    },
                    else => {},
                }

                const new_item_ptr = try list.addOne(allocator);
                new_item_ptr.* = try innerParse(T, allocator, source, options);
            }
            return .{ .list = list };
        }

        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            if (source != .object) return error.UnexpectedToken;

            var list = std.ArrayListUnmanaged(T){};
            errdefer list.deinit(allocator);

            var it = source.object.iterator();
            while (it.next()) |kv| {
                try list.put(allocator, kv.key_ptr.*, try innerParseFromValue(T, allocator, kv.value_ptr.*, options));
            }
            return .{ .list = list };
        }

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginArray();
            for (self.list.items) |item| {
                try jws.write(item);
            }
            try jws.endArray();
        }
    };
}
