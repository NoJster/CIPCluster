require './lib/CIPCluster.rb'

c = CIPClusterMaster.new
my_idles = c.get_idles
puts "---"
#puts c.bla 
c.start_watcher( my_idles )

while
	#sleep 10
	my_removed_nodes = c.get_removed_idles( my_idles )
	puts "---"
	puts my_removed_nodes
	my_removed_nodes.each do |rm|
		c.send_stop( rm )
	end
end
=begin
sleep 2
removed_idles = c.get_removed_idles( my_idles )
puts removed_idles
sleep 3
puts "---"
added_idles = c.get_added_idles( my_idles )
puts added_idles
=end
