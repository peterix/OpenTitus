//
// Copyright (C) 2013-2018 Alexey Khokholov (Nuke.YKT)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//
//  Nuked OPL3 emulator.
//  Thanks:
//      MAME Development Team(Jarek Burczynski, Tatsuyuki Satoh):
//          Feedback and Rhythm part calculation information.
//      forums.submarine.org.uk(carbon14, opl3):
//          Tremolo and phase generator calculation information.
//      OPLx decapsulated(Matthew Gambrell, Olli Niemitalo):
//          OPL2 ROMs.
//      siliconpr0n.org(John McMaster, digshadow):
//          YMF262 and VRC VII decaps and die shots.
//
// version: 1.8
//

// NOTE: automatically translated from `opl3.h`

pub const opl3_writebuf = extern struct {
    time: u64 = 0,
    reg: u16 = 0,
    data: u8 = 0,
};
pub const opl3_chip = extern struct {
    channel: [18]opl3_channel = @import("std").mem.zeroes([18]opl3_channel),
    slot: [36]opl3_slot = @import("std").mem.zeroes([36]opl3_slot),
    timer: u16 = 0,
    eg_timer: u64 = 0,
    eg_timerrem: u8 = 0,
    eg_state: u8 = 0,
    eg_add: u8 = 0,
    eg_timer_lo: u8 = 0,
    newm: u8 = 0,
    nts: u8 = 0,
    rhy: u8 = 0,
    vibpos: u8 = 0,
    vibshift: u8 = 0,
    tremolo: u8 = 0,
    tremolopos: u8 = 0,
    tremoloshift: u8 = 0,
    tremolo_dirty: u8 = 0,
    noise: u32 = 0,
    zeromod: i16 = 0,
    mixbuff: [4]i32 = @import("std").mem.zeroes([4]i32),
    rm_hh_bit2: u8 = 0,
    rm_hh_bit3: u8 = 0,
    rm_hh_bit7: u8 = 0,
    rm_hh_bit8: u8 = 0,
    rm_tc_bit3: u8 = 0,
    rm_tc_bit5: u8 = 0,
    rateratio: i32 = 0,
    samplecnt: i32 = 0,
    oldsamples: [4]i16 = @import("std").mem.zeroes([4]i16),
    samples: [4]i16 = @import("std").mem.zeroes([4]i16),
    writebuf_samplecnt: u64 = 0,
    writebuf_cur: u32 = 0,
    writebuf_last: u32 = 0,
    writebuf_lasttime: u64 = 0,
    writebuf: [1024]opl3_writebuf = @import("std").mem.zeroes([1024]opl3_writebuf),
};

pub const opl3_channel = extern struct {
    slotz: [2][*c]opl3_slot = @import("std").mem.zeroes([2][*c]opl3_slot),
    pair: [*c]opl3_channel = null,
    chip: [*c]opl3_chip = null,
    out: [4][*c]i16 = @import("std").mem.zeroes([4][*c]i16),
    out_cnt: u8 = 0,
    chtype: u8 = 0,
    f_num: u16 = 0,
    block: u8 = 0,
    fb: u8 = 0,
    con: u8 = 0,
    alg: u8 = 0,
    ksv: u8 = 0,
    cha: u16 = 0,
    chb: u16 = 0,
    chc: u16 = 0,
    chd: u16 = 0,
    ch_num: u8 = 0,
};

pub const opl3_slot = extern struct {
    channel: [*c]opl3_channel = null,
    chip: [*c]opl3_chip = null,
    mod: [*c]i16 = null,
    trem: [*c]u8 = null,
    pg_reset: u32 = 0,
    pg_phase: u32 = 0,
    pg_inc: u32 = 0,
    out: i16 = 0,
    fbmod: i16 = 0,
    prout: i16 = 0,
    eg_rout: u16 = 0,
    eg_out: u16 = 0,
    eg_tl_ksl: u16 = 0,
    pg_phase_out: u16 = 0,
    key: u8 = 0,
    eg_gen: u8 = 0,
    reg_vib: u8 = 0,
    reg_mult: u8 = 0,
    reg_wf: u8 = 0,
    slot_num: u8 = 0,
    eg_ksl: u8 = 0,
    eg_ks: u8 = 0,
    reg_type: u8 = 0,
    reg_ksr: u8 = 0,
    reg_ksl: u8 = 0,
    reg_tl: u8 = 0,
    reg_ar: u8 = 0,
    reg_dr: u8 = 0,
    reg_sl: u8 = 0,
    reg_rr: u8 = 0,
    eg_rates: [4]u8 = @import("std").mem.zeroes([4]u8),
    eg_rate_hi: [4]u8 = @import("std").mem.zeroes([4]u8),
    eg_rate_lo: [4]u8 = @import("std").mem.zeroes([4]u8),
};

pub extern fn OPL3_Generate(chip: [*c]opl3_chip, buf: [*c]i16) void;
pub extern fn OPL3_GenerateResampled(chip: [*c]opl3_chip, buf: [*c]i16) void;
pub extern fn OPL3_Reset(chip: [*c]opl3_chip, samplerate: u32) void;
pub extern fn OPL3_WriteReg(chip: [*c]opl3_chip, reg: u16, v: u8) void;
pub extern fn OPL3_WriteRegBuffered(chip: [*c]opl3_chip, reg: u16, v: u8) void;
pub extern fn OPL3_GenerateStream(chip: [*c]opl3_chip, sndptr: [*c]i16, numsamples: u32) void;
pub extern fn OPL3_Generate4Ch(chip: [*c]opl3_chip, buf4: [*c]i16) void;
pub extern fn OPL3_Generate4ChResampled(chip: [*c]opl3_chip, buf4: [*c]i16) void;
pub extern fn OPL3_Generate4ChStream(chip: [*c]opl3_chip, sndptr1: [*c]i16, sndptr2: [*c]i16, numsamples: u32) void;

pub const OPL_ENABLE_STEREOEXT = @as(c_int, 0);
pub const OPL_WRITEBUF_SIZE = @as(c_int, 1024);
pub const OPL_WRITEBUF_DELAY = @as(c_int, 2);
