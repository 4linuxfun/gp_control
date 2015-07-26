#!/usr/bin/tclsh
#This is a geekproxy script for create user and add flow

set dir "[file dirname [info script]]"
if {![file exists [file join "$dir" "gp.conf"]]} {puts "There is no gp.conf"}

#read configure
set gp_f 	[open [file join "$dir" "gp.conf"] r]
set conf 	[split [read $gp_f] "\n"]
close $gp_f
foreach info $conf {
	if {[regexp "^\[^#\]" $info]} {
		set info_v [split $info "="]
		switch [lindex $info_v 0] {
			ss_dns	 	{set ss_dns 	[lindex $info_v 1]}
			send_mail	{set send_mail 	[lindex $info_v 1]}
			piddir		{set piddir 	[lindex $info_v 1]}
			db_file		{set dbfile 	[lindex $info_v 1]}
			m_flow		{set buy_flow	[lindex $info_v 1]}
			d_method	{set method     [lindex $info_v 1]}
			ss_server	{set ss_server 	[lindex $info_v 1]}
			ss_port 	{set ss_port    [lindex $info_v 1]}
		}
	}
}

source "$dir/db_control.tcl"
if {![info exists ss_server]} {puts "NOT SPECIFIED ss-server file"
	set ss_server	[exec find / -name ss-server]
	if {$ss_server eq ""} {puts "ERROR:Can't find ss-server program";exit 1}
}
if {![file exists $piddir]} {file mkdir $piddir}
if {![file exists "${dbfile}"]} {::gpd::create_db}


proc create_server {passwd port method} {
	global ss_server piddir
	if {[catch {exec iptables -A OUTPUT -p tcp --sport $port -j ACCEPT} error]} {
		puts "iptables add error:$error"
		return -code error
		}
	if {[catch {exec iptables -L -vn | grep -i "spt:$port" }]} {puts "iptables not added";return -code error}
	if {[catch {exec service iptables save}]} {puts "iptables save error";return -code error}
	if {[catch {exec $ss_server -u -s 0.0.0.0 -p $port -k $passwd -m $method -t 10 -f $piddir/$port } error]} {
		puts "create server $error"
		return -code error
	}
	puts "ss-server start ok"
	return -code ok
}

proc send_mail {mode uname buy_flow args} {
	global ss_dns method
	set u_info [::gpd::user_info -a $uname]
	switch $mode {
		-a {
			set header "Geekproxy购买成功"
			set port   "[lindex $args 0]"
			set passwd "[lindex $args 1]"
			set method "[lindex $args 2]"
			set buy_info "<p>Hello，<br>这是一封来自GeekProxy的帐号开通提醒，您的ss帐号已开通，相关信息如下：</p>
				\<li\>购买流量[expr {${buy_flow}/1000000000}]G，可用流量为[expr {double([lindex $u_info 2] - [lindex $u_info 3])/1000000000}]G \
				\<li\>服务器IP:&quot;\<strong\>$ss_dns\</strong\>&quot;\</li\> \
				\<li\>服务器端口:\<strong\>${port}\</strong\>\</li\> \
				\<li\>加密方式：\<strong\>$method\</strong\>\</li\> \
				\<li\>密码:\<strong\>$passwd\</strong\>\</li\> \
				\<strong\>当流量少于500M的时候会发送邮件通知，为了能及时收到提醒邮件，请把geekproxy.net@gmail.com加入可信列表，防止被当作垃圾邮件处理！\</strong\>"
				
		}
		-c {
			set header "Geekproxy续费成功"
			set buy_info "您已成功购买[expr {${buy_flow}/1000000000}]G流量，可用流量为[expr {double([lindex $u_info 2] - [lindex $u_info 3])/1000000000}]G，当流量少于500M的时候会发送邮件通知！"}
	}
	if {[catch {exec  mutt  -e "set content_type=text/html" -s "$header" $uname << ${buy_info}}  error]} {puts "error:$error"}
	set t_mail 0
	set port [lindex $u_info 1]
        if {[catch {::gpd::change_mail $port $t_mail}]} {puts "change mail info error";exit 1}

}

proc kill_proc {kport} {
	global piddir
	if {[catch {exec cat ${piddir}/${kport}} kpid]} {puts "ERROR:cat ${kport} file error,${kpid}"}
	if {[catch {exec kill -9 $kpid}]} {puts "ERROR:kill ${kpid} process error,$kpid"}
	if {[catch {file delete  $piddir/${kport}}]} {puts "delete error"}
	if {[catch {exec iptables -D OUTPUT -p tcp --sport $kport -j ACCEPT} e]} {puts "DELETE IPTABLES ERROR:$e"}
    if {[catch {exec service iptables save}]} {puts "iptables save error";return -code error}
	::gpd::del_user $kport
}

