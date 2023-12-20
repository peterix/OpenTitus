//
// Copyright (C) 2008 - 2011 The OpenTitus team
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

const LZW_CLEAR_CODE = 0x100;
const LZW_END_CODE = 0x101;
const LZW_FIRST = 0x102;
const LZW_MAX_TABLE = 4096;

const SqzError = error{
    OutOfMemory,
    InvalidFile,
    BadAlgorithm,
};

pub fn unSQZ2(inputfile: [*c]u8, allocator: Allocator) ![]u8 {
    var i: c_int = 0;
    _ = i;

    var file = try std.fs.cwd().openFile(std.mem.span(inputfile), .{});
    defer file.close();

    var header_buf: [4]u8 = undefined;

    _ = try file.read(&header_buf);

    var b1 = header_buf[0];
    var comp_type = header_buf[1];
    var b3 = header_buf[2];
    var b4 = header_buf[3];

    var out_len: usize = 0;
    out_len = (b1 & 0x0F);
    out_len <<= 8;
    out_len += b4;
    out_len <<= 8;
    out_len += b3;

    if (out_len == 0) {
        return SqzError.InvalidFile;
    }

    var output = try allocator.alloc(u8, out_len);
    errdefer {
        allocator.free(output);
    }

    var file_size = try file.getEndPos();
    var in_len = file_size - 4;
    var inbuffer = try allocator.alloc(u8, in_len);
    defer allocator.free(inbuffer);

    var bytes_read = try file.readAll(inbuffer);
    if (in_len != bytes_read) {
        return SqzError.InvalidFile;
    }

    if (comp_type == 0x10) {
        try lzw_decode(inbuffer, output);
    } else {
        try huffman_decode(inbuffer, output);
    }
    return output;
}

fn lzw_decode(input: []u8, output: []u8) !void {
    var nbit: u8 = 9;
    var bitadd: u8 = 0;
    var i: c_uint = 0;
    var k_pos: c_uint = 0;
    var k: c_uint = 0;
    var tmp_k: c_uint = 0;
    var w: c_uint = 0;
    var out_pos: c_uint = 0;
    var addtodict: bool = false;
    var dict_prefix: [LZW_MAX_TABLE]c_uint = undefined;
    var dict_character: [LZW_MAX_TABLE]u8 = undefined;
    var dict_length: c_uint = 0;
    var dict_stack: [LZW_MAX_TABLE]c_uint = undefined;

    while ((k_pos < input.len) and (out_pos < output.len)) {
        k = 0;
        i = 0;
        while (i < 4) {
            k <<= 8;
            if ((k_pos + i < input.len) and (i * 8 < bitadd + nbit))
                k += input[k_pos + i];
            i += 1;
        }
        k <<= @truncate(bitadd);
        k >>= @truncate(@sizeOf(c_int) * 8 - nbit);

        bitadd += nbit;
        while (bitadd > 8) {
            bitadd -= 8;
            k_pos += 1;
        }
        if (k == LZW_CLEAR_CODE) {
            nbit = 9;
            dict_length = 0;
            addtodict = false;
        } else if (k != LZW_END_CODE) {
            if (k > 255 and k < LZW_FIRST + dict_length) {
                i = 0;
                tmp_k = k;
                while (tmp_k >= LZW_FIRST) {
                    dict_stack[i] = dict_character[tmp_k - LZW_FIRST];
                    tmp_k = dict_prefix[tmp_k - LZW_FIRST];
                    if (i >= LZW_MAX_TABLE) {
                        return SqzError.InvalidFile;
                    }
                    i += 1;
                }
                dict_stack[i] = tmp_k;
                i += 1;
                tmp_k = i - 1;
                i -= 1;
                while (i > 0) {
                    output[out_pos] = @truncate(dict_stack[i]);
                    out_pos += 1;
                    i -= 1;
                }

                output[out_pos] = @truncate(dict_stack[0]);
                out_pos += 1;

                dict_stack[0] = dict_stack[tmp_k];
            } else if (k > 255 and k >= LZW_FIRST + dict_length) {
                i = 1;
                tmp_k = w;
                while (tmp_k >= LZW_FIRST) {
                    dict_stack[i] = dict_character[tmp_k - LZW_FIRST];
                    tmp_k = dict_prefix[tmp_k - LZW_FIRST];
                    if (i >= LZW_MAX_TABLE) {
                        return SqzError.InvalidFile;
                    }
                    i += 1;
                }
                dict_stack[i] = tmp_k;
                i += 1;

                if (dict_length > 0) {
                    tmp_k = dict_character[dict_length - 1];
                } else {
                    tmp_k = w;
                }

                dict_stack[0] = tmp_k;
                tmp_k = i - 1;
                i -= 1;
                while (i > 0) {
                    output[out_pos] = @truncate(dict_stack[i]);
                    out_pos += 1;
                    i -= 1;
                }

                output[out_pos] = @truncate(dict_stack[0]);
                out_pos += 1;
                dict_stack[0] = @truncate(dict_stack[tmp_k]);
            } else {
                output[out_pos] = @truncate(k);
                out_pos += 1;
                dict_stack[0] = k;
            }
            if (addtodict and (LZW_FIRST + dict_length < LZW_MAX_TABLE)) {
                dict_character[dict_length] = @truncate(dict_stack[0]);
                dict_prefix[dict_length] = w;
                dict_length += 1;
            }

            w = k;
            addtodict = true;
        }
        if (LZW_FIRST + dict_length == (@as(u32, 1) << @truncate(nbit)) and (nbit < 12)) {
            nbit += 1;
        }
    }
}

fn huffman_decode(input: []u8, output: []u8) !void {
    const treesize = (@as(u16, input[1]) << 8) + input[0];
    var node: u16 = 0;
    var state: c_int = 0;
    var count: u16 = 0;

    var last: u8 = 0;
    var out_pos: c_uint = 0;

    for (2 + treesize..input.len) |i| {
        var bit: u8 = 128;
        while (bit >= 1) {
            defer bit >>= 1;
            if (input[i] & bit != 0)
                node += 1;
            var bintree = (@as(u16, input[3 + node * 2]) << 8) + @as(u16, input[2 + node * 2]);
            if (bintree <= 0x7FFF) {
                node = bintree >> 1;
            } else {
                node = bintree & 0x7FFF;
                var nodeL: u8 = @truncate(node & 0x00FF);
                if (state == 0) {
                    if (node < 0x100) {
                        last = nodeL;
                        output[out_pos] = last;
                        out_pos += 1;
                    } else if (nodeL == 0) {
                        state = 1;
                    } else if (nodeL == 1) {
                        state = 2;
                    } else {
                        for (1..nodeL + 1) |_| {
                            output[out_pos] = last;
                            out_pos += 1;
                        }
                    }
                } else if (state == 1) {
                    for (1..node + 1) |_| {
                        output[out_pos] = last;
                        out_pos += 1;
                    }
                    state = 0;
                } else if (state == 2) {
                    count = 256 * @as(u16, nodeL);
                    state = 3;
                } else if (state == 3) {
                    count += @as(u16, nodeL);
                    for (1..count + 1) |_| {
                        output[out_pos] = last;
                        out_pos += 1;
                    }
                    state = 0;
                }
                node = 0;
            }
        }
    }
}
