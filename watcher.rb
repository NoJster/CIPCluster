#!/usr/bin/ruby -w
require "fileutils"

USERNAME = `whoami`.strip
HOSTNAME = `hostname`.strip
WORKDIR = "/proj/ciptmp/"+USERNAME+"/cluster/"+HOSTNAME+"/"
CONFIG = "/proj/ciptmp/"+USERNAME+"/cluster/"+HOSTNAME+"/config"
BINDIR = "/proj/ciptmp/"+USERNAME+"/cluster/bin/"
RUNNING = "running"
REDISTRIBUTE = "redistribute"
FINISHED = "finished"
FREE = "free"
STOP = "stop"
KILL = "kill"

@act_status = ""
@pid = 0;

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

def sleep_kill
	kill?
	sleep POLLINTERVAL
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
	STDERR.puts "... waiting for work"
	while(true)
		if File.exists? CONFIG		
			return parse_config
		end
		sleep_kill
	end
end


def start_work(program, state)
	@pid = fork do
		FileUtils.chdir WORKDIR
		exec(BINDIR+program, WORKDIR+state)
	end
	put_status RUNNING
end

def poll_for_interrupts
	STDERR.puts "... waiting for interrupts"
	while(true)
		if File.exists? WORKDIR + FINISHED
			@pid = 0
			put_status FINISHED
			break
		elsif File.exists? WORKDIR + STOP
			stop_child
			break
		end			
		sleep_kill
	end
end

def poll_for_free
	STDERR.puts "... waiting for free"
	while(true)
		break if File.exists? WORKDIR + FREE		
		sleep_kill
	end
end

def stop_child
	if @act_status == RUNNING && @pid != 0
		STDERR.puts "... stopping child"
		Process.kill("KILL", @pid)
		@pid = 0;
		put_status REDISTRIBUTE
	end
end

def kill?
	if File.exists? WORKDIR + KILL
		STDERR.puts "... going down"
		stop_child	
		File.delete WORKDIR + KILL
		STDERR.puts "kthnxbye"
		exit(0)
	end
end

#.....#

if __FILE__ == $0

check_workdir
put_status FREE


STDERR.puts "workdir: #{WORKDIR}"
STDERR.puts "bindir: #{BINDIR}"
STDERR.puts "config: #{CONFIG}"

while(true)
	poll_for_free
	program, state = poll_for_work
	start_work(program, state)
	poll_for_interrupts
end

end
