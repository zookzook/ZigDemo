const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const expect = std.testing.expect;

const IP4Network = @This();

addr: u32,
length: u8,

pub fn init(addr: u32, length: u5) IP4Network {
    return .{ .addr = addr, .length = length };
}

pub fn newNetwork(addr: [4]u8, length: u5) IP4Network {
    return .{ .addr = toU32(addr), .length = length };
}

pub fn containsHost(self: IP4Network, addr: u32) bool {
    return addr & self.maskbits() == self.addr;
}

pub fn toU32(addr: [4]u8) u32 {
    return @as(u32, addr[0]) << 24 | @as(u32, addr[1]) << 16 | @as(u32, addr[2]) << 8 | @as(u32, addr[3]);
}

fn toBinarString(buf: []u8, addr: u32) []u8 {
    const bigEndian = switch (native_endian) {
        .little => @byteSwap(addr),
        .big => addr,
    };
    const bytes = @as(*const [4]u8, @ptrCast(&bigEndian));

    return std.fmt.bufPrint(buf, "{b:0>8} {b:0>8} {b:0>8} {b:0>8}", .{bytes[0], bytes[1], bytes[2], bytes[3]}) catch unreachable;
}

fn toDecimalString(buf: []u8, addr: u32) []u8 {
    const bigEndian = switch (native_endian) {
        .little => @byteSwap(addr),
        .big => addr,
    };
    const bytes = @as(*const [4]u8, @ptrCast(&bigEndian));

    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{bytes[0], bytes[1], bytes[2], bytes[3]}) catch unreachable;
}

inline fn hostbits(self: IP4Network) u32 {
    return @as(u32, 0xff_ff_ff_ff) >> @truncate(self.length);
}

inline fn maskbits(self: IP4Network) u32 {
    return ~self.hostbits();
}

pub fn debug(self: IP4Network, binar: bool) void {
    var buf: [36]u8 = undefined;

    if (binar) {
        const addr = toBinarString(&buf, self.addr);
        std.debug.print("Network: {s}/{d}\n", .{ addr, self.length });
        const mask = toBinarString(&buf, self.maskbits());
        std.debug.print("Mask   : {s}\n", .{mask});
    } // if
    else {
        const addr = toDecimalString(&buf, self.addr);
        std.debug.print("Network: {s}/{d}\n", .{ addr, self.length });
        const mask = toDecimalString(&buf, self.maskbits());
        std.debug.print("Mask   : {s}\n", .{mask});
    } // else
}

test "contains host" {
    const network = IP4Network.newNetwork([4]u8{ 192, 168, 1, 0 }, 24);
    network.debug(false);
    network.debug(true);

    std.debug.print("{d}\n", .{1});
    std.debug.print("{d}\n", .{1 << 2});
    std.debug.print("{d}\n", .{1 << 3});
    std.debug.print("{d}\n", .{1 << 4});

    std.debug.print("{b:0>32}\n", .{7096099});
    std.debug.print("{b:0>32}\n", .{~(@as(u32, 0xff_ff_ff_ff) >> 8)});

    try expect(network.containsHost(toU32([4]u8{ 192, 168, 1, 1 })) == true);
    try expect(network.containsHost(toU32([4]u8{ 192, 168, 0, 1 })) == false);


    const network2 = IP4Network.newNetwork([4]u8{ 3, 5, 140, 0 }, 22);
    try expect(network2.containsHost(toU32([4]u8{ 192, 168, 1, 1 })) == false);
    try expect(network2.containsHost(toU32([4]u8{ 192, 168, 0, 1 })) == false);
    try expect(network2.containsHost(toU32([4]u8{ 3, 5, 140, 1 })) == true);

    network2.debug(true);

    const network3 = IP4Network.newNetwork([4]u8{ 35, 71, 108, 0 }, 24);
    network3.debug(false);
    const addr : u32 = 7096099;
    const network4 = IP4Network.init(@byteSwap(addr), 24);
    network4.debug(false);

    const bytes = [4]u8{ 35, 71, 108, 0};
    const value = std.mem.bytesToValue(u32, &bytes);
    std.debug.print("{any}\n", .{value});
}
