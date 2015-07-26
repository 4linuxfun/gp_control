#!/usr/local/tcl_test/bin/tclsh8.6
#�˽ű�����ÿ��0��00�жϰ����Ƿ����
#|-------������ɾ���ʺ�
#|-------δ�������ж��Ƿ���Ҫ��ʼ������
#                 |-----------���Ϊ�µ��³������ʼ��������ʹ��������


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
	    #����һ����
	    #�жϹ���ʱ���Ƿ�Ϊ2��������������ʼ�
	    set expir_Date_Sec [clock scan $expir_Date -format {%Y-%m-%d}]
	    set buy_Date_Sec [clock scan $buy_Date -format {%Y-%m-%d}]
	    if {$warn_Date == [clock scan $expir_Date -format {%Y-%m-%d}]} {
		puts "send expir e_mail to $port"
		if {$send_mail == 1} {
                    warn_mail $port
                }
	    } elseif {[clock add $buy_Date_Sec $incr_month months 1 day] == $now_Date_Sec ]} {
		#����
		if {$expir_Date_Sec > $now_Date_Sec} {
		    #δ���ڣ����������
		    puts "set $port used_flow to 0"
		    if {$send_mail == 1} {
		        ::gpd::change_mail $port 0
		    }
		    if {[catch {exec iptables -L OUTPUT --line-numbers | grep "spt" | grep ${port} | awk {{print $1}} } line]} {puts "GET ${port} line error"}
		    puts "Line is :$line"
		    if {[catch {exec iptables -Z OUTPUT $line } e]} {puts "clean $e"}
		    ::gpd::update_flow -c $port
		} else {
		    #�����ʺ�
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
	if {[catch {exec echo "����һ������Geekproxy�����������ʼ��������ʺŽ���2����Զ��رգ��뼰ʱ���ѡ�" | mutt -s "GeekProxy��������" $user_info} error]} {puts "sent mail error:$error"}
}

proc expir_mail {port} {
	if {[catch {u_info $port} user_info]} {puts "get send mail info error:$user_info"}
	if {[catch {exec echo "����geekproxy�����ʺ��ѹ��ڲ��Զ�ɾ�����������ʣ��ɻ�����ϵ��" | mutt -s "GeekProxy�ʺŹر�" $user_info} error]} {puts "sent mail error:$error"}
}

time_clock
