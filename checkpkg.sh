#!/bin/sh

# CHANGE THIS!
PKGSUFFIXES="_SBo"
# END OF CHANGES

PKGUPGRADE="${HOME}/upgrade-rebuild-$(date +%Y%m%dT%H%M%S).txt"
PKGMISSING="${HOME}/missing-files-$(date +%Y%m%dT%H%M%S).txt"

PKGLISTTMP="$(mktemp /tmp/checklib-list.XXXXXX)"

ARCH=`uname -m`
if [ "$ARCH" == "x86_64" ]; then
    LIBSUFFIX="64"
else
    LIBSUFFIX=""
fi

unset PKG FILE BINFILE PKGSUFFIX
for PKGSUFFIX in ${PKGSUFFIXES}; do
  ls -1 /var/log/packages/*${PKGSUFFIX} | sed '/kernel-/d' | sort -u | tee -a $PKGLISTTMP >/dev/null
done

cat ${PKGLISTTMP} | while read PKG; do
  PKGTESTTMP="$(mktemp /tmp/checklib-test.XXXXXX)"
  PKGNAME="$(basename $PKG)"

  echo "Package $PKGNAME" | tee -a $PKGTESTTMP
  cat $PKG | sed '/:/d' | grep -e "bin/" -e "sbin/" -e "lib" -e "usr/" -e "opt/" | sed 's:^:/:g' | while read FILE; do
    if test -e "$FILE"; then
      # test ELF binary only
      file $FILE | grep -e ELF -e "shared object" | cut -d : -f 1 | while read -r f1 f2 ; do
        if printf '%s\n' "$f1" | xargs ldd | grep -q "not found" 2>/dev/null; then
	  echo "==> $f1: FAILED" | tee -a $PKGTESTTMP
#           echo "$(basename $PKG)" | tee -a $PKGUPGRADETMP >/dev/null
        fi
      done
    else
      echo "==> $FILE: MISSING" | tee -a $PKGTESTTMP
    fi
  done

  if grep -q ': FAILED' $PKGTESTTMP 2>/dev/null ; then
    cat $PKGTESTTMP | sed '/MISSING/d' | tee -a $PKGUPGRADE >/dev/null
  fi
  
  if grep -q ': MISSING' $PKGTESTTMP 2>/dev/null ; then
    cat $PKGTESTTMP | sed '/FAILED/d' | tee -a $PKGMISSING >/dev/null
  fi
  
  rm -f $PKGTESTTMP
done

rm -f $PKGLISTTMP
unset PKGSUFFIXES PKGSUFFIX PKG FILE BINFILE PKGLISTTMP PKGUPGRADETMP PKGMISSING PKGUPGRADE
