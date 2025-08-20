{:ok, body} = File.read("./ip-ranges.json")
json =  :json.decode(body)

zig_ip_trie = Helper.zig_ip_trie(json)
ip_trie = Helper.ip_trie(json)

sample_data = Helper.sample_data(json)

Benchee.run(
  %{
    "ip_trie" => fn -> Enum.each(sample_data, fn {_, host} -> Iptrie.lookup(ip_trie, host) end) end,
    "zip_ip_trie" => fn -> Enum.each(sample_data, fn {host, _} -> ZigDemo.lookup(zig_ip_trie, host, true) end) end
  }
)