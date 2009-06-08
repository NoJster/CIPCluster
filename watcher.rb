#!/usr/bin/ruby -w
require "fileutils"

USERNAME = `whoami`.strip
HOSTNAME = `hostname`.strip
WORKDIR = "/proj/ciptmp/"+USERNAME+"/cluster/"+HOSTNAME+"/"
CONFIG = "/proj/ciptmp/"+USERNAME+"/cluster/"+HOSTNAME+"/config"
BINDIR = "/proj/ciptmp/"+USERNAME+"/cluster/bin/"
RUNNING = "running"
REDISTRIBUTE = "redistribute"
FREE = "free"
STOP = "stop"

@act_status = ""

POLLINTERVAL = 0.5



def check_workdir()
	FileUtils.mkdir(WORKDIR) unless File.exists?(WORKDIR)
end

def put_status(status) 
	return if(status == @act_status)
	@act_status = status
	File.delete(WORKDIR+RUNNING) if File.exists?(WORKDIR+RUNNING)
	File.delete(WORKDIR+FREE) if File.exists?(WORKDIR+FREE)
	File.delete(WORKDIR+REDISTRIBUTE) if File.exists?(WORKDIR+REDISTRIBUTE)
	FileUtils.touch(WORKDIR+status)
end


def parse_config
	program = ""
	state = ""
	File.readlines(CONFIG).each { |line|
		line = line.strip
		arg = line.split("=")[1]
		program = arg if line =~ /^exec=/
		state = arg if line =~ /^state=/
	}
	return program,state
	
end


def poll_for_work
	while(true)
		if File.exists? CONFIG		
			return parse_config
		end
		sleep POLLINTERVAL
	end
end


def start_work(program, state)
	pid = fork
	if(pid)
		put_status RUNNING
		return pid
	end
	exec(BINDIR+program, WORKDIR+state)
end

#.....#

if __FILE__ == $0

check_workdir
put_status FREE


program, state = poll_for_work
child_pid = start_work(program, state)


puts child_pid

end
