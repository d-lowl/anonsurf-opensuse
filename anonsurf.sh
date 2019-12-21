#!/bin/bash
export BLUE='\033[1;94m'
export GREEN='\033[1;92m'
export RED='\033[1;91m'
export RESETCOLOR='\033[1;00m'


# The UID Tor runs as
_tor_uid=`id -u tor` #ArchLinux/Gentoo

# Tor's TransPort
_trans_port="9040"

# Tor's DNSPort
_dns_port="5353"

# Tor's VirtualAddrNetworkIPv4
_virt_addr="10.192.0.0/10"

# Your outgoing interface
_out_if="wlp4s0"

# LAN destinations that shouldn't be routed through Tor
_non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

# Other IANA reserved blocks (These are not processed by tor and dropped by default)
_resv_iana="0.0.0.0/8 100.64.0.0/10 169.254.0.0/16 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32"



function init {
	echo -e -n "$BLUE[$GREEN*$BLUE] killing dangerous applications\n"
	sudo killall -q chrome dropbox iceweasel skype icedove thunderbird firefox firefox-esr chromium xchat hexchat transmission steam firejail
	echo -e -n "$BLUE[$GREEN*$BLUE] Dangerous applications killed\n"

	echo -e -n "$BLUE[$GREEN*$BLUE] cleaning some dangerous cache elements\n"
	bleachbit -c adobe_reader.cache chromium.cache chromium.current_session chromium.history elinks.history emesene.cache epiphany.cache firefox.url_history flash.cache flash.cookies google_chrome.cache google_chrome.history  links2.history opera.cache opera.search_history opera.url_history &> /dev/null
	echo -e -n "$BLUE[$GREEN*$BLUE] Cache cleaned\n"
}

function start {
	# Make sure only root can run this script
	ME=$(whoami | tr [:lower:] [:upper:])
	if [ $(id -u) -ne 0 ]; then
		echo -e -e "\n$GREEN[$RED!$GREEN] $RED $ME R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi

	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Starting anonymous mode:$RESETCOLOR\n"

	if [ ! -e /var/run/tor/tor.pid ]; then
		systemctl start tor
		sleep 20
	fi


	nmcli device modify wlp4s0 ipv4.dns "127.0.0.1"
	echo -e " $GREEN*$BLUE Modified nameserver configuration to use Tor\n"

	# disable ipv6
	echo -e " $GREEN*$BLUE Disabling IPv6 for security reasons\n"
	/sbin/sysctl -w net.ipv6.conf.all.disable_ipv6=1
	/sbin/sysctl -w net.ipv6.conf.default.disable_ipv6=1

	### *nat OUTPUT (For local redirection)
	# nat .onion addresses
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 0 -d $_virt_addr -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports $_trans_port

	# nat dns requests to Tor
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 1 -d 127.0.0.1/32 -p udp -m udp --dport 53 -j REDIRECT --to-ports $_dns_port

	# Don't nat the Tor process, the loopback, or the local network
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 2 -m owner --uid-owner $_tor_uid -j RETURN
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 3 -o lo -j RETURN

	# Allow lan access for hosts in $_non_tor
	for _lan in $_non_tor; do
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 4 -d $_lan -j RETURN
	done

	for _iana in $_resv_iana; do
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 5 -d $_iana -j RETURN
	done

	# Redirect all other pre-routing and output to Tor's TransPort
	firewall-cmd -q --direct --add-rule ipv4 nat OUTPUT_direct 6 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports $_trans_port

	### *filter INPUT
	firewall-cmd -q --direct --add-rule ipv4 filter INPUT_direct 9 -m state --state ESTABLISHED -j ACCEPT
	firewall-cmd -q --direct --add-rule ipv4 filter INPUT_direct 9 -i lo -j ACCEPT

	# Log & Drop everything else. Uncomment to enable logging
	#iptables -A INPUT -j LOG --log-prefix "Dropped INPUT packet: " --log-level 7 --log-uid
	firewall-cmd -q --direct --add-rule ipv4 filter INPUT_direct 9 -j DROP

	### *filter FORWARD
	firewall-cmd -q --direct --add-rule ipv4 filter FORWARD_direct 9 -j DROP

	### *filter OUTPUT
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 9 -m state --state INVALID -j DROP
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 9 -m state --state ESTABLISHED -j ACCEPT

	# Allow Tor process output
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 10 -o $_out_if -m owner --uid-owner $_tor_uid -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m state --state NEW -j ACCEPT

	# Allow loopback output
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 10 -d 127.0.0.1/32 -o lo -j ACCEPT

	# Tor transproxy magic
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 10 -d 127.0.0.1/32 -p tcp -m tcp --dport $_trans_port --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT

	# Log & Drop everything else. Uncomment to enable logging
	#iptables -A OUTPUT -j LOG --log-prefix "Dropped OUTPUT packet: " --log-level 7 --log-uid
	firewall-cmd -q --direct --add-rule ipv4 filter OUTPUT_direct 100 -j DROP

	echo -e "$GREEN *$BLUE All traffic was redirected throught Tor\n"
	echo -e "$GREEN[$BLUE i$GREEN ]$BLUE You are under AnonSurf tunnel$RESETCOLOR\n"
	sleep 1
	sleep 10
}


