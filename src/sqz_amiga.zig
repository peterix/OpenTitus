const std = @import("std");
const Allocator = std.mem.Allocator;
const bytes_ = @import("bytes.zig");
const chompInt = bytes_.chompInt;
const getInt = bytes_.getInt;
const Endian = bytes_.Endian;

const SqzError = error{
    OutOfMemory,
    InvalidFile,
    BadRead,
    NotImplemented,
};

/// This is very wrong and work in progress.
pub fn unSQZ(inputfile: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(inputfile, .{});
    defer file.close();

    var reader = file.reader();

    const compression_type = try reader.readByte();
    _ = try reader.readByte(); // skip, original code ignores this byte
    const out_len: u32 = try reader.readIntLittle(u32);

    const output = try allocator.alloc(u8, out_len);
    errdefer {
        allocator.free(output);
    }
    switch (compression_type) {
        0 => {
            // uncompressed
            _ = try reader.readAll(output);
            if (try file.getEndPos() != try file.getPos()) {
                return SqzError.InvalidFile;
            }
        },
        1 => {
            // probably huffman
            try huffman_decode_amiga(allocator, &file, output);
        },
        2 => {
            // probably lzw
            try lzw_decode_amiga(allocator, &file, output);
        },
        else => {
            return SqzError.InvalidFile;
        },
    }
    return output;
}

fn huffman_decode_amiga(allocator: std.mem.Allocator, file_handle: *std.fs.File, output: []u8) !void {
    _ = file_handle;
    _ = allocator;
    _ = output;
    return SqzError.NotImplemented;
}

var FILE_HANDLE1: *std.fs.File = undefined;
var LZW_chunk_bytes_read: u16 = undefined;
var lzw_read_buffer_length: u16 = undefined;
var lzw_read_buffer: []u8 = undefined;

var CHUNK_138B: []u8 = undefined;
var CHUNK_2716: []u16 = undefined;

var LZW_DICTIONARY: []u8 = undefined;
var LZW_DICT_SIZE: u16 = undefined;

var u16_ARWAD: u16 = undefined;
var u16_ZEBULON: u16 = undefined;
var u16_CIRI: u16 = undefined;

var _bool_initial_flag: bool = undefined;
var _bool_norwegian_wood: bool = undefined;

var nbit: u16 = undefined;

fn read_byte_for_lzw() !u32 {
    var read_amount: i32 = undefined;
    var new_start_offset: u16 = undefined;
    if (LZW_chunk_bytes_read == lzw_read_buffer_length) {
        LZW_chunk_bytes_read = 0;

        read_amount = @intCast(try FILE_HANDLE1.readAll(lzw_read_buffer));
        lzw_read_buffer_length = @as(u16, @intCast(read_amount));
        if (lzw_read_buffer_length == 0) {
            return 0xffffffff;
        }
    }
    new_start_offset = LZW_chunk_bytes_read;
    LZW_chunk_bytes_read = LZW_chunk_bytes_read + 1;
    return lzw_read_buffer[new_start_offset];
}

fn setup_lzw(allocator: std.mem.Allocator, file_handle: *std.fs.File) !void {
    FILE_HANDLE1 = file_handle;
    LZW_chunk_bytes_read = 0;
    lzw_read_buffer_length = 0;
    lzw_read_buffer = try allocator.alloc(u8, 0x200);
    CHUNK_138B = try allocator.alloc(u8, 0x138b);
    CHUNK_2716 = try allocator.alloc(u16, 0x138b);
    LZW_DICTIONARY = try allocator.alloc(u8, 0x138b);

    // cool. we skip a byte...
    _ = try read_byte_for_lzw();

    _bool_norwegian_wood = false;
    nbit = 9;
    LZW_DICT_SIZE = 0x1ff;
    var index: i16 = 0xFF;
    while (index > -1) : (index -= 1) {
        const index_u8: u8 = @intCast(index);
        CHUNK_2716[index_u8] = 0;
        LZW_DICTIONARY[index_u8] = index_u8;
    }
    u16_ARWAD = 0x101;
    u16_ZEBULON = 0;
    u16_CIRI = 0;
    _bool_initial_flag = false;
}

fn teardown_lzw(allocator: std.mem.Allocator) void {
    allocator.free(lzw_read_buffer);
    allocator.free(CHUNK_138B);
    allocator.free(CHUNK_2716);
    allocator.free(LZW_DICTIONARY);
}

fn lzw_decode_amiga(allocator: std.mem.Allocator, file_handle: *std.fs.File, output: []u8) !void {
    try setup_lzw(allocator, file_handle);
    defer teardown_lzw(allocator);
    _ = output;
    return SqzError.NotImplemented;
}
