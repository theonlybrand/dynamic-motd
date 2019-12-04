#!/bin/bash
#
#	 
#	The boring stuff first - License
#
#	(c) 2019 Felix Brand <theonlybrand@web.de>
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# ############################## SETTINGS ############################## 
# User defined warnings (row in red)
# if greater than this value, display corresponding line in red, otherwise in green
status_processes_zombie_warn=0 # (int)
# 1.0 = 100% load on ALL cores
status_cpu_load_warn1m=1.0 # (float) 1minute load average over this value -> red line
status_cpu_load_warn5m=0.7 # (float) 5minute load average over this value -> red line
status_cpu_load_warn15m=0.5 # (float) 15minute load average over this value -> red line
status_mem_usage_warn=80.0 # (float) %used memory(-buffers/cache) to trigger red line
status_swap_usage_warn=80.0 # (float) %used swap to trigger red line
status_disk_usage_warn=80 # (int) warn if % disk usage greater than this value
status_file_descriptor_usage_warn=70.0 # (float) warn if % of available file descriptors is used
update_repository_max_age=86400 # (int) Update Package List (apt-get update) if this period (seconds) after last update has passed 
# if there is more than one security update, line is red
# ############################## ~~~~~~~ ############################## 
#
#
# #####################################################################################################################################
#
#
# Color Reference https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
# http://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux/5947802#5947802
#
red="\033[0;31m"
redl="\033[1;31m"
green="\033[0;32m"
yellow="\033[0;33m"
cyan="\033[0;36m"
defcolor="\033[0m" # no color

color_no_status_indicator_yet=$defcolor

export PATH=$PATH:/usr/sbin:/usr/bin:/sbin:/bin
if [[ ! -f /usr/bin/figlet || ! -f /usr/bin/bc || ! -f /usr/bin/lsb_release || ! -f /usr/sbin/needrestart ]]; then
	echo -e "$red\nError: Required packages are not installed.\ninstall with\napt-get update && apt-get install figlet bc lsb-release needrestart$defcolor\n"
	exit
fi

# relative cpu load warnings (1.0 = 100% on all cores)
status_cpu_load_warn1m=$(bc <<< "$status_cpu_load_warn1m+$(nproc)-1")
status_cpu_load_warn5m=$(bc <<< "$status_cpu_load_warn5m+$(nproc)-1")
status_cpu_load_warn15m=$(bc <<< "$status_cpu_load_warn15m+$(nproc)-1")

# System  welcome message #################################################################################
release_description=$(lsb_release -s -d)
release_kernel=$(uname -r)
#release_arch=$(uname -m)

# System Load #################################################################################

# awk $value:
#			 total	   used	   free	 shared	buffers	 cached
#Mem:			 8		  9		 10		 11		 12		 13
#-/+ buffers/cache:		 16		 17
#Swap:		   19		 20		 21
#
physical_memory_usage=$(free -m | awk -v RS=", " '{printf("%3.1f", $9/$8*100)}')
#swap_usage=$(free -m | awk -v RS=", " '{printf("%3.1f", $20/$19*100)}')
swap_total=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
if (( $swap_total == 0 )); then
	swap_usage="N/A"
else
	swap_free=$(cat /proc/meminfo | grep SwapFree | awk '{print $2}')
	swap_usage=$(echo $(bc -l <<< "(1-$swap_free/$swap_total)*100") | awk '{printf("%3.1f",$1)}')
fi

if [ $(cat /proc/meminfo | grep MemAvailable | wc -l) -eq 0 ]; then
	mem_usage=$(free | awk -v RS=", " '{printf("%3.1f", $16/$8*100)}') # fallback if MemAvailable is not available
else
	mem_free=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
	mem_total=$(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}')))
	mem_usage=$(echo $(bc -l <<< "(1-$mem_free/$mem_total)*100") | awk '{printf("%3.1f",$1)}')
fi

uptime=$(uptime -p | awk '{print substr($0, 4)}')
users=$(users | wc -w)

processes=$(ps ax | wc -l | awk '{print $1}')
processes_zombie=$(( $(ps aux | grep 'Z' | wc -l) -2 ))

