//
// Copyright (C) 2008 - 2024 The OpenTitus team
//
// Authors:
// Eirik Stople
// Petr Mrázek
//
// "Titus the Fox: To Marrakech and Back" (1992) and
// "Lagaf': Les Aventures de Moktar - Vol 1: La Zoubida" (1991)
// was developed by, and is probably copyrighted by Titus Software,
// which, according to Wikipedia, stopped buisness in 2005.
//
// OpenTitus is not affiliated with Titus Software.
//
// OpenTitus is  free software; you can redistribute  it and/or modify
// it under the  terms of the GNU General  Public License as published
// by the Free  Software Foundation; either version 3  of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT  ANY  WARRANTY;  without   even  the  implied  warranty  of
// MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.   See the GNU
// General Public License for more details.
//

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
