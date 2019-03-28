log_start
mkdir -p $UNITY$BINPATH
cp_ch -n $TMPDIR/custom/dns_switch.sh $UNITY$BINPATH/dns_switch
log_print " - Using $BINPATH - "
sed -i -e  "s|<BINPATH>|$BINPATH|" -e "s|<CACHELOC>|$CACHELOC|" $UNITY$BINPATH/dns_switch >> $INSTLOG 2>&1
if $MAGISK; then
  sed -i "s|<MODPROP>|$(echo $MOD_VER)|" $UNITY$BINPATH/dns_switch >> $INSTLOG 2>&1
else
  sed -i "s|<MODPROP>|$MOD_VER|" $UNITY$BINPATH/dns_switch >> $INSTLOG 2>&1
fi
patch_script $UNITY$BINPATH/dns_switch >> $INSTLOG 2>&1

