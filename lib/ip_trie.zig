///
/// This is a Radix Trie (Patricia-Trie) implementation for IP4 networks. It is based on the binary representation of IP4 networks.
/// With 32 bits, we have a tree with a maximum depth of 32 levels. For a given IP4 address, it can be determined
/// whether or not this address can be found by an IP4 network.
///
/// The primary use case is the provision of a white or black list for IP addresses.
///
const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

const IP4Network = @import("ip4_network.zig");

///
/// This is am internal node representing the state of a node or a leaf
/// the prefix and length describe the matched prefix of the node
/// left and right contain pointers to the left and right node. We choose the low value to branch to the left
/// and the high value to branch to the right.
///
/// The leaf contains the IP4 network as the payload for the final check if the given address belongs to the network.
///
pub const Node = struct {
    prefix: ?u32 = null, // the prefix of the node, optional in some cases if two children don't have a prefix
    length: u8 = 0, // the length of the prefix bits
    left: ?*Node = null, // left node in the case of a low bit
    right: ?*Node = null, // right node in the case of a high bit
    ip4: ?IP4Network = null, // the payload of the leaf

    /// Returns true, if the node is empty
    fn isEmpty(self: Node) bool {
        return self.prefix == null and self.length == 0 and self.left == null and self.right == null;
    }

    /// Returns true if this is a leave, right and left are empty
    fn isLeaf(self: Node) bool {
        return self.right == null and self.left == null;
    }

    /// Returns true, if the prefix matches the prefix of the addr
    fn matchPrefix(self: Node, addr: u32) bool {
        return if (self.prefix) |v| (addr & v) == v else true;
    }

    test "matchPrefix" {
        const n1: Node = .{ .prefix = 0b0110, .length = 4 };
        try expect(n1.matchPrefix(0b1000) == false);
        try expect(n1.matchPrefix(0b0110) == true);

        const n2: Node = .{};
        try expect(n2.matchPrefix(0b1000) == true);

        const n3: Node = .{ .prefix = 0b0110, .length = 3 };
        try expect(n3.matchPrefix(0b1000) == false);
        try expect(n3.matchPrefix(0b0110) == true);
        try expect(n3.matchPrefix(0b0111) == true);
    }

    /// Releases the allocated memory, works recursivly (we always use the Arena allocator)
    fn deinit(self: Node, allocator: mem.Allocator) void {
        if (self.left) |left| {
            left.deinit(allocator);
            allocator.destroy(left);
        }

        if (self.right) |right| {
            right.deinit(allocator);
            allocator.destroy(right);
        }
    }

    /// Returns the depth of the tree. It should be <= 32.
    /// Works recursivly.
    pub fn depth(self: Node, level: usize) usize {
        const left_level = if (self.left) |left| left.depth(level + 1) else level;
        const right_level = if (self.right) |right| right.depth(level + 1) else level;

        return @max(left_level, right_level);
    }

    /// Returns true, if the addr matches the prefix of a leaf in the tree.
    /// Works recursive
    fn lookup(self: Node, addr: u32, contains: bool) bool {
        // std.debug.print("{b:0>32}, {d} {b:0>32}\n", .{self.prefix orelse 0, self.length, addr});
        if (self.matchPrefix(addr)) {
            if (self.isLeaf()) {
                if(self.ip4) |ip4| {
                    const result = ip4.addr == addr or (contains and ip4.containsHost(addr));
                    if(result == false) {
                        // std.debug.print("{b:0>32} {b:0>32}\n", .{ip4.addr, addr});
                    }
                    return result;
                } // if
                else {
                    return false;
                } // else
            } else {
                const pos: u5 = @truncate(self.length);
                // std.debug.print("IsHigh: {d}: {} {d}\n",.{self.prefix orelse 0, isHigh(addr, pos), pos});
                if (isHigh(addr, pos)) {
                    return if (self.right) |r| r.lookup(addr, contains) else false;


                } // if
                else {
                    return if (self.left) |l| l.lookup(addr, contains) else false;
                } // else
            } // else
        } // if
        else {
            // std.debug.print("Not matched", .{});
            return false;
        } // else
    } // fn

    /// Adds a new leaf to the right
    fn add_right(self: *Node, network: IP4Network, allocator: mem.Allocator) !void {
        const right: *Node = try allocator.create(Node);
        right.* = Node{ .prefix = network.addr, .ip4 = network };
        self.right = right;

    }

    /// Adds a new leaf to the left
    fn add_left(self: *Node, network: IP4Network, allocator: mem.Allocator) !void {
        const left: *Node = try allocator.create(Node);
        left.* = Node{ .prefix = network.addr, .ip4 = network };
        self.left = left;
    }

    /// Splits the node:
    /// The node gets a new prefix and a new position
    /// depended on the bit of the new network addr the values of the node
    /// are moved to the left or to the right of the node
    fn split(self: *Node, range: RangeResult, network: IP4Network, allocator: mem.Allocator) !bool {
        const left: *Node = try allocator.create(Node);
        const right: *Node = try allocator.create(Node);

        if(range.length == 32) {
            // std.debug.print("Match duplicate {any}:{any}:\n", .{network, self});
            // network.debug(false);
            return false;
        }

        if (isHigh(network.addr, @truncate(range.length))) {
            left.* = self.*;
            right.* = Node{.prefix = network.addr, .ip4 = network };
        } else {
            right.* = self.*;
            left.* = Node{ .prefix = network.addr, .ip4 = network };
        }

        self.prefix = range.matched_bits;
        self.length = range.length;
        self.left = left;
        self.right = right;

        return true;
    }

    /// adds a new network to the IP4 trie
    /// Until the prefix isn't matched anymore
    /// the code searches for the node or leaf.
    /// In the case of a leaf the new leaf is added to the left or to the right.
    /// If the prefix is changed, we split the node and create two new nodes.
    ///
    fn add(self: *Node, network: IP4Network, allocator: mem.Allocator) !bool {
        if (self.isEmpty()) {
            self.prefix = network.addr;
            self.length = 0;
            self.ip4 = network;
            return true;
        }

        var n = self;

        while (true) {
            // std.debug.print("{b:0>32}, {d}:{b:0>32}\n", .{n.prefix orelse 0, n.length, network});
            const range = n.findRange(network.addr);
            // matched prefix
            if (range.length == n.length) {
                // use the right subtree
                if (isHigh(network.addr, @truncate(n.length))) {
                    if (n.right == null) {
                        try n.add_right(network, allocator);
                        return true;
                    } // if
                    else {
                        // std.debug.print("Right:\n", .{});
                        n = n.right.?;
                    } // else
                } // if
                else {
                    // use the left subtree
                    if (n.left == null) {
                        try n.add_left(network, allocator);
                        return true;
                    } // if
                    else {
                        // std.debug.print("Left:\n", .{});
                        n = n.left.?;
                    } // else
                } // else
            } // if
            else {
                return try n.split(range, network, allocator);
            } // else
        } // while
    }

    const RangeResult = struct { matched_bits: ?u32 = null, length: u8 = 0 };

    /// Determines the prefix match of two network addresses. It returns struct of type RangeResult:
    /// matched_bits: the mask of the first bits that are matched
    /// length: the number of bits
    ///
    fn findRange(self: Node, b: u32) RangeResult {
        if (self.prefix) |a| {
            const max_len = if (self.isLeaf()) 32 else self.length;
            var i: u8 = 0;
            var mask: u32 = 0x8000_0000;
            var matched_bits: u32 = 0x0000_0000;

            while (true) {
                const bit_a = a & mask;
                const bit_b = b & mask;

                if (bit_a == bit_b) {
                    matched_bits = matched_bits | bit_a;

                    i += 1;

                    if (i == max_len) {
                        return RangeResult{ .matched_bits = matched_bits, .length = i };
                    } // if

                    mask = mask >> 1;
                } else {
                    if (i == 0) {
                        return RangeResult{};
                    } // if
                    else {
                        return RangeResult{ .matched_bits = matched_bits, .length = i };
                    } // else
                } // else
            } // while
        } // if
        else {
            return RangeResult{};
        } // while
    }

    /// Prints the structure of the trie for debugging purpose, starting with the specified indent.
    /// Works recursive.
    fn tree(self: Node, indent: u32) void {
        for (0..indent) |_| {
            std.debug.print(" ", .{});
        }

        if (self.isLeaf()) {
            std.debug.print("{b:0>32}*\n", .{self.prefix orelse 0});
        } else {
            const prefix = (self.prefix orelse 0) >> @truncate(32 - self.length);
            std.debug.print("{[p]b:0>[l]}:{[l]d}\n", .{ .p = prefix, .l = self.length });

            if (self.left) |left| {
                std.debug.print("L", .{});
                left.tree(indent + 1);
            } else {
                std.debug.print("L\n", .{});
            }

            if (self.right) |right| {
                std.debug.print("R", .{});
                right.tree(indent + 1);
            } else {
                std.debug.print("R\n", .{});
            }
        }
    }
};

