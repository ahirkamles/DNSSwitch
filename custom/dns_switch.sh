#!/system/bin/sh
# Terminal Magisk Mod Template
# by veez21 @ xda-developers
# Modified by @JohnFawkes - Telegram
# Supersu/all-root compatibility with Unity and @Zackptg5
# Variables
OLDPATH=$PATH
CACHELOC=<CACHELOC>
BINPATH=<BINPATH>
SDCARD=/storage/emulated/0
TMPLOG=DNSSwitch_logs.log
TMPLOGLOC=$CACHELOC/DNSSwitch_logs
DNSLOG=$MODPATH/dns.txt
DNSSERV=$MODPATH/service.sh

quit() {
  PATH=$OLDPATH
  exit $?
}

MODPROP=<MODPROP>
$MAGISK && [ ! -f $MODPROP ]
[ -f $MODPROP ] || { echo "Module not detected!"; quit 1; }

# Detect root
_name=$(basename $0)
ls /data >/dev/null 2>&1 || { echo "$MODID needs to run as root!"; echo "type 'su' then '$_name'"; quit 1; }

# Set Log Files
mount -o remount,rw $CACHELOC 2>/dev/null
mount -o rw,remount $CACHELOC 2>/dev/null
# > Logs should go in this file
LOG=$CACHELOC/DNSSwitch.log
oldLOG=$CACHELOC/DNSSwitch-old.log
# > Verbose output goes here
VERLOG=$CACHELOC/DNSSwitch-verbose.log
oldVERLOG=$CACHELOC/DNSSwitch-verbose-old.log

# Start Logging verbosely
mv -f $VERLOG $oldVERLOG 2>/dev/null
mv -f $LOG $oldLOG 2>/dev/null
set -x 2>$VERLOG

# Loggers
LOGGERS="
$CACHELOC/magisk.log
$CACHELOC/magisk.log.bak
$CACHELOC/DNSSwitch-install.log
$SDCARD/dns_switch-debug.log
$CACHELOC/dns_switch
/data/adb/magisk_debug.log
$CACHELOC/DNSSwitch.log
$CACHELOC/DNSSwitch-old.log
$CACHELOC/DNSSwitch-verbose.log
$CACHELOC/DNSSwitch-verbose-old.log
"

#log_handler() {
#	if [ $(id -u) == 0 ] ; then
#		echo "" >> $LOG 2>&1
#		echo -e "$(date +"%m-%d-%Y %H:%M:%S") - $1" >> $LOG 2>&1
#	fi
#}

#log_print() {
#	echo "$1"
#	log_handler "$1"
#}

#log_script_chk() {
#	log_handler "$1"
#	echo -e "$(date +"%m-%d-%Y %H:%M:%S") - $1" >> $LOG 2>&1
#}

#get_file_value() {
#	cat $1 | grep $2 | sed "s|.*$2||" | sed 's|\"||g'
#}

#ZACKPTG5 BUSYBOX
#=========================== Set Busybox up
if [ "$(busybox 2>/dev/null)" ]; then
  BBox=true
elif $MAGISK && [ -d /sbin/.core/busybox ]; then
  PATH=/sbin/.core/busybox:$PATH
	_bb=/sbin/.core/busybox/busybox
  BBox=true
elif $MAGISK && [ -d /sbin/.magisk/busybox ]; then
PATH=/sbin/.magisk/busybox:$PATH
_bb=/sbin/.magisk/busybox/busybox
BBox=true
elif $MAGISK && [ -d /data/adb/magisk/busybox ]; then
PATH=/data/adb/magisk/busybox:PATH
_bb=/data/adb/magisk/busybox
BBox=true
else
  BBox=false
  echo "! Busybox not detected"
	echo "Please install one (@osm0sis' busybox recommended)"
  for applet in cat chmod cp grep md5sum mv printf sed sort tar tee tr wget; do
    [ "$($applet)" ] || quit 1
  done
  echo "All required applets present, continuing"
fi
if $BBox; then
  alias cat="busybox cat"
  alias chmod="busybox chmod"
  alias cp="busybox cp"
  alias grep="busybox grep"
  alias md5sum="busybox md5sum"
  alias mv="busybox mv"
  alias printf="busybox printf"
  alias sed="busybox sed"
  alias sort="busybox sort"
  alias tar="busybox tar"
  alias tee="busybox tee"
  alias tr="busybox tr"
  alias wget="busybox wget"
  alias unzip="busybox unzip"
