#!/usr/bin/tclsh
#geekproxy sqlite database control package

package require sqlite3
namespace eval ::gpd {
	global dbfile
	variable dbfile $dbfile
}

proc  ::gpd::create_db {} {
variable dbfile
sqlite3 gp $dbfile
gp eval {
	create table gp_info
	(
	uname varchar(255),
	passwd varchar(255),
	port int,
	method varchar(255),
	buy_date text,
	expir_date text,
	buy_flow varchar(255),
	used_flow varchar(255),
	tmp_flow varchar(255),
	primary key (uname)
	);
	create table send_info
	(
	uname varchar(255),
	port int,
	s_mail boolean,
	primary key (uname)
	);
}
gp close
}

proc  ::gpd::insert_user {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set insert_sql "insert into gp_info values ('[lindex $args 0]','[lindex $args 1]','[lindex $args 2]','[lindex $args 3]','[lindex $args 4]','[lindex $args 5]','[lindex $args 6]','0','0')"
	if {[catch {gp eval $insert_sql} error]} {return -code error "$error"}
	set insert_sql "insert into send_info values ('[lindex $args 0]','[lindex $args 2]','0')"
	if {[catch {gp eval $insert_sql} error]} {return -code error "$error"}
	gp cache flush
	gp close
	return -code ok
}

proc  ::gpd::update_user {{mod -c} args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[string equal $mod "-c"]} {
		set old_date "select expir_date from gp_info where uname='[lindex $args 0]'"
		if {[catch {gp eval $old_date} old_date]} {puts "get old expir date error;gp close;exit 1"}
		set new_expir [clock format [clock add [clock scan $old_date -format {%Y-%m-%d}] [lindex $args 1] month 1 day] -format {%Y-%m-%d}]
		puts "NEW EXPIR is:$new_expir"
		set update_sql "update gp_info set expir_date='${new_expir}' where uname='[lindex $args 0]'"
		if {[catch {gp eval $update_sql} error]} {gp close;return -code error}
	} else {
		set update_sql "update gp_info set [lindex $args 1]='[lindex $args 2]' where uname='[lindex $args 0]'"
		if {[catch {gp eval $update_sql} error]} {gp close;return -code error}
	}
	
	gp cache flush
	gp close
	return -code ok
}


proc  ::gpd::get_ports {{mod -e}} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[string equal $mod "-e"] } {
		puts "get ports info"
		if {[catch {gp eval {select port,expir_date,buy_flow,used_flow from gp_info}} p_info]} {puts "ERROR:get port info error,$p_info"}
		#if {[catch {gp eval {select port from gp_info}} ports_list]} {puts "ERROR:get port info error,$p_info"}
		puts "p_info is:$p_info"
		if {[llength $p_info] == 0} {
			puts "There is no port_list"
			return -code error "There is no ports_list info"
		} else {
			foreach {port expir_date buy_flow used_flow} $p_info {
				if {$buy_flow > $used_flow} {
					lappend t_info $port $expir_date
				}
			}
			#puts "t_info is:$t_info"
			if {![info exists t_info]} {
				puts "There is no port_list"
				return -code error "There is no ports_list info"
			}
		}
		puts "t_info :$t_info"
		foreach {t_port e_date} $t_info {
			if {[clock seconds] >= [clock scan $e_date -format {%Y-%m-%d}]} {
				puts "$t_port buy_date expired"
				continue
			} else {
				lappend ports_list $t_port
			}
		}		
	} elseif {[string equal $mod "-a"]} {
		if {[catch {gp eval {select port,buy_date,expir_date,used_flow from gp_info}} ports_list]} {puts "ERROR:get port info error,$p_info"}
		
	}
	
	puts "ports list is:$ports_list"
	gp close
	return $ports_list
}

