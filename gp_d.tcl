#!/usr/local/tcl_test/bin/tclsh8.6
#此脚本用来每天0：00判断包月是否过期
#|-------过期则删除帐号
#|-------未过期则判断是否需要初始化流量
#                 |-----------如果为新的月初，则初始化流量（使用流量）


proc time_clock {} {
    set close_time  [clock scan "00:00"]
    puts "expir_Date check time is:$close_time"
    set seconds     [expr {$close_time - [clock seconds]}]
    puts "seconds is :$seconds"
    if {$seconds < 0 } {
        incr seconds 86400
    }
    after [expr {$seconds * 1000}]
    check_task
}

proc check_task {} {
    global send_mail
    if {[catch {::gpd::get_ports -a} ports_list]} {puts "ERROR:gp_d get ports_list:${ports_list}";after 10000;check_task}
    set now_Date_Sec 		[clock seconds]
    set warn_Date               [clock add $now_Date_Sec 2 days ]
    set current_Year            [clock format $now_Date_Sec -format {%Y}]
    set current_Month           [clock format $now_Date_Sec -format {%m}]
    set current_Day            [clock format $now_Date_Sec -format {%d}]
    foreach {port buy_Date expir_Date used_flow} $ports_list {
        puts "port info:$port $buy_Date $expir_Date $used_flow"
        regexp {([0-9]*)-([0-9]*)-([0-9]*)} $buy_Date match year month day
        set incr_month [expr {($current_Year - $year) * 12 + ($current_Month - $month)}]
	if {$incr_month>0} {
	    #已满一个月
	    #判断过期时间是否为2天后，是则发送提醒邮件
	    set expir_Date_Sec [clock scan $expir_Date -format {%Y-%m-%d}]
	    set buy_Date_Sec [clock scan $buy_Date -format {%Y-%m-%d}]
	    if {$warn_Date == [clock scan $expir_Date -format {%Y-%m-%d}]} {
		puts "send expir e_mail to $port"
		if {$send_mail == 1} {
                    warn_mail $port
                }
	    } elseif {[clock add $buy_Date_Sec $incr_month months 1 day] == $now_Date_Sec ]} {
		#新月
		if {$expir_Date_Sec > $now_Date_Sec} {
		    #未过期，则更新流量
		    puts "set $port used_flow to 0"
		    if {$send_mail == 1} {
		        ::gpd::change_mail $port 0
		    }
		    if {[catch {exec iptables -L OUTPUT --line-numbers | grep "spt" | grep ${port} | awk {{print $1}} } line]} {puts "GET ${port} line error"}
		    puts "Line is :$line"
		    if {[catch {exec iptables -Z OUTPUT $line } e]} {puts "clean $e"}
		    ::gpd::update_flow -c $port
		} else {
		    #过期帐号
		    puts "expired date $port"
		    if {$send_mail == 1} {expir_mail $port}
		    delete_expir_user $port
		}
	    }
            
	}        
    }
    after 10000
    time_clock
}

proc delete_expir_user {kport} {
	global piddir
        if {[file exists ${piddir}/${kport}]} {
            puts "${piddir}/${kport} file exists"
            if {[catch {exec cat ${piddir}/${kport}} kpid]} {puts "ERROR:cat ${kport} file error,${kpid}"}
            if {[catch {exec kill -9 $kpid}]} {puts "ERROR:kill ${kpid} process error,$kpid"}
            if {[catch {file delete  $piddir/${kport}}]} {puts "delete error"}
        } else {
            puts "${piddir}/${kport} file not exists"
            puts "$kport service has been killed"
        }
        if {[catch {exec iptables -D OUTPUT -p tcp --sport $kport -j ACCEPT} e]} {puts "DELETE IPTABLES ERROR:$e"}
        if {[catch {exec service iptables save}]} {puts "iptables save error";return -code error}
        ::gpd::del_user $kport
}

proc warn_mail {port} {
	if {[catch {u_info $port} user_info]} {puts "get send mail info error:$user_info"}
	if {[catch {exec echo "这是一封来自Geekproxy的续费提醒邮件，您的帐号将在2天后自动关闭，请及时续费。" | mutt -s "GeekProxy续费提醒" $user_info} error]} {puts "sent mail error:$error"}
}

proc expir_mail {port} {
	if {[catch {u_info $port} user_info]} {puts "get send mail info error:$user_info"}
	if {[catch {exec echo "您的geekproxy包月帐号已过期并自动删除，如有疑问，可环聊联系！" | mutt -s "GeekProxy帐号关闭" $user_info} error]} {puts "sent mail error:$error"}
}

time_clock