/// Returns true if the specified bit is 1.
inline fn isHigh(a: u32, pos: u5) bool {
    const mask: u32 = @as(u32, 0x8000_0000) >> pos;
    return (a & mask) != 0;
}

test "isHigh" {
    try expect(isHigh(0b1000 << 28, 0) == true);
    try expect(isHigh(0b1000 << 28, 1) == false);
    try expect(isHigh(0b1000 << 28, 2) == false);
    try expect(isHigh(0b1000 << 28, 3) == false);
}

allocator: mem.Allocator,
root: Node,
counter: u32 = 0,

const IpTrie = @This();

pub fn init(allocator: mem.Allocator) IpTrie {
    return .{ .allocator = allocator, .root = Node{} };
}

pub fn deinit(self: *IpTrie) void {
    self.root.deinit(self.allocator);
}

pub fn add(self: *IpTrie, network: IP4Network) !bool {
    const result = try self.root.add(network, self.allocator);
    if(result) {
        self.counter += 1;
    } // if
    return result;
}

pub fn lookup(self: IpTrie, addr: u32, contains: bool) bool {
    return self.root.lookup(addr, contains);
}

pub fn depth(self: IpTrie) usize {
    return self.root.depth(0);
}

pub fn tree(self: IpTrie, indent: u32) void {
    self.root.tree(indent);
}

test "simple ip trie" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var ip_trie = IpTrie.init(allocator);
    defer _ = ip_trie.deinit();

    const network_1 = IP4Network.init(0b0110 << 28, 24);
    const network_2 = IP4Network.init(0b0111 << 28, 24);
    const network_3 = IP4Network.init(0b1100 << 28, 24);
    const network_4 = IP4Network.init(0b1110 << 28, 24);
    const network_5 = IP4Network.init(0b1111 << 28, 24);

    try ip_trie.add(network_1);
    try ip_trie.add(network_2);
    try ip_trie.add(network_3);
    try ip_trie.add(network_4);
    try ip_trie.add(network_5);

    ip_trie.tree(0);

    try expect(ip_trie.lookup(0b0110 << 28, false) == true);
    try expect(ip_trie.lookup(0b0111 << 28, false) == true);
    try expect(ip_trie.lookup(0b1100 << 28, false) == true);
    try expect(ip_trie.lookup(0b1110 << 28, false) == true);
    try expect(ip_trie.lookup(0b1111 << 28, false) == true);
    try expect(ip_trie.lookup(0b0000 << 28, false) == false);
}