proc  ::gpd::get_port {uname} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[string equal $uname "-a"]} {
		if {[catch {gp eval {select port from gp_info}} port]} {
			puts "get user port error"
			gp close
			return -code error
		}
	} else {
		set query "select port from gp_info where uname ='$uname'"
		if {[catch {gp eval $query} port]}  {puts "get user info error"}
	}
	gp close
	return $port
}

proc  ::gpd::get_flow {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[catch {gp eval {select port,used_flow from gp_info}} old_flow]} {gets "get flow error"}
	gp close 
	return $old_flow
}

proc  ::gpd::get_buyflow {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[catch {gp eval {select port,buy_flow from gp_info}} buy_flow]} {gets "get buy flow error"}
	gp close
	return $buy_flow
}

proc  ::gpd::get_tmpflow {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[catch {gp eval {select port,tmp_flow from gp_info }} tmp_flow]} {gets "get tmp flow error"}
	gp close
	return $tmp_flow
}


proc  ::gpd::flow_info {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set query "select port,buy_flow,used_flow from gp_info where port='[lindex $args 0]'"
	if {[catch {gp eval $query} info ]} {puts "get info error"}
	gp close
	return $info
}

proc  ::gpd::update_flow {{mod -u} args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[string equal $mod "-t"]} {
		puts "update [lindex $args 0] tmp flow"
		foreach {port flow} [lindex $args 0] {
			puts "update tmp flow:$port $flow"
			set up_tflow "update gp_info set tmp_flow='$flow' where port='$port'"
			if {[catch {gp eval $up_tflow} error]} {puts "update tflow error:$error";gp close;return -code error}
		}
		
	} elseif {[string equal $mod "-c"]} {
		puts "clean [lindex $args 0] used_flow and tmp_flow"
		set up_tflow "update gp_info set used_flow='0',tmp_flow='0' where port='[lindex $args 0]'"
		if {[catch {gp eval $up_tflow} error]} {puts "update tflow error:$error";gp close;return -code error}
	} else {
		puts "update [lindex $args 0] flow"
		foreach {port flow} [lindex $args 0] {
			puts "update flow :$port $flow"
			set update_flow "update gp_info set used_flow='$flow' where port='$port'"
			if {[catch {gp eval $update_flow} error]} {gp close;return -code error}
		}
		
	}
 	gp cache flush
	gp close
	return -code ok
}

proc  ::gpd::del_user {args} {
#delete flow overed user
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set delete_user "delete from gp_info where port='[lindex $args 0]'"
	if {[catch {gp eval $delete_user } error]} {puts "delete error";gp close ;return -code error}
	set delete_user "delete from send_info where port='[lindex $args 0]'"
        if {[catch {gp eval $delete_user } error]} {puts "delete error";gp close ;return -code error}
	gp cache flush
	gp close
	return -code ok
}

proc  ::gpd::start_info {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set s_info "select passwd,method from gp_info where port='[lindex $args 0]'"
	if {[catch {gp eval $s_info } t_info]} {puts "select error"}
	gp close
	return $t_info
	
}

proc  ::gpd::send_info {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set s_info "select uname,s_mail from send_info where port='[lindex $args 0]'"
	if {[catch {gp eval $s_info} s_info]} {puts "select error"}
	gp close
	return $s_info
}

proc  ::gpd::change_mail {args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	set s_info "update send_info set s_mail='[lindex $args 1]' where port='[lindex $args 0]'"
	if {[catch {gp eval $s_info} s_info]} {return -code error}
	gp close
	return -code ok
}

proc  ::gpd::user_info {mod args} {
	variable dbfile
	sqlite3 gp $dbfile
	gp timeout 2000
	if {[string equal $mod "-a"]} {
		set u_info "select uname,port,buy_flow,used_flow from gp_info where uname='[lindex $args 0]'"
		if {[catch {gp eval $u_info} u_info]} {puts "select error"}
	} else {
		set u_info "select uname,port,buy_date,expir_date,buy_flow,used_flow from gp_info"
		if {[catch {gp eval $u_info} u_info]} {puts "select error"}
	}
	gp close
	return $u_info	
}