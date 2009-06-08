require 'timeout'

class CIPClusterMaster
	MY_USER = `whoami`.strip!
	FIND_IDLES_CMD = 'rusers -a' 
	CLUSTER_DIR = "/proj/ciptmp/#{MY_USER}/cluster/"
	RUN_WATCHER_CMD = "bin/watcher.rb"
	TIMEOUT = 5

	def get_idles
			ret_val = []
		
		begin
			timeout( TIMEOUT ) do
				my_p = IO.popen( FIND_IDLES_CMD )	

				while my_host_info = my_p.readline
					#
					# we only want idle hosts and only the short name of those
					#
					my_users = my_host_info.split( " " )
					my_host = my_users.slice!( 0 ).split( "." )[ 0 ]

					if my_host.include? "faui"
						#
						# caveat: beware that rusers shows one user per shell
						#
						if( ( my_users.length == 1 and my_users[ 0 ] == MY_USER ) or my_users.length == 0 )
								ret_val +=  [ my_host ]
						end
					end
				end
			end
		rescue Timeout::Error
			#
			# just catch the timeout and pretend that everything is fine ...
			#
		end
		
		return ret_val
	end


	#
	# returns a list of idles to which a user has logged in since last checking,
	# to signal that this node has to be terminated
	#
	def get_removed_idles( list_of_idles )
		ret_val = []

		current_idles = get_idles

		list_of_idles.each do |old_idle|
			unless current_idles.include? old_idle
				ret_val += [ old_idle ]
			end
		end

		return ret_val
	end

	def get_added_idles( list_of_idles )
		ret_val = []

		current_idles = get_idles

		current_idles.each do |current_idle|
			unless list_of_idles.include? current_idle
				ret_val += [ current_idle ]
			end
		end

		return ret_val
	end

	def start_watcher( list_of_idles )
		list_of_idles.each do |idle|
			fork {
				exec "ssh", "#{idle}", "#{CLUSTER_DIR}#{RUN_WATCHER_CMD}"
			}
		end	
	end

	def send_stop( node )
		exec "ssh", "#{node}", "touch #{CLUSTER_DIR}#{node}/stop"	
	end
end

