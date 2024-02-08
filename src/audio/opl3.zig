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
    time: u64,
    reg: u16,
    data: u8,
};
pub const opl3_chip = extern struct {
    channel: [18]opl3_channel,
    slot: [36]opl3_slot,
    timer: u16,
    eg_timer: u64,
    eg_timerrem: u8,
    eg_state: u8,
    eg_add: u8,
    newm: u8,
    nts: u8,
    rhy: u8,
    vibpos: u8,
    vibshift: u8,
    tremolo: u8,
    tremolopos: u8,
    tremoloshift: u8,
    noise: u32,
    zeromod: i16,
    mixbuff: [2]i32,
    rm_hh_bit2: u8,
    rm_hh_bit3: u8,
    rm_hh_bit7: u8,
    rm_hh_bit8: u8,
    rm_tc_bit3: u8,
    rm_tc_bit5: u8,
    rateratio: i32,
    samplecnt: i32,
    oldsamples: [2]i16,
    samples: [2]i16,
    writebuf_samplecnt: u64,
    writebuf_cur: u32,
    writebuf_last: u32,
    writebuf_lasttime: u64,
    writebuf: [1024]opl3_writebuf,
};
pub const opl3_channel = extern struct {
    slots: [2][*c]opl3_slot,
    pair: [*c]opl3_channel,
    chip: [*c]opl3_chip,
    out: [4][*c]i16,
    chtype: u8,
    f_num: u16,
    block: u8,
    fb: u8,
    con: u8,
    alg: u8,
    ksv: u8,
    cha: u16,
    chb: u16,
    ch_num: u8,
};
pub const opl3_slot = extern struct {
    channel: [*c]opl3_channel,
    chip: [*c]opl3_chip,
    out: i16,
    fbmod: i16,
    mod: [*c]i16,
    prout: i16,
    eg_rout: i16,
    eg_out: i16,
    eg_inc: u8,
    eg_gen: u8,
    eg_rate: u8,
    eg_ksl: u8,
    trem: [*c]u8,
    reg_vib: u8,
    reg_type: u8,
    reg_ksr: u8,
    reg_mult: u8,
    reg_ksl: u8,
    reg_tl: u8,
    reg_ar: u8,
    reg_dr: u8,
    reg_sl: u8,
    reg_rr: u8,
    reg_wf: u8,
    key: u8,
    pg_reset: u32,
    pg_phase: u32,
    pg_phase_out: u16,
    slot_num: u8,
};
pub extern fn OPL3_Generate(chip: *opl3_chip, buf: [*c]i16) void;
pub extern fn OPL3_GenerateResampled(chip: *opl3_chip, buf: [*c]i16) void;
pub extern fn OPL3_Reset(chip: *opl3_chip, samplerate: u32) void;
pub extern fn OPL3_WriteReg(chip: *opl3_chip, reg: u16, v: u8) void;
pub extern fn OPL3_WriteRegBuffered(chip: *opl3_chip, reg: u16, v: u8) void;
pub extern fn OPL3_GenerateStream(chip: *opl3_chip, sndptr: [*c]i16, numsamples: u32) void;
