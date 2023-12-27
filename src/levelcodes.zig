const std = @import("std");

const levelcodes = [_][]const u8{
    "EFE8",
    "5165",
    "67D4",
    "2BDA",
    "11E5",
    "86EE",
    "4275",
    "A0B9",
    "501C",
    "E9ED",
    "D4E6",
    "A531",
    "CE96",
    "B1A4",
    "EBEA",
    "3B9C",
};

pub fn initCodes() void {
    // TODO: actually init the codes instead of hardcoding them
}

pub export fn levelForCode(input: [*c]u8) i16 {
    const input_span = std.mem.span(input);
    for (0.., levelcodes) |i, code| {
        if (std.mem.eql(u8, input_span, code)) {
            return @intCast(i);
        }
    }
    return -1;
}

pub export fn codeForLevel(level: i16) [*c]const u8 {
    if (level < 0 or level >= levelcodes.len) {
        return null;
    }
    return &levelcodes[@intCast(level)][0];
}