cpu_load=$(cat /proc/loadavg | awk '{printf "%s %s %s ('$(nproc)' core)", $1, $2, $3}')

file_descriptor_allocated=$(cat /proc/sys/fs/file-nr | awk '{print $1}')
file_descriptor_max=$(cat /proc/sys/fs/file-nr | awk '{print $3}')
file_descriptor_tcp=$(netstat -nat | wc -l)
file_descriptor_usage=$(echo $(bc -l <<< "($file_descriptor_allocated/$file_descriptor_max)*100") | awk '{printf("%3.2f",$1)}')

disk_usage=$(df --total  | grep -v udev | egrep "/dev/*" | awk '{printf "%-20s %-27s %-3s\n", $1, $6, $5}') # -x tmpfs # exclude
# `df --total -x tmpfs | grep -v udev | egrep "/dev/*"` | grep -v -i /dev/shm | awk '{print substr($5,1,2)}'


# Network #################################################################################
interfaces=$(cat /proc/net/dev | awk 'NR>2{print substr($1, 1, length($1)-1)}')

# Cast to int
#updates_security=$(($updates_security+0))
#processes_zombie=$(($processes_zombie+0))

if (( "$processes_zombie" > "$status_processes_zombie_warn" ))
then
	status_processes_zombie=$red
else
	status_processes_zombie=$green
fi

#if (($(echo `echo $cpu_load | awk '{print $3}'`'>'$status_cpu_load_warn | bc -l))) # awk $1 $2 $3 = 1min 5min 15min avg load

cpu_load1m=$(echo $cpu_load | awk '{print $1}')
cpu_load5m=$(echo $cpu_load | awk '{print $2}')
cpu_load15m=$(echo $cpu_load | awk '{print $3}')
if (( $(bc <<< "$cpu_load1m>$status_cpu_load_warn1m") || $(bc <<< "$cpu_load5m>$status_cpu_load_warn5m") || $(bc <<< "$cpu_load15m>$status_cpu_load_warn15m")  ))
then
	status_cpu_load=$red
else
	status_cpu_load=$green
fi

if (( $(bc <<< "$mem_usage > $status_mem_usage_warn") ))
then
	status_mem_usage=$red
else
	status_mem_usage=$green
fi

if (( $swap_total != 0 )); then
	if (( $(bc <<< "$swap_usage > $status_swap_usage_warn") ))
	then
		status_swap_usage=$red
	else
		status_swap_usage=$green
	fi
else
	status_swap_usage=$green
fi

if (( $(bc <<< "$file_descriptor_usage>$status_file_descriptor_usage_warn") ))
then
	status_file_descriptor_usage=$red
else
	status_file_descriptor_usage=$green
fi

echo -e -n "$red"

figlet -t $(hostname)

echo -e -n "$cyan"

echo -e "Welcome to $release_description ($release_kernel)$defcolor
$cyan# System Load $color_no_status_indicator_yet
Uptime:\t\t$uptime
Users:\t\t$users$status_cpu_load 
CPU Load:\t$cpu_load$status_processes_zombie 
Processes:\t$processes ($processes_zombie zombies)$status_file_descriptor_usage
FDs:\t\t$file_descriptor_usage% ($file_descriptor_allocated [TCP: $file_descriptor_tcp] / $file_descriptor_max)$status_mem_usage 
Memory Usage:\t$mem_usage%$status_swap_usage 
Swap Usage:\t$swap_usage%$color_no_status_indicator_yet 
$cyan# Disk - Device      Mountpoint			 %Usage $color_no_status_indicator_yet "
# Disk Usage #################################################################################
count=1
echo "$disk_usage" | while read disk; do 
	pused=$(echo "$disk" | awk '{print substr($3,1,length($3)-1)}') # % disk used
	
	#pused=`echo $pused | awk '{printf "%d", $0}'` # cast to int
	#status_disk_usage_warn=`echo $status_disk_usage_warn | awk '{printf "%d", $0}'` # cast to int
	#echo $pused;
	#echo $(echo "$pused $status_disk_usage_warn" | awk '{print ($1 > $2)}');
	if (( "$pused" > "$status_disk_usage_warn" )); then
		status_disk_usage=$red
		#echo "$pused > $status_disk_usage_warn"
	else
		status_disk_usage=$green
		#echo "green"
		#echo "$pused < $status_disk_usage_warn"
	fi
	echo -e -n "$status_disk_usage"
	#df --total  | grep -v udev | egrep "/dev/*" | awk '{printf "%-25s %-40s %s\n", $1, $6, $5}' | tail -n$count | head -n1
	echo "$disk"
	#echo -e "$color_no_status_indicator_yet"
	count=$(($count+1))
