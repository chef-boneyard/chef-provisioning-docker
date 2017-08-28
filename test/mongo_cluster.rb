1.upto(2) do |i|
  machine "cluster#{i}" do
    recipe "mongo_host"
  end
end
