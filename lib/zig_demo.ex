defmodule ZigDemo do
  use Zig,
    otp_app: :zig_demo,
    resources: [
      :PointerResource
    ],
    release_mode: :fast

  ~Z"""

  const std = @import("std");
  const beam = @import("beam");
  const root = @import("root");
  const IpTrie = @import("ip_trie.zig");
  const IP4Network = @import("ip4_network.zig");

  const IPTrieResource = struct {
      arena: *anyopaque,  // we use the anyopaque type, because the semi.zig commands would run into an endless recursion.
      ip_trie: *anyopaque // same here, the IpTrie contains self references as well
  };

  pub const PointerResource = beam.Resource(*IPTrieResource, root, .{.Callbacks = PointerResourceCallbacks});

  pub const PointerResourceCallbacks = struct {
      pub fn dtor(s: **IPTrieResource) void {
          const ip_trie: *IpTrie = @ptrCast(@alignCast(s.*.ip_trie));
          ip_trie.deinit();

          const arena: *std.heap.ArenaAllocator = @ptrCast(@alignCast(s.*.arena));
          arena.deinit();

          beam.allocator.destroy(ip_trie);
          beam.allocator.destroy(arena);
          beam.allocator.destroy(s.*);
      }
  };

  pub fn create() !PointerResource {
      const ipTrieResource = try beam.allocator.create(IPTrieResource);
      const ip_trie = try beam.allocator.create(IpTrie);
      const arena_ptr = try beam.allocator.create(std.heap.ArenaAllocator);
      arena_ptr.* = std.heap.ArenaAllocator.init(beam.allocator);
      ip_trie.* = IpTrie.init(arena_ptr.allocator());

      ipTrieResource.arena = arena_ptr;
      ipTrieResource.ip_trie = ip_trie;

      return PointerResource.create(ipTrieResource, .{});
  }

  pub fn add(resource: PointerResource, network_addr: [4]u8, length: u8) !bool {
      const ipTrieResource : *IPTrieResource = resource.unpack();
      const ip_trie: *IpTrie = @ptrCast(@alignCast(ipTrieResource.ip_trie));
      const network = IP4Network.newNetwork(network_addr, @truncate(length));
      if(ip_trie.lookup(network.addr, true)) {
        return false;
      }
      return try ip_trie.add(network);
  }

  pub fn depth(resource: PointerResource) usize {
      const ipTrieResource : *IPTrieResource = resource.unpack();
      const ip_trie: *IpTrie = @ptrCast(@alignCast(ipTrieResource.ip_trie));
      return ip_trie.depth();
  }

  pub fn counter(resource: PointerResource) u32 {
      const ipTrieResource : *IPTrieResource = resource.unpack();
      const ip_trie: *IpTrie = @ptrCast(@alignCast(ipTrieResource.ip_trie));
      return ip_trie.counter;
  }

  pub fn lookup(resource: PointerResource, addr: [4]u8, contains: bool) bool {
      const ipTrieResource : *IPTrieResource = resource.unpack();
      const ip_trie: *IpTrie = @ptrCast(@alignCast(ipTrieResource.ip_trie));
      const addr_u32 = IP4Network.toU32(addr);
      return ip_trie.lookup(addr_u32, contains);
  }

  """
end