fi

if [ -z "$(echo $PATH | grep /sbin:)" ]; then
	alias resetprop="/data/adb/magisk/magisk resetprop"
fi

# Log print
log_handler "Functions loaded."
if $BBox; then
  BBV=$(busybox | grep "BusyBox v" | sed 's|.*BusyBox ||' | sed 's| (.*||')
  log_handler "Using busybox: ${PATH} (${BBV})."
else
  log_handler "Using installed applets (not busybox)"
fi

# Functions
grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}


api_level_arch_detect() {
  API=`grep_prop ro.build.version.sdk`
  ABI=`grep_prop ro.product.cpu.abi | cut -c-3`
  ABI2=`grep_prop ro.product.cpu.abi2 | cut -c-3`
  ABILONG=`grep_prop ro.product.cpu.abi`
  ARCH=arm
  ARCH32=arm
  IS64BIT=false
  if [ "$ABI" = "x86" ]; then ARCH=x86; ARCH32=x86; fi;
  if [ "$ABI2" = "x86" ]; then ARCH=x86; ARCH32=x86; fi;
  if [ "$ABILONG" = "arm64-v8a" ]; then ARCH=arm64; ARCH32=arm; IS64BIT=true; fi;
  if [ "$ABILONG" = "x86_64" ]; then ARCH=x64; ARCH32=x86; IS64BIT=true; fi;
}

set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  [ -z $5 ] && chcon 'u:object_r:system_file:s0' $1 || chcon $5 $1 || return 1
}

magisk_version() {
  if grep MAGISK_VER /data/adb/magisk/util_functions.sh; then
		log_print "$MAGISK_VERSION $MAGISK_VERSIONCODE" >> $LOG 2>&1
	else
		log_print "Magisk not installed" >> $LOG 2>&1
	fi
}

# Device Info
# BRAND MODEL DEVICE API ABI ABI2 ABILONG ARCH
BRAND=$(getprop ro.product.brand)
MODEL=$(getprop ro.product.model)
DEVICE=$(getprop ro.product.device)
ROM=$(getprop ro.build.display.id)
api_level_arch_detect
# Version Number
VER=$(grep_prop version $MODPROP)
# Version Code
REL=$(grep_prop versionCode $MODPROP)
# Author
AUTHOR=$(grep_prop author $MODPROP)
# Mod Name/Title
MODTITLE=$(grep_prop name $MODPROP)
#Grab Magisk Version
MAGISK_VERSION=$(echo $(get_file_value /data/adb/magisk/util_functions.sh "MAGISK_VER=") | sed 's|-.*||')
MAGISK_VERSIONCODE=$(echo $(get_file_value /data/adb/magisk/util_functions.sh "MAGISK_VER_CODE=") | sed 's|-.*||')

# Colors
G='\e[01;32m'		# GREEN TEXT
R='\e[01;31m'		# RED TEXT
Y='\e[01;33m'		# YELLOW TEXT
B='\e[01;34m'		# BLUE TEXT
V='\e[01;35m'		# VIOLET TEXT
Bl='\e[01;30m'		# BLACK TEXT
C='\e[01;36m'		# CYAN TEXT
W='\e[01;37m'		# WHITE TEXT
BGBL='\e[1;30;47m'	# Background W Text Bl
N='\e[0m'			# How to use (example): echo "${G}example${N}"
loadBar=' '			# Load UI
# Remove color codes if -nc or in ADB Shell
[ -n "$1" -a "$1" == "-nc" ] && shift && NC=true
[ "$NC" -o -n "$LOGNAME" ] && {
	G=''; R=''; Y=''; B=''; V=''; Bl=''; C=''; W=''; N=''; BGBL=''; loadBar='=';
}

# Divider (based on $MODTITLE, $VER, and $REL characters)
character_no=$(echo "$MODTITLE $VER $REL" | tr " " '_' | wc -c)
div="${Bl}$(printf '%*s' "${character_no}" '' | tr " " "=")${N}"

# Title Div
title_div() {
  no=$(echo "$@" | wc -c)
  extdiv=$((no-character_no))
  echo "${W}$@${N} ${Bl}$(printf '%*s' "$extdiv" '' | tr " " "=")${N}"
}

