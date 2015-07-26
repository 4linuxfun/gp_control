#!/usr/local/tcl_test/bin/tclsh8.6
#This script is used to moniter ss-server processes

proc start_server {ss_server piddir port passwd method} {
        #global ss_server piddir
        if {[catch {exec $ss_server -u -s 0.0.0.0 -p $port -k $passwd -m $method -t 60 -f $piddir/$port } error]} {puts "
create server $error";return -code error}
        puts "$port ss-server start ok"
        return -code ok
}


while 1 {
	if {[catch {::gpd::get_ports} port_list]} {after 10000;continue}
	puts "useful port list is:$port_list"
	foreach port $port_list {
		if {![file exists $piddir/$port]} {
			puts "$port file not exists"
			set p_info [::gpd::start_info $port]
			if {[catch {start_server $ss_server $piddir $port [lindex $p_info 0] [lindex $p_info 1]} e]} {puts "start ss error";continue}
		} else {
			if {[catch {exec ps -ef | grep -e "-p $port -k" | grep "ss-server" | awk {{print $2}}} realpid]} {
				puts "realpid error:$realpid"
				set p_info [::gpd::start_info $port]
				if {[catch {start_server $ss_server $piddir $port [lindex $p_info 0] [lindex $p_info 1]} e]} {puts "$e"}
			}
			if {[catch {exec cat ${piddir}/${port}} kpid]} {puts "there is no that file"}
			if {$realpid != $kpid} {
				puts "$port:$realpid not equal $kpid"
				if {[catch {exec sed -i s/$kpid/$realpid/g ${piddir}/${port}} e]} {puts "$e"}
			}
			}
		}
	after 300000
}	
		

