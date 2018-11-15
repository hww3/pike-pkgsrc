#!/bin/sh
VMIMAGE="/Users/hww3/Virtual Machines/pkgbuild OS X 10.9.vmwarevm"
VMSNAPSHOT="pkgbuild"
OS=Darwin
DIST=10.9
RELEASE=trunk

PKGSRC_REL=$RELEASE

. pkgsrc_base.sh

HOST=pkgbuild-osx.local

vmrun revertToSnapshot "$VMIMAGE" "$VMSNAPSHOT"
vmrun start "$VMIMAGE"

sleep 30

# bootstrap and install prerequisite packages

ssh $SSHOPTS root@$HOST << EOFF
#cd /data/pkgsrc/bootstrap
#./bootstrap
# pkg_delete sqlite3 pkgin
sed -i -e 's/always/never/' /opt/pkg/etc/pkg_install.conf 
mkdir -p /data/packages/Darwin/trunk/x86_64/All
echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /opt/pkg/etc/pkg_install.conf
cat /opt/pkg/etc/pkg_install.conf
echo done installing prerequisites
EOFF

#copy setup files
echo copy setup files
safe_copy darwin_pkg/* /data/packages/Darwin/trunk/x86_64/All

echo starting build
xssh $SSHOPTS root@$HOST "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/pkg/bin:/opt/pkg/sbin:/data/pkgbuild/scripts run-sandbox osx-$RELEASE-$PLATFORM" << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/pkg/bin:/opt/pkg/sbin
 ln -s /data/pkgbuild /data/pbulk
 sed -e 's/https:/http:/' < /opt/pkg/etc/pkg_install.conf > /tmp/pkg_install.conf
 cp /tmp/pkg_install.conf /opt/pkg/etc/pkg_install.conf
 cd /data/pkgsrc
  pkg_add wget tar bzip2 ed psmisc screen mozilla-rootcerts
  pkg_add libwebp
  pkg_add librsvg
  #mozilla-rootcerts install
  pkg_add gnupg libtool-base  unixodbc glib2 glib2-tools gtk2+ librsvg2 libwebp  pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto \
  nettle libffi pcre mysql-client gdbm tiff freetype2 gcc49 autoconf bison gcc49-libs patch gmake digest openjdk8 digest nbpatch pkgvi pkgdiff pkg_alternatives pkgconf m4 oracle-jdk8 openjdk8
  git config --global http.sslVerify false
  cd /data/pkgsrc/lang
 tar xzvf pike8.0-all.tar.gz
  rm pike8.0-all.tar.gz

EOFF

copy_phase_1

echo ssh $SSHOPTS root@$HOST
rm pike-$$.tar.gz