# set_file_prop <property> <value> <prop.file>
set_file_prop() {
  if [ -f "$3" ]; then
    if grep "$1=" "$3"; then
      sed -i "s/${1}=.*/${1}=${2}/g" "$3"
    else
      echo "$1=$2" >> "$3"
    fi
  else
    echo "$3 doesn't exist!"
  fi
}

# https://github.com/fearside/ProgressBar
# ProgressBar <progress> <total>
ProgressBar() {
# Determine Screen Size
  if [[ "$COLUMNS" -le "57" ]]; then
    local var1=2
	local var2=20
  else
    local var1=4
    local var2=40
  fi
# Process data
  local _progress=$(((${1}*100/${2}*100)/100))
  local _done=$(((${_progress}*${var1})/10))
  local _left=$((${var2}-$_done))
# Build progressbar string lengths
  local _done=$(printf "%${_done}s")
  local _left=$(printf "%${_left}s")

# Build progressbar strings and print the ProgressBar line
printf "\rProgress : ${BGBL}|${N}${_done// /${BGBL}$loadBar${N}}${_left// / }${BGBL}|${N} ${_progress}%%"
}

#https://github.com/fearside/SimpleProgressSpinner
# Spinner <message>
Spinner() {

# Choose which character to show.
case ${_indicator} in
  "|") _indicator="/";;
  "/") _indicator="-";;
  "-") _indicator="\\";;
  "\\") _indicator="|";;
  # Initiate spinner character
  *) _indicator="\\";;
esac

# Print simple progress spinner
printf "\r${@} [${_indicator}]"
}

# cmd & spinner <message>
e_spinner() {
  PID=$!
  h=0; anim='-\|/';
  while [ -d /proc/$PID ]; do
    h=$(((h+1)%4))
    sleep 0.02
    printf "\r${@} [${anim:$h:1}]"
  done
}

# test_connection
# tests if there's internet connection
test_connection() {
  echo -n "Testing internet connection "
  ping -q -c 1 -W 1 google.com >/dev/null 2>&1 && echo "- OK" || { echo "Error"; false; }
}

# Log files will be uploaded to termbin.com
# Logs included: VERLOG LOG oldVERLOG oldLOG
upload_logs() {
  $BBok && {
    test_connection || exit
    echo "Uploading logs"
    [ -s $VERLOG ] && verUp=$(cat $VERLOG | nc termbin.com 9999) || verUp=none
    [ -s $oldVERLOG ] && oldverUp=$(cat $oldVERLOG | nc termbin.com 9999) || oldverUp=none
    [ -s $LOG ] && logUp=$(cat $LOG | nc termbin.com 9999) || logUp=none
    [ -s $oldLOG ] && oldlogUp=$(cat $oldLOG | nc termbin.com 9999) || oldlogUp=none
    echo -n "Link: "
    echo "$MODEL ($DEVICE) API $API\n$ROM\n$ID\n
    O_Verbose: $oldverUp
    Verbose:   $verUp

    O_Log: $oldlogUp
    Log:   $logUp" | nc termbin.com 9999
  } || echo "Busybox not found!"
  exit
}

# Print Random
# Prints a message at random
# CHANCES - no. of chances <integer>
# TARGET - target value out of CHANCES <integer>
prandom() {
  local CHANCES=2
  local TARGET=2
  [ "$1" ==  "-c" ] && { local CHANCES=$2; local TARGET=$3; shift 3; }
  [ "$((RANDOM%CHANCES+1))" -eq "$TARGET" ] && echo "$@"
}

# Print Center
# Prints text in the center of terminal
pcenter() {
  local CHAR=$(echo $@ | sed 's|\e[[0-9;]*m||g' | wc -m)
  local hfCOLUMN=$((COLUMNS/2))
  local hfCHAR=$((CHAR/2))
  local indent=$((hfCOLUMN-hfCHAR-1))
  echo "$(printf '%*s' "${indent}" '') $@"
}

# Heading
mod_head() {
	clear
	echo "$div"
	echo "${W}$MODTITLE $VER${N}(${Bl}$REL${N})"
	echo "by ${W}$AUTHOR${N}"
	echo "$div"
  echo "${R}$BRAND${N},${R}$MODEL${N},${R}$ROM${N}"
  echo "$div"
	echo "${W}BUSYBOX VERSION = ${N}${R}$_bbname${N}${R}$BBV${N}"
	echo "$div"
if $MAGISK; then 
	echo "${W}MAGISK VERSION = ${N}${R} $MAGISK_VERSION${N}" 
	echo "$div"
  echo ""
fi
}

