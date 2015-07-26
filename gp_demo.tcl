#!/usr/local/tcl_test/bin/tclsh8.6
#This script is used to moniter ss-server processes
#and auto kill ss-server processes in time
#一个线程监控端口、一个线程定时关闭服务（关闭后监控线程监控到口重启）
package require Thread

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
			send_mail	{set send_mail 	[lindex $info_v 1]}
			piddir		{set piddir 	[lindex $info_v 1]}
			db_file		{set dbfile 	[lindex $info_v 1]}
			c_time		{set c_time	[lindex $info_v 1]}
			u_time		{set u_time	[lindex $info_v 1]}
			ss_server	{set ss_server 	[lindex $info_v 1]}
		}
	}
}
if {![file exists [file join "$dir" "$dbfile"]]} {
	puts "dbfile not exists"
	source "$dir/db_control.tcl"
	::gpd::create_db
	}
if {![file exists $piddir]} {file mkdir $piddir}
if {![info exists ss_server]} {
	puts "Not specified ss_server"
	set ss_server	[exec find / -name ss-server]
	if {$ss_server eq ""} {puts "ERROR:Can't find ss-server program";exit 1}
}

tsv::array set gp_info [list {dir} "$dir" \
			{piddir} "$piddir" \
			{ss_server} "$ss_server" \
			{send_mail} "$send_mail" \
			{dbfile} "$dbfile" \
			{ctime} "$c_time" \
			{u_time} "$u_time"]
#创建定时关闭进程服务
set gp_kill_proc [thread::create {
	foreach {name value} [tsv::array get gp_info] {
		set $name $value
	}
	puts "close time is:$ctime"
	source "$dir/db_control.tcl"
	source "$dir/gp_k.tcl"
	}]

#创建监控线程	
set gp_proc_monitor [thread::create {
	foreach {name value} [tsv::array get gp_info] {
		set $name $value
	}
	source "$dir/db_control.tcl"
	source "$dir/gp_m.tcl"
	}]
	
#创建流量更新线程
set gp_flow_update [thread::create {
	foreach {name value} [tsv::array get gp_info] {
		set $name $value
	}
	set wtime [expr {$u_time * 1000}]
	puts "wtime is:$wtime"
	source "$dir/db_control.tcl"
	source "$dir/gp_u.tcl"
	}]

#创建月刷新线程
set gp_expir_monitor [thread::create {
	foreach {name value} [tsv::array get gp_info] {
		set $name $value
	}
	source "$dir/db_control.tcl"
	source "$dir/gp_d.tcl"
}]

#主进程进入循环中
vwait forever
