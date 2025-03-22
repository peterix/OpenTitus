const std = @import("std");
pub const Endian = std.builtin.Endian;

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const debug = std.debug;
const assert = debug.assert;

const readIntBig = std.mem.readIntBig;
const readIntLittle = std.mem.readIntLittle;

/// Removes an integer from the front of a byte slice
/// Asserts that bytes.len >= @typeInfo(T).Int.bits / 8. Reads the integer starting from index 0
/// and ignores extra bytes.
/// The bit count of T must be evenly divisible by 8.
pub fn chompInt(comptime T: type, comptime endian: Endian, bytes: *[]const u8) T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    var result: T = undefined;
    result = std.mem.readInt(T, bytes.*[0..n], endian);
    bytes.*.len -= n;
    bytes.*.ptr += n;
    return result;
}

pub fn getInt(comptime T: type, comptime endian: Endian, bytes: []const u8) T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    return std.mem.readInt(T, bytes[0..n], endian);
}