#=========================== Main
# > You can start your MOD here.
# > You can add functions, variables & etc.
# > Rather than editing the default vars above.

# Find prop type
get_prop_type() {
	echo $1 | sed 's|.*\.||'
}

# Get left side of =
get_eq_left() {
	echo $1 | sed 's|=.*||'
}

# Get right side of =
get_eq_right() {
	echo $1 | sed 's|.*=||'
}

# Get first word in string
get_first() {
	case $1 in
		*\ *) echo $1 | sed 's|\ .*||'
		;;
		*=*) get_eq_left "$1"
		;;
	esac
}

set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  [ -z $5 ] && chcon 'u:object_r:system_file:s0' $1 || chcon $5 $1 || return 1
}

#Log Functions
# Saves the previous log (if available) and creates a new one
#log_start() {
#if [ -f "$LOG" ]; then
#	mv -f $LOG $oldLOG
#fi
#touch $LOG
#echo " " >> $LOG 2>&1
#echo "    *********************************************" >> $LOG 2>&1
#echo "    *              DNSSwitch                    *" >> $LOG 2>&1
#echo "    *********************************************" >> $LOG 2>&1
#echo "    *                 $VER                      *" >> $LOG 2>&1
#echo "    *********************************************" >> $LOG 2>&1
#echo "    *              John Fawkes                  *" >> $LOG 2>&1
#echo "    *********************************************" >> $LOG 2>&1
#echo " " >> $LOG 2>&1
#log_script_chk "Log start."
#}

#collect_logs() {
#	log_handler "Collecting logs and information."
	# Create temporary directory
#	mkdir -pv $TMPLOGLOC >> $LOG 2>&1

	# Saving Magisk and module log files and device original build.prop
#	for ITEM in $LOGGERS; do
#		if [ -f "$ITEM" ]; then
#			case "$ITEM" in
#				*build.prop*)	BPNAME="build_$(echo $ITEM | sed 's|\/build.prop||' | sed 's|.*\/||g').prop"
#				;;
#				*)	BPNAME=""
#				;;
#			esac
#			cp -af $ITEM ${TMPLOGLOC}/${BPNAME} >> $LOG 2>&1
#		else
#			case "$ITEM" in
#				*/cache)
#					if [ "$CACHELOC" == "/cache" ]; then
#						CACHELOCTMP=/cache
#					else
#						CACHELOCTMP=/data/cache
#					fi
#					ITEMTPM=$(echo $ITEM | sed 's|$CACHELOC|$CACHELOCTMP|')
#					if [ -f "$ITEMTPM" ]; then
#						cp -af $ITEMTPM $TMPLOGLOC >> $LOG 2>&1
#					else
#						log_handler "$ITEM not available."
#					fi
#        ;;
#				*)	log_handler "$ITEM not available."
#				;;
#			esac
#    fi
#	done

# Saving the current prop values
#if $MAGISK; then
#  log_handler "RESETPROPS"
#  echo "==========================================" >> $LOG 2>&1
#	resetprop >> $LOG 2>&1
#else
#  log_handler "GETPROPS"
#  echo "==========================================" >> $LOG 2>&1
#	getprop >> $LOG 2>&1
#fi
#if $MAGISK; then
#  log_print " Collecting Modules Installed "
#  echo "==========================================" >> $LOG 2>&1
#  ls $MOUNTPATH >> $INSTLOG 2>&1
#  log_print " Collecting Logs for Installed Files "
#  echo "==========================================" >> $LOG 2>&1
#  log_handler "$(du -ah $MODPATH)" >> $LOG 2>&1
#fi

# Package the files
#cd $CACHELOC
#tar -zcvf DNSSwitch_logs.tar.xz DNSSwitch_logs >> $LOG 2>&1

# Copy package to internal storage
#mv -f $CACHELOC/DNSSwitch_logs.tar.xz $SDCARD >> $LOG 2>&1

#if  [ -e $SDCARD/DNSSwitch_logs.tar.xz ]; then
#  log_print "DNSSwitch_logs.tar.xz Created Successfully."
#else
#  log_print "Archive File Not Created. Error in Script. Please contact @JohnFawkes on Telegram"
#fi

