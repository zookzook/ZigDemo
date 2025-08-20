# ZigDemo

Inspired by the article/video [Fast IP Address Matching in Elixir ](https://elixirforum.com/t/fast-ip-address-matching-in-elixir-with-radix-trees-and-persistent-term-michael-lubas-code-beam-america-2022/54930?u=zookzook)
, I wanted to explore how fast a similar solution could be when implemented in Zig.  
Thanks to the excellent package [Zigler](https://hexdocs.pm/zigler/Zig.html), writing NIF bindings for Zig code is straightforward.

## Use Case ##

We build the IPv4 trie once, containing all network addresses.  
This structure remains immutable afterward. Then, a large number of host addresses can be checked against it to see whether they belong to any network.

For example, if the IPv4 trie contains the network `35.180.0.0/16`, then looking up the host address `35.180.1.0` will return a positive result.

## Test Data ##

For testing, I used the IPv4 ranges published by AWS.  
They provide an endpoint that returns a JSON file with the current list of CIDR network blocks:

```bash
curl -O https://ip-ranges.amazonaws.com/ip-ranges.json
```

This list served as the basis. For the first 20 networks, all possible host addresses were tested.
Here are the results:

```
Operating System: macOS
CPU Information: Apple M1 Pro
Number of Available Cores: 10
Available memory: 32 GB
Elixir 1.18.3
Erlang 28.0.2
JIT enabled: true

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 0 ns
reduction time: 0 ns
parallel: 1
inputs: none specified
Estimated total run time: 14 s

Benchmarking ip_trie ...
Benchmarking zig_ip_trie ...
Calculating statistics...
Formatting results...

Name                  ips        average  deviation         median         99th %
zig_ip_trie         53.34       18.75 ms     ±1.11%       18.65 ms       19.33 ms
ip_trie              6.22      160.85 ms     ±1.49%      159.82 ms      166.22 ms

Comparison:
zig_ip_trie         53.34
ip_trie              6.22 - 8.58x slower +142.10 ms

```

Lookups for host addresses are about 8.5x faster compared to the pure Elixir implementation.
The Elixir version, however, provides a broader set of features, while the Zig version focuses solely on this one use case.

## Potential Usage ##

The Zig implementation avoids mutexes, which comes with some considerations when using it in a Phoenix environment.
Read operations can safely be performed in parallel, but write operations must be handled by a single process.
A common approach would be to use a GenServer that exclusively builds the IP trie structure and then stores the reference, for example,
in the Persistent Term.
Other processes can read the reference from the Persistent Term and use it for host lookups.
Alternatively, the reference can also be stored in ETS tables.