function stop {
	# Make sure only root can run our script
	ME=$(whoami | tr [:lower:] [:upper:])

	if [ $(id -u) -ne 0 ]; then
		echo -e "\n$GREEN[$RED!$GREEN] $RED $ME R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi

	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Stopping anonymous mode:$RESETCOLOR\n"

	echo -e "\n $GREEN*$BLUE Deleted all iptables rules"

	firewall-cmd --complete-reload

	echo -e -n "\n $GREEN*$BLUE Restore DNS service"
	nmcli device modify wlp4s0 ipv4.dns "8.8.8.8"

	# re-enable ipv6
	/sbin/sysctl -w net.ipv6.conf.all.disable_ipv6=0
	/sbin/sysctl -w net.ipv6.conf.default.disable_ipv6=0

	systemctl stop tor
	sleep 2
	killall tor
	sleep 6

	echo -e " $GREEN*$BLUE Anonymous mode stopped\n"
	sleep 4
}


function change {
	killall -HUP tor
	echo -e " $GREEN*$BLUE Tor daemon reloaded and forced to change nodes\n"
	sleep 1
}


case "$1" in
	init)
		init
	;;
	start)
		start
	;;
	stop)
		stop
	;;
	changeid|change-id|change)
		change
	;;
	myip|ip)
		ip
	;;
	restart)
		$0 stop
		sleep 1
		$0 start
	;;
   *)
echo -e "
AnonSurf OpenSuse Module
	Developed by D. Lowl <dlowl@sihvi.com>
	Based on the original AnonSurf Module 

	Usage:
	$RED┌──[$GREEN$USER$YELLOW@$BLUE`hostname`$RED]─[$GREEN$PWD$RED]
	$RED└──╼ \$$GREEN"" anonsurf $RED{$GREEN""init$RED|$GREEN""start$RED|$GREEN""stop$RED|$GREEN""restart$RED|$GREEN""change$RED""$RED}

	$RED init$BLUE -$GREEN Kill dangerous apps before starting tunneling
	$RED start$BLUE -$GREEN Start system-wide TOR tunnel
	$RED stop$BLUE -$GREEN Stop anonsurf and return to clearnet
	$RED restart$BLUE -$GREEN Combines \"stop\" and \"start\" options
	$RED change$BLUE -$GREEN Restart TOR to change identity
$RESETCOLOR
Dance like no one's watching. Encrypt like everyone is.
" >&2

exit 1
;;
esac

echo -e $RESETCOLOR
exit 0