# Remove temporary directory
#rm -rf $TMPLOGLOC >> $LOG 2>&1

#log_handler "Logs and information collected."
#}

# Load functions
#log_start "Running Log script." >> $LOG 2>&1

help_me() {
  cat << EOF
$MODTITLE $VER($REL)
by $AUTHOR

Usage: $_name
   or: $_name [options]...
   
Options:
    -nc                    removes ANSI escape codes
    -r                     remove DNS
    -c [DNS ADRESS]        add custom DNS
    -l                     list custom DNS server(s) in use
    -h                     show this message
EOF
exit
}

get_crypt () {
VERSION=

wget https://github.com/jedisct1/dnscrypt-proxy/releases/download/*/dnscrypt-proxy-android_$ARCH-$VERSION.zip

dnscrypt-proxy-android_arm64-2.0.17.zip

dnscrypt-proxy-android_i386-2.0.17.zip

dnscrypt-proxy-android_x86_64-2.0.17.zip
}

dnscrypt_menu (){

  answer=""

  echo "$div"
  echo ""
  echo "${G}***DNSCRYPT DNS MENU***${N}"
  echo ""
  echo "$div"
  echo ""
  echo -n "${G}Would You Like to Set Up DNSCrypt?${N}" 
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"
  echo ""
  read -r answer
if [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ "$choice" = "yes" ] || [ "$choice" = "Yes" ] || [ "$choice" = "YES" ]; then
  if [ "$ARCH" = "x64" ]; then
  wget https://github.com/jedisct1/dnscrypt-proxy/releases/download/*/dnscrypt-proxy-android_x86_64-2.0.19.zip
  elif [ "$ARCH" = "x86" ]; then
  wget https://github.com/jedisct1/dnscrypt-proxy/releases/download/*/dnscrypt-proxy-android_i386-2.0.19.zip
  else
  wget https://github.com/jedisct1/dnscrypt-proxy/releases/download/*/dnscrypt-proxy-android_$ARCH-2.0.19.zip
  fi
  
  echo ""
  echo -n "${G} Would You Like to Enter a Second DNS?${N}"
  echo ""
  echo -n "${R} [CHOOSE] :   ${N}"
  echo ""
  read -r choice
  echo ""
if [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ "$choice" = "yes" ] || [ "$choice" = "Yes" ] || [ "$choice" = "YES" ]; then
  echo -n "${G} Please Enter Your Custom DNS2${N}"
  echo ""
  echo -n "${R} [CHOOSE]  :  ${N}"
  echo ""
  read -r custom2
  if [ -n $custom2 ]; then
echo "custom2=$custom2" >> $DNSLOG 2>&1
setprop net.eth0.dns2 $custom2
setprop net.dns2 $custom2
setprop net.ppp0.dns2 $custom2
setprop net.rmnet0.dns2 $custom2
setprop net.rmnet1.dns2 $custom2
setprop net.pdpbr1.dns2 $custom2
echo "iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination $custom2:53" >> $DNSSERV 2>&1 
echo "iptables -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination $custom2:53" >> $DNSSERV 2>&1
  fi
   if [ -f /system/etc/resolv.conf ]; then
mkdir -p $MODPATH/system/etc
cp -f /system/etc/resolv.conf $MODPATH/system/etc
printf "nameserver $custom\nnameserver $custom2" >> $MODPATH/system/etc/resolv.conf
set_perm $MODPATH/system/etc/resolv.conf 0 0 0644
   fi
else
echo -n "${R}Return to menu? < y | n > : ${N}"
read -r mchoice
 if [ "$mchoice" = "y" ]; then
menu
 else
echo "${R} Thanks For Using Custom DNS Module By @JohnFawkes - @Telegram/@XDA ${N}"
sleep 1.5
clear && quit
 fi
fi
}

log_menu () {

logresponse=""
choice=""

  echo "$div"
  echo "" 
  echo "${G}***LOGGING MAIN MENU***${N}"
  echo ""
  echo "$div"
  echo ""
  echo "${G}Do You Want To Take Logs?${N}"
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"
  read -r logresponse
if [ "$logresponse" = "y" ] || [ "$logresponse" = "Y" ] || [ "$logresponse" = "yes" ] || [ "$logresponse" = "Yes" ] || [ "$logresponse" = "YES" ]; then
upload_logs
else
echo -n "${R}Return to menu? < y | n > : ${N}"
read -r mchoice
 if [ "$mchoice" = "y" ]; then
menu
else
echo "${R} Thanks For Using Custom DNS Module By @JohnFawkes - @Telegram/@XDA ${N}"
sleep 1.5
clear && quit
 fi
fi
}

