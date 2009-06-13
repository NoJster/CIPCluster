require 'timeout'
require 'fileutils'

MY_USER = `whoami`.strip!
FIND_IDLES_CMD = 'rusers -a' 
CLUSTER_DIR = "/proj/ciptmp/#{MY_USER}/cluster/"
RUN_WATCHER_CMD = "bin/watcher.rb"
TIMEOUT = 5

class CIPClusterMaster
	def get_idles( test )
		unless test
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
		else
			return [ "faui02o", "faui02n", "faui02m" ]
		end
	end

	def get_hosts
		ret_val = []

		begin
			timeout( TIMEOUT ) do
				my_p = IO.popen( FIND_IDLES_CMD )

				while my_host_info = my_p.readline
					my_host = my_host_info.split( " " )[ 0 ].split( "." )[ 0 ]

					ret_val += [ my_host ]
				end
			end
		rescue Timeout::Error
		end

		return ret_val
	end

	def get_running_nodes( nodes )
		ret_val = []
	
		nodes.each do |node|
				if get_state( node ) == "running"
					ret_val += [ node ]
				end
		end

		return ret_val										 
	end

	def get_state( node )
		my_free_file = CLUSTER_DIR + "#{node}/free"
		my_running_file = CLUSTER_DIR + "#{node}/running"
		my_redist_file = CLUSTER_DIR + "#{node}/redistribute"
		if File.exist?( my_free_file )
			return "free"
		elsif File.exist?( my_running_file )
			return "running"
		elsif File.exist?( my_redist_file )
			return "redistribute"
		else
			return "not initialized"
		end

	end

	def kill_watcher( nodes )
		nodes.each do |n|
			fork {
				exec "ssh", "#{n}", "killall csh"	
			}
			fork {
				exec "ssh", "#{n}", "killall /usr/bin/ruby"	
			}
		end
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

	#
	# available signal are:
	# - stop: tells the watcher to stop his child
	# - kill: tells the watcher to terminate itself
	#
	def send_signal( nodes, signal )
		nodes.each do |node|
			FileUtils.touch "#{CLUSTER_DIR}#{node}/#{signal}"	
		end
	end
end

class CIPClusterControl

	def initialize
		@my_master = CIPClusterMaster.new
		@my_nodez = []
		@my_nodez = []
	end

	def show_menu
		my_option = -1

		begin
			puts "***************************************"
			puts "* CIPCluster Control                  *"
			puts "***************************************"
			puts "* Available options:                  *"
			puts "* [1] Renew list of idle nodes        *"
			puts "* [2] Show current list of idle nodes *"
			puts "* [3] Start watcher on idle nodes     *"
			puts "* [4] Show states of nodes            *"
			puts "* [5] Stop work on nodes              *"
			puts "* [6] Terminate watchers              *"
			puts "* [7] Exit                            *"
			puts "***************************************"
			print "Please enter option: "	
			my_option = STDIN.readline.to_i
		end while my_option < 1 || my_option > 7

		case my_option
		when 1
			@my_nodez = @my_master.get_idles( true )
		when 2
			print_idles
		when 3
			@my_master.start_watcher( @my_nodez )
		when 4
			print_states
		when 5
			@my_master.send_signal( @my_nodez, "stop" )
		when 6
			@my_master.send_signal( @my_nodez, "kill" )
		when 7
			@my_master.send_signal( @my_nodez, "kill" )
			exit 0
		end
	end


	def print_idles
		@my_nodez.each do |idle|
			puts idle
		end
	end

	def print_states
		@my_nodez.each do |idle|
			my_state = @my_master.get_state( idle )
			puts "#{idle}: #{my_state}"
		end
	end
end
