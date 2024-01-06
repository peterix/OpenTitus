const std = @import("std");
const game = @import("src/game.zig");

pub fn main() !u8 {
    return game.run() catch |err| {
        std.log.err("Game exited with an error: {}", .{err});
        return 1;
    };
}
