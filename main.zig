const game = @import("src/game.zig");

pub fn main() !u8 {
    return try game.run();
}
