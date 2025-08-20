defmodule Helper do
  def zig_ip_trie(json) do
    ip_trie = ZigDemo.create()

    networks =
      json
      |> parse()
      |> Enum.reject(fn network -> network == nil end)

    fill(networks, ip_trie)

    ip_trie
  end

  def ip_trie(%{"prefixes" => networks}) do
    networks =
      Enum.map(networks, fn %{"ip_prefix" => network, "region" => region} -> {network, region} end)

    Iptrie.new(networks)
  end

  def parse(%{"prefixes" => prefixes}) do
    Enum.map(prefixes, fn prefix -> map(prefix) end)
  end

  def sample_data(%{"prefixes" => prefixes}) do
    prefixes
    |> Enum.take(20)
    |> Enum.flat_map(fn %{"ip_prefix" => network} -> Pfx.hosts(network) end)
    |> Enum.map(fn host -> {to_octet(host), host} end)
    |> Enum.filter(fn {host, _str} -> host != nil end)
  end

  def to_octet(host) do
    case String.split(host, ".") do
      [o1, o2, o3, o4] ->
        [
          String.to_integer(o1),
          String.to_integer(o2),
          String.to_integer(o3),
          String.to_integer(o4)
        ]

      _ ->
        nil
    end
  end

  def map(%{"ip_prefix" => ip_prefix}) do
    cidr =
      ~r/^(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\/(3[0-2]|[12]?\d)$/x

    case Regex.run(cidr, ip_prefix) do
      [_, o1, o2, o3, o4, prefix] ->
        {[
           String.to_integer(o1),
           String.to_integer(o2),
           String.to_integer(o3),
           String.to_integer(o4)
         ], String.to_integer(prefix)}

      _ ->
        nil
    end
  end

  def fill(networks, ip_trie) do
    Enum.each(networks, fn {addr, len} -> ZigDemo.add(ip_trie, addr, len) end)
  end
end