proc rndpassword {len} {
 set s "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789"
 for {set i 0} {$i <= $len} {incr i} {
    append p [string index $s [expr {int([string length $s]*rand())}]]
 }
 return $p
}

proc get_unused_port {} {
	global ss_port
	set port_list 	[::gpd::get_port -a]
	foreach t_port $port_list {
		set p_used($t_port) 1
	}
	for {set i [lindex $ss_port 0]} {$i <= [lindex $ss_port 1]} {incr i} {
		if {![info exists p_used($i)]} {
			puts "port $i not used"
			break
		}
	}
	return $i
}
proc main {argv} {
	global buy_flow method send_mail ss_port
	set ss_port [split $ss_port "-"]
	switch [lindex $argv 0] {
	-a {
		puts "create a new user"
		set user_name 	[lindex $argv 1]
		set passwd 	[lindex $argv 2]
		if {[string equal $passwd "-r"]} {
			set passwd [rndpassword 6]
		}
		#set port	[lindex $argv 3]
		
		set port [get_unused_port]
		if { [llength $argv] < 5 } {
		set buy_month   [lindex $argv 3]

		} else {
		set method	[lindex $argv 3]
		set buy_month   [lindex $argv 4]
		}
		set buy_flow 	[expr {$buy_flow * 1000000000}]
		set buy_date [clock format [clock seconds] -format {%Y-%m-%d}]
		set expir_date [clock format [clock add [clock seconds] $buy_month month 1 day] -format {%Y-%m-%d}]
		puts "insert info is:$user_name $passwd $port $method $buy_date $expir_date $buy_flow"
		if {[catch {::gpd::insert_user  $user_name $passwd $port $method $buy_date $expir_date $buy_flow } e]} {
			puts "insert error:$e"
			exit 1
		}
		if {[catch {create_server $passwd $port $method}]} {
			puts "create server error"
			::gpd::del_user $port
			exit 1
		}
		
		if {$send_mail == 1} {
		send_mail -a $user_name $buy_flow $port $passwd $method
		}
		puts "[format "+-[string repeat - 11]-+-[string repeat - 20]-+"]"
		puts "[format "| %-*s | %-*s |" "11" "user_name:" "20" $user_name]"
		puts "[format "| %-*s | %-*s |" "11" "port:" "20" $port]"
		puts "[format "| %-*s | %-*s |" "11" "password:" "20" $passwd]"
		puts "[format "| %-*s | %-*s |" "11" "method:" "20" $method]"
		puts "[format "| %-*s | %-*s |" "11" "expir_date:" "20" $expir_date]"
		puts "[format "+-[string repeat - 11]-+-[string repeat - 20]-+"]"
	}
	-t {
		puts "Create a test user"
		set user_name [lindex $argv 1]
		set passwd [rndpassword 5]
		set port [get_unused_port]
		set buy_date [clock format [clock seconds] -format {%Y-%m-%d}]
		set expir_date [clock format [clock add [clock seconds] 2 day] -format {%Y-%m-%d}]
		set buy_flow [expr {2*1000000000}]
		if {[catch {::gpd::insert_user  $user_name $passwd $port $method $buy_date $expir_date $buy_flow } e]} {
			puts "insert error:$e"
			exit 1
		}
		if {$send_mail == 1} {
		send_mail -a $user_name $buy_flow $port $passwd $method
		}
	}
	-c {
		puts "buy more months"
		set user_name	[lindex $argv 1]
		set buy_month	[lindex $argv 2]
		if {[catch {::gpd::update_user -c $user_name $buy_month}]} {puts "update error";exit 1}
		if {$send_mail == 1} {
			puts "sending $user_name mail"	
			send_mail -c $user_name $buy_flow
		}
	}
	-u {
		puts "update user info"
		set u_name [lindex $argv 1]
		set change [lindex $argv 3]
		switch [lindex $::argv 2] {
		    -P {set mod		"passwd"}
		    -p {set mod		"port"}
		    -m {set mod 	"method"}
		    default {
			puts "./gp_c.tcl -u email_addr \[-P Passwd\] \[-p port\] \[-m method\]"
			exit 1
			}
		}
		kill_proc [::gpd::get_port $u_name]
		::gpd::update_user -u $u_name $mod $change
	}
	-l {
		puts "+-[string repeat - 20]-+-[string repeat - 5]-+-[string repeat - 10]-+-[string repeat - 10]-+-[string repeat - 11]-+-[string repeat - 12]-+-[string repeat - 12]-+"
		set u_info [::gpd::user_info -l]
		puts "[format "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |" \
					"20" "user_name" \
					"5" "port" \
					"10" "buy_date" \
					"10" "expir_date" \
					"11" "buy_flow(G)" \
					"12" "used_flow(G)" \
					"12" "left_flow(G)"]"
		puts "+-[string repeat - 20]-+-[string repeat - 5]-+-[string repeat - 10]-+-[string repeat - 10]-+-[string repeat - 11]-+-[string repeat - 12]-+-[string repeat - 12]-+"
		set u_num 0
		set all_flow 0
		set all_uflow 0
		set all_lflow 0
		foreach {u_name port buy_date expir_date buy_flow used_flow} $u_info {
			set buy_flow [expr {double(${buy_flow})/1000000000}]
			set used_flow [expr {double(${used_flow})/1000000000}]
			set left_flow [expr {${buy_flow} - ${used_flow}}]
			puts "[format "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*.4f | %-*s |" \
						"20" $u_name \
						"5" $port \
						"10" $buy_date \
						"10" $expir_date \
						"11" $buy_flow \
						"12" $used_flow \
						"12" [format "%.3f" ${left_flow}]]"
			incr u_num
			set all_flow [expr {$buy_flow+$all_flow}]
			set all_uflow [expr {$used_flow + $all_uflow}]
			set all_lflow [expr {$left_flow + $all_lflow}]
		}

		puts "+-[string repeat - 20]-+-[string repeat - 5]-+-[string repeat - 10]-+-[string repeat - 10]-+-[string repeat - 11]-+-[string repeat - 12]-+-[string repeat - 12]-+"
		puts "[format "| %-*s | %-*s | %-*s | %-*s |" \
				"17" "U_COUNTS:${u_num}" \
				"27" "BUY_COUNTS:${all_flow}G" \
				"21" "USED_COUNTS:[format "%.3f" ${all_uflow}]G" \
				"24" "LEFT_COUNTS:[format "%.3f" ${all_lflow}]G"] "
		puts "+-[string repeat - 17]-+-[string repeat - 27]-+-[string repeat - 21]-+-[string repeat - 24]-+"
	}
	-d {
		set u_name [lindex $argv 1]
		if {[catch {::gpd::get_port $u_name} port]} {puts "GET PORT ERROR";exit 1}
		kill_proc $port
		puts "$u_name has been delete successfully."
	}
	default {
		puts "+-[string repeat - 55]-+"
		puts "+-[string repeat - 18]Argument error[string repeat - 23]-+"
		puts "+-[string repeat - 55]-+"
		puts ""
		puts "+-[string repeat - 18]Create a new user[string repeat - 20]-+"
		puts "[format "%-*s %-*s %-*s %-*s %-*s %-*s" "10" "./gp_c.tcl" \
			"2" "-a" "10" "email_addr" "10" "passwd" "11" "\[method\]" "11" "buy_month"]"
		puts ""
		puts "+-[string repeat - 18]Create a test user[string repeat - 19]-+"
		puts "[format "%-*s %-*s %-*s " "10" "./gp_c.tcl" \
			"2" "-t" "10" "email_addr" ]"
		puts ""	
		puts "+-[string repeat - 18]Buy more month[string repeat - 23]-+"
		puts "[format "%-*s %-*s %-*s %-*s " "10" "./gp_c.tcl" \
			"2" "-c" "10" "email_addr" "10" "buy_month"]"
		puts ""
		puts "+-[string repeat - 18]Change ss info[string repeat - 23]-+"
		puts "[format "%-*s %-*s %-*s %-*s %-*s %-*s" "10" "./gp_c.tcl" \
			"2" "-a" "10" "email_addr" "11" "\[-P Passwd\]" "10" "\[-p port\]" "11" "\[-m method\]"]"
		puts ""
		puts "+-[string repeat - 18]Delete a user[string repeat - 24]-+"
		puts "[format "%-*s %-*s %-*s" "10" "./gp_c.tcl" \
			"2" "-d" "10" "email_addr"]"
		puts ""
		puts "+-[string repeat - 18]List all user info[string repeat - 19]-+"
		puts "[format "%-*s %-*s" "10" "./gp_c.tcl" \
			"2" "-l"]"
	}
	}
} 
main $argv