done
echo -en "$cyan"
#echo -e "# Traffic - iface            RX                  TX $color_no_status_indicator_yet"
# Network traffic #################################################################################
#echo "$interfaces" | while read iface; do
#	rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
#	tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)
# 	echo -e "$iface\t\t\t $(($rx/1024/1024)) MiB\t\t\t$(($tx/1024/1024)) MiB";
#	if (( $(($rx+$tx)) > 0 )); then
#		printf "%-13s %17s %19s\n" "$iface" "$(bc -l <<< "scale=1; $rx/1024/1024/1024") GiB" "$(bc -l <<< "scale=1; $tx/1024/1024/1024") GiB"
#	fi;
#done

echo -e "$cyan# Security$color_no_status_indicator_yet"

if [ $EUID -eq 0 ]; then
	# Security #################################################################################	
	if [[ -f /var/run/reboot-required || ! $(needrestart -k -r l -b 2>/dev/null | grep -c "NEEDRESTART-KSTA: 1") ]]; then
		echo -e "${red}System restart required!$defcolor"
	fi

	old_services=$(needrestart -l -r l -b 2>/dev/null | grep -v "NEEDRESTART-VER:" | wc -l)
	if (( old_services > 0 )); then
		echo -e "${yellow}${old_services} services might need a restart.$defcolor command: needrestart"
	fi

	if [ -f /var/log/auth.log ]; then
		ssh_fails=$(cat /var/log/auth.log | grep -i "fail" | wc -l)
		ssh_first_fail_date=$(head -n1 /var/log/auth.log | awk '{print $1, $2}')
	
		echo -e "$ssh_fails failed SSH logins since $ssh_first_fail_date$defcolor"
	fi

	package_manager_found=0
	
	### SWITCH package manager commands for different OS ###
	if [ -f /usr/bin/apt-get ]; then # debian/ubuntu, apt-get package manager
		if (( $(date +%s) - $(stat -c%Y /var/cache/apt/pkgcache.bin) > update_repository_max_age)); then
			echo "Updating package list..."
			apt-get update > /dev/null 2>&1
		fi
		
		updates=$(apt-get -s upgrade | grep ^Inst | wc -l)
		updates_security=$(apt-get -s upgrade | grep ^Inst | grep -i security | wc -l)
		
		package_manager_found=1
	elif [ -f /usr/bin/pacman ]; then
		updates=$(pacman -Syup | grep "http://" | wc -l) 2>/dev/null

		if [ -f /usr/bin/arch-audit ]; then
			updates_security=$(arch-audit --upgradable | wc -l) 2>/dev/null
		else
			echo -e "${red}Error: Please install arch-audit from AUR$defcolor";
		fi
		package_manager_found=1
	elif [ -f /usr/bin/yum ]; then
		updates=$(yum list updates | grep "update" | wc -l) 2>/dev/null
		updates_security=$(yum update --security | grep ^Inst | wc -l) 2>/dev/null
		fi
		package_manager_found=1
	else
		echo -e "${red}Error: No command available yet for your package manager$defcolor";
	fi


	if (("$package_manager_found" == "1")); then
		
		updates_security=$(($updates_security+0))
		updates=$(($updates+0))
		
		if (("$updates_security" == "0")); then
			status_updates_security=$green
		else
			status_updates_security=$red
		fi
		if (("$updates" == "0")); then
			status_updates=$green
		else
			status_updates=$yellow
		fi
		
		echo -e "$status_updates$updates packages can be updated.$status_updates_security \n$updates_security updates are security updates.\n$defcolor"
	fi
# Der Block unterhalb wird unter CentOS nicht benötigt
else
	echo -e "This requires root privileges.
	$defcolor"
fi
