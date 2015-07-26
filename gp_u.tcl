#!/usr/local/tcl_test/bin/tclsh8.6

proc close_mail {port} {
	if {[catch {::gpd::send_info $port} user_info]} {puts "get send mail info error"}
	if {[catch {exec echo "您的shadowsocks月流量已用完，并自动关闭！如需购买，可环聊或回复邮件！" | mutt -s "GeekProxy关闭通知" [lindex $user_info 0]} error]} {puts "close mail error:$error"}
}

proc kill_proc {kport} {
	global piddir
	if {[catch {exec cat ${piddir}/${kport}} kpid]} {puts "ERROR:cat ${kport} file error,${kpid}"}
	if {[catch {exec kill -9 $kpid}]} {puts "ERROR:kill ${kpid} process error,$kpid"}
	if {[catch {file delete  $piddir/${kport}}]} {puts "delete error"}	
}


proc send_mail {port} {
	if {[catch {::gpd::send_info $port} user_info]} {puts "get send mail info error"}
	if {[lindex $user_info 1] == 0} {
		puts "havent send mail"
		if {[catch {exec echo "这是一封来自Geekproxy的流量提醒邮件，您的流量已不足500M，请尽快购买流量，不然会在流量用完后自动删除帐号信息。" | mutt -s "GeekProxy续费提醒" [lindex $user_info 0]} error]} {puts "sent mail error:$error"}
		set t_mail 1
		if {[catch {change_mail $port $t_mail}]} {puts "change mail info error";exit 1}
		 
	}
}

proc get_port_flow_list {port_info} {
	set iptables_port_flow ""
	set port_info [regexp -all -inline {\S+} $port_info ]
	set port_info [split $port_info " :"]
	for {set i 0} {$i<[llength $port_info]} {incr i 12} {
        	set iptables_port_flow [lappend iptables_port_flow [lindex $port_info [expr {$i + 11}]] [lindex $port_info [expr {$i + 1}]]]
	}
	puts "return port flow:$iptables_port_flow"
	return $iptables_port_flow
}

proc main {} {
	global wtime send_mail
	while 1 {
		if {[catch {::gpd::get_ports} port_list]} {puts "ERROR:get port_list error:$port_list";after ${wtime};continue}
		if {[llength $port_list] == 0} {after $wtime;continue}
		set port_list [join $port_list "|"]
		
		#puts "port list is$port_list"
		if {[catch {exec iptables -L OUTPUT -vnx | grep -v "bytes" | grep "spt" | grep -E "$port_list" } port_info]} {puts "ERROR:$port_info";after $wtime;continue}
	
		set iptables_port_flow [get_port_flow_list "$port_info"]
		puts "iptables_port_flow:$iptables_port_flow"
		if {[catch {dict keys $iptables_port_flow} error]} {puts "get iptables_port_flow error:$error";after $wtime;continue}
		#已使用流量#购买流量#临时流量
		set used_flow_list [::gpd::get_flow ] 
		set buy_flow_list [::gpd::get_buyflow]	
		set tmp_flow_list [::gpd::get_tmpflow]	
	
		foreach t_port [dict keys $iptables_port_flow] {
			set iptables_flow [dict get $iptables_port_flow $t_port]
			set used_flow  [dict get $used_flow_list $t_port]
			set buy_flow [dict get $buy_flow_list $t_port]
			set tmp_flow [dict get $tmp_flow_list $t_port]
			#判断iptables_flow的模式，是否重启过iptables
			puts "$iptables_flow $used_flow $buy_flow $tmp_flow"
			if { $iptables_flow < $used_flow } {
				puts "IPTABLES has been restarted"
				if { $iptables_flow < $tmp_flow} {
					set new_used_flow [expr {$iptables_flow + $used_flow}]
					lappend t_flow $t_port $iptables_flow
	
				} elseif {$iptables_flow > $tmp_flow } {
					set new_used_flow [expr {$iptables_flow - $tmp_flow + $used_flow}]
					lappend t_flow $t_port $iptables_flow
				} else {
					continue
				}
				#new_used_flow表示新的使用流量
				set iptables_flow $new_used_flow
				
			} elseif {$iptables_flow == $used_flow } {
				continue
			} else {
				puts "$t_port now is grater than db"
			}
			
			puts "port:$t_port u_flow:$iptables_flow"
			if {$iptables_flow >= $buy_flow} {
				puts "$t_port flow overd kill"
				kill_proc $t_port
				if {$send_mail == 1} {close_mail $t_port}
			} elseif {[expr {$buy_flow - $iptables_flow}] < 500000000 } {
				if {$send_mail == 1} {
					if {[catch {send_mail $t_port}]} {after $wtime;continue}
				}	
			} 
			lappend u_flow $t_port $iptables_flow		
		}
		if {[info exists t_flow]} {
			puts "t_filw is:$t_flow"
			if {[catch {::gpd::update_flow -t $t_flow} e]} {after $wtime;continue}
			unset t_flow
		}
		if {[info exists u_flow]} {
			puts "u_flow is:$u_flow"
			if {[catch {::gpd::update_flow -u $u_flow} e]} {after $wtime;continue}
			unset  u_flow
		}
				
		after $wtime
	}
}
main 