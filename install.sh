##########################################################################################
#
# Unity Config Script
# by topjohnwu, modified by Zackptg5
#
##########################################################################################

##########################################################################################
# Unity Logic - Don't change/move this section
##########################################################################################

if [ -z $UF ]; then
  UF=$TMPDIR/META-INF/com/google/android/unityfiles
  unzip -oq "$ZIPFILE" 'META-INF/com/google/android/unityfiles/util_functions.sh' -d $TMPDIR >&2
  [ -f "$UF/util_functions.sh" ] || { ui_print "! Unable to extract zip file !"; exit 1; }
  . $UF/util_functions.sh
fi

comp_check

##########################################################################################
# Config Flags
##########################################################################################

# Uncomment and change 'MINAPI' and 'MAXAPI' to the minimum and maximum android version for your mod
# Uncomment DYNLIB if you want libs installed to vendor for oreo+ and system for anything older
# Uncomment SYSOVER if you want the mod to always be installed to system (even on magisk) - note that this can still be set to true by the user by adding 'sysover' to the zipname
# Uncomment DEBUG if you want full debug logs (saved to /sdcard in magisk manager and the zip directory in twrp) - note that this can still be set to true by the user by adding 'debug' to the zipname
#MINAPI=21
#MAXAPI=25
#DYNLIB=true
#SYSOVER=true
#DEBUG=true

# Uncomment if you do *NOT* want Magisk to mount any files for you. Most modules would NOT want to set this flag to true
# This is obviously irrelevant for system installs
#SKIPMOUNT=true

##########################################################################################
# Replace list
#########################$INSTALLER/common/unityfiles/###############################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE="
"

##########################################################################################
# Custom Logic
##########################################################################################

# Set what you want to display when installing your module

print_modname() {
  center_and_print # Replace this line if using custom print stuff
  unity_main # Don't change this line
}

set_permissions() {
  set_perm $UNITY$BINPATH/dns_switch 0 2000 0777

  # Note that all files/folders have the $UNITY prefix - keep this prefix on all of your files/folders
  # Also note the lack of '/' between variables - preceding slashes are already included in the variables
  # Use $VEN for vendor (Do not use /system$VEN, the $VEN is set to proper vendor path already - could be /vendor, /system/vendor, etc.)

  # Some examples:
  
  # For directories (includes files in them):
  # set_perm_recursive  <dirname>                <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
  
  # set_perm_recursive $UNITY/system/lib 0 0 0755 0644
  # set_perm_recursive $UNITY$VEN/lib/soundfx 0 0 0755 0644

  # For files (not in directories taken care of above)
  # set_perm  <filename>                         <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
  
  # set_perm $UNITY/system/lib/libart.so 0 0 0644
}

# Custom Variables for Install AND Uninstall - Keep everything within this function - runs before uninstall/install
unity_custom() {
  BIN=$SYS/bin
  XBIN=$SYS/xbin
  if [ -d $XBIN ]; then BINPATH=$XBIN; else BINPATH=$BIN; fi
  if [ -d /cache ]; then CACHELOC=/cache; else CACHELOC=/data/cache; fi
#  MODTITLE=$(grep_prop name $INSTALLER/module.prop)
#  VER=$(grep_prop version $INSTALLER/module.prop)
#	AUTHOR=$(grep_prop author $INSTALLER/module.prop)
#	INSTLOG=$CACHELOC/dns_switch_install.log
#  MAGISK_VER="$(grep MAGISK_VER_CODE /data/adb/magisk/util_functions.sh)"
}

# Custom Functions for Install AND Uninstall - You can put them here

#log_handler() {
#  echo "" >> $INSTLOG 2>&1
#  echo -e "$(date +"%m-%d-%Y %H:%M:%S") - $1" >> $INSTLOG 2>&1
#}

#log_start() {
#	if [ -f "$INSTLOG" ]; then
#    truncate -s 0 $INSTLOG
#  else
#    touch $INSTLOG
#  fi
#  echo " " >> $INSTLOG 2>&1
#  echo "    *******************************************" >> $INSTLOG 2>&1
#  echo "    *              DNS SWITCHER               *" >> $INSTLOG 2>&1
#  echo "    *******************************************" >> $INSTLOG 2>&1
#  echo "    *              VERSION 3.0                *" >> $INSTLOG 2>&1
#  echo "    *******************************************" >> $INSTLOG 2>&1
#  echo "    *              BY JOHN FAWKES             *" >> $INSTLOG 2>&1
#  echo "    *******************************************" >> $INSTLOG 2>&1
#  echo " " >> $INSTLOG 2>&1
#  log_handler "Starting module installation script"
#}

#log_print() {
#  ui_print "$1"
#  log_handler "$1"
#}