dns_remove () {

custom=$(echo $(get_file_value $DNSLOG "custom=") | sed 's|-.*||')
custom2=$(echo $(get_file_value $DNSLOG "custom2=") | sed 's|-.*||')

resetprop --delete net.eth0.dns1
resetprop --delete net.eth0.dns2
resetprop --delete net.dns1
resetprop --delete net.dns2
resetprop --delete net.ppp0.dns1
resetprop --delete net.ppp0.dns2
resetprop --delete net.rmnet0.dns1
resetprop --delete net.rmnet0.dns2
resetprop --delete net.rmnet1.dns1
resetprop --delete net.rmnet1.dns2
resetprop --delete net.pdpbr1.dns1
resetprop --delete net.pdpbr1.dns2

if [ -f $MODPATH/system/etc/resolv.conf ]; then  
  sed -i "/nameserver\ "$custom"/d" $MODPATH/system/etc/resolv.conf
  if [ "$custom2" ]; then
    sed -i "/nameserver\ "$custom2"/d" $MODPATH/system/etc/resolv.conf
  fi
fi
echo -n "${R}Return to menu? < y | n > : ${N}"
read -r mchoice
if [ "$mchoice" = "y" ]; then
menu
else
echo "${R} Thanks For Using Custom DNS Module By @JohnFawkes - @Telegram/@XDA ${N}"
sleep 1.5
clear && quit
fi
}

re_dns_menu () {

response=""
choice=""

  echo "$div"
  echo ""
  echo "${G}***REMOVE CUSTOM DNS MENU***${N}"
  echo ""
  echo "$div"
  echo ""
  echo -n "${G}Do You Want to Remove Your Custom DNS?${N}" 
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"
  read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ] || [ "$response" = "yes" ] || [ "$response" = "Yes" ] || [ "$response" = "YES" ]; then
dns_remove
else
  echo ""
  echo -e "${W}R)${N} ${B}Return to Main Menu${N}"
  echo ""
  echo -e "${W}Q)${N} ${B}Quit${N}"
  echo "$div"
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"

  read -r choice
 
  case $choice in
  r|R) echo "${B}Return to Main Menu Selected... ${N}"
  sleep 1
  clear
  menu
  ;;
  q|Q) echo " ${R}Quiting... ${N}"
  sleep 1
  clear
  quit
  ;;
  *) echo "${Y}item not available! Try Again${N}"
  sleep 1.5
  clear
  ;;
  esac
fi
}

dns_menu () {

custom=""
custom2=""
choice=""

  echo "$div"
  echo ""
  echo "${G}***CUSTOM DNS MENU***${N}"
  echo ""
  echo "$div"
  echo ""
  echo -n "${G}Please Enter Your Custom DNS${N}" 
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"
  echo ""
  read -r custom
 if [ -n $custom ]; then
touch $DNSLOG
set_perm $DNSLOG 0 0 0644
truncate -s 0 $DNSLOG
truncate -s 0 $DNSSERV
echo "custom=$custom" >> $DNSLOG 2>&1
setprop net.eth0.dns1 $custom
setprop net.dns1 $custom
setprop net.ppp0.dns1 $custom
setprop net.rmnet0.dns1 $custom
setprop net.rmnet1.dns1 $custom
setprop net.pdpbr1.dns1 $custom
echo "iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination $custom:53" >> $DNSSERV 2>&1
echo "iptables -t nat -I OUTPUT -p tcp --dport 53 -j DNAT --to-destination $custom:53" >> $DNSSERV 2>&1
 fi
  echo ""
  echo -n "${G} Would You Like to Enter a Second DNS?${N}"
  echo ""
  echo -n "${R} [CHOOSE] :   ${N}"
  echo ""
  read -r choice
  echo ""
if [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ "$choice" = "yes" ] || [ "$choice" = "Yes" ] || [ "$choice" = "YES" ]; then
  echo -n "${G} Please Enter Your Custom DNS2${N}"
  echo ""
  echo -n "${R} [CHOOSE]  :  ${N}"
  echo ""
  read -r custom2
  if [ -n $custom2 ]; then
echo "custom2=$custom2" >> $DNSLOG 2>&1
setprop net.eth0.dns2 $custom2
setprop net.dns2 $custom2
setprop net.ppp0.dns2 $custom2
setprop net.rmnet0.dns2 $custom2
setprop net.rmnet1.dns2 $custom2
setprop net.pdpbr1.dns2 $custom2
echo "iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination $custom2:53" >> $DNSSERV 2>&1 
echo "iptables -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination $custom2:53" >> $DNSSERV 2>&1
  fi
   if [ -f /system/etc/resolv.conf ]; then
mkdir -p $MODPATH/system/etc
cp -f /system/etc/resolv.conf $MODPATH/system/etc
printf "nameserver $custom\nnameserver $custom2" >> $MODPATH/system/etc/resolv.conf
set_perm $MODPATH/system/etc/resolv.conf 0 0 0644
   fi
else
echo -n "${R}Return to menu? < y | n > : ${N}"
read -r mchoice
 if [ "$mchoice" = "y" ]; then
menu
 else
echo "${R} Thanks For Using Custom DNS Module By @JohnFawkes - @Telegram/@XDA ${N}"
sleep 1.5
clear && quit
 fi
fi
} 

menu () {
  
choice=""
custom=$(echo $(get_file_value $DNSLOG "custom=") | sed 's|-.*||')
custom2=$(echo $(get_file_value $DNSLOG "custom2=") | sed 's|-.*||')

while [ "$choice" != "q" ]
  do  	
  mod_head
  echo "$div"
  echo "${G}***DNS MAIN MENU***${N}"
  echo "$div"
  echo ""
  echo "$div"
  if [ "$custom" ]; then
  echo -e "${W}Your Custom DNS is :${N} ${R}$custom${N}"
  fi
  if [ "$custom2" ]; then
  echo -e "${W}Your Second Custom DNS is :${N} ${R}$custom2${N}"
  fi
  echo "$div"
  echo "${G}Please make a Selection${N}"
  echo ""
  echo -e "${W}1)${N} ${B}Enter Custom DNS${N}"
  echo ""
  echo -e "${W}2)${N} ${B}Remove Custom DNS${N}"
  echo ""
  echo -e "${W}3)${N} ${B}DNSCrypt${N}"
  echo ""
  echo -e "${W}Q)${N} ${B}Quit${N}"
  echo ""
  echo -e "${W}L)${N} ${B}Logs${N}"
  echo "$div"
  echo ""
  echo -n "${R}[CHOOSE] :  ${N}"

  read -r choice
 
  case $choice in
  1) echo "${G} Custom DNS Menu Selected... ${N}"
  sleep 1
  clear
  dns_menu
  ;;
  2) echo "${B} Remove Custom DNS Selected... ${N}"
  sleep 1
  clear
  re_dns_menu
  ;;
  3) echo "${B} DNSCrypt Selected... ${N}"
  sleep 1
  clear
  dnscrypt_menu
  ;;
  q|Q) echo " ${R}Quiting... ${N}"
  sleep 1
  clear
  quit
  ;;
  l|L) echo "${R}Logs Selected...${N}"
  sleep 1
  clear
  log_menu
  ;;
  *) echo "${Y}item not available! Try Again${N}"
  sleep 1.5
  clear
  ;;
  esac
done
}

case $1 in
-c|-C) shift
  dns_menu;;
-r|-R) shift
  for i in "$@"; do
  dns_remove
  done
  exit;;
-l|-L) shift
  for i in "$@"; do
custom=$(echo $(get_file_value $DNSLOG "custom=") | sed 's|-.*||')
custom2=$(echo $(get_file_value $DNSLOG "custom2=") | sed 's|-.*||')
  if [ "$custom" ]; then
  echo -e "${W}Your Custom DNS is :${N} ${R}$custom${N}"
  elif [ "$custom2" ]; then
  echo -e "${W}Your Second Custom DNS is :${N} ${R}$custom2${N}"
  else
  echo -e "${R}NO CUSTOM DNS IN USE${N}"
  echo -e "${R}Please run 'su' then 'dns_switch' to use a custom DNS${N}"
  fi
  done
  exit;;
-h|--help) help_me;;
esac  

menu

quit $?
