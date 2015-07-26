#!/usr/local/tcl_test/bin/tclsh8.6
#����һ��������ʱ�ر�ss-server�Ľű�

proc kill_proc {kport} {
	global piddir
	if {[catch {exec cat ${piddir}/${kport}} kpid]} {puts "there is no that file"}
	if {[catch {exec ps -ef | grep  -e "-p $kport -k" | grep "ss-server" | awk {{print $2}}} realpid]} {
		puts "$realpid"			
		}
	if {$realpid != $kpid} {
		puts "realpid not equal kpid"
		set kpid $realpid
	}
	if {[catch {exec kill -9 $kpid}]} {puts "$kport kill process error"}
	if {[catch {exec rm -rf ${piddir}/${kport}} ]} {puts "rm file error"}
}

#�˴�killtask��foreachѭ�����Ż��ռ�
proc killtask {port_list} {
    global ctime
    puts "It's time to kill ss-server"
    puts "port_list is:$port_list"
    foreach kport $port_list {
        kill_proc $kport        
    }
    after 10000
    time_clock 
}

proc time_clock {} {
    global ctime
    set close_time  [clock scan "$ctime"]
    puts "close time is:$close_time"
    set seconds     [expr {$close_time - [clock seconds]}]
    puts "seconds is :$seconds"
    if {$seconds < 0 } {
        incr seconds 86400
    }
    after [expr {$seconds * 1000}]
    if {[catch {::gpd::get_ports} port_list]} {puts "ERROR:get port_list error";after 10000;time_clock}
    killtask $port_list
}


time_clock 