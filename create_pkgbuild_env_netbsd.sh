#!/bin/sh

OS=NetBSD
DIST=$1
PKG=pike8.0
VER=`grep PIKE_VERSION= ports/pike8.0/version.mk | cut -f 2 -d '=' | tr '\t' ' ' | sed -e 's/^[ ]*//;s/[ ]*$//'`
RELEASE=2017Q3
PLATFORM=x86_64
MAKE=make
PKGSRC_REL=$RELEASE

case "$DIST" in
  netbsd6)
DIST=6.1.5
;;
  netbsd7)
DIST=7.1
;;
  *)
    echo need a valid netbsd version. "$DIST" not valid.
    echo "usage: $0 6|7"
    exit 1;
  ;;
esac

IMAGE=netbsd-$DIST

if [ "x$VER" = "x" ] ; then
  echo "Unable to find version for pike package build. aborting."
  exit 1
else
  echo "Building a package for Pike $VER for OS $OS $RELEASE".
  cd ports
  tar czvf ../$PKG-$$.tar.gz $PKG*
  cd ..
fi


SSHOPTS="-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"
DATE=`date +%y%m%d%H%M`
HOST=$OS-$DIST-$RELEASE-pkgbuild-$DATE
HOST=`echo $HOST | tr "." "-"`

triton create -w -N external -n $HOST $IMAGE kvm-512m || exit 1
sleep 60
# bootstrap and install prerequisite packages
scp $SSHOPTS sets-netbsd-$DIST/* root@$HOST:/

ssh $SSHOPTS root@$HOST << EOFF
  PATH=/usr/pkg/bin:/usr/pkg/sbin:$PATH

echo "adding 1gb of swap"

dd if=/dev/zero of=/swap bs=1m count=1024
chmod 600 /swap
swapctl -a -p 1 /swap 

echo updating and installing git and friends.
  echo ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/$DIST/All > /usr/pkg/etc/pkgin/repositories.conf
  pkgin -y update
  pkgin -y update
  pkgin -y in wget tar bzip2 ed git git-base psmisc screen mozilla-rootcerts
  mozilla-rootcerts install
  git config --global http.sslVerify false
echo "installing sdk and x sdk sets"
  cd / 
echo "installing compiler tools"
  tar xzf comp.tgz
echo "installing x11 base"
  tar xzf xbase.tgz 
echo "installing x11 libraries"
  tar xzf xcomp.tgz 

echo "cloning pkgsrc"
mkdir -p /data
 cd /data
 git clone https://github.com/joyent/pkgsrc.git > /dev/null
cd pkgsrc
git checkout pkgsrc-$RELEASE > /dev/null
# git checkout trunk > /dev/null
echo "cloning pkgbuild"
cd /data 
git clone https://github.com/joyent/pkgbuild.git > /dev/null

echo "installing prerequisites"
 pkgin -y in libtool-base alsa-lib unixodbc 
echo adding gtk and friends
 pkgin -y in gtk2+ libXext libX1 libXt libXtst pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto 
echo adding other library dependencies
 pkgin -y in nettle libffi pcre mysql-client-5.5 gdbm tiff freetype2 gcc49 autoconf bison gcc49-libs patch gmake digest openjdk8 digest nbpatch pkgvi pkgdiff pkg_alternatives pkgconf m4 
 pkgin -y in openjdk8
 pkgin -y in gtk2+
 pkgin -y in gtk2
 pkgin -y in gtk2
 pkgin -y in openjdk8
#cd /data/pkgsrc/bootstrap
#./bootstrap
# pkg_delete sqlite3 pkgin
# sed -e 's/always/never/' < /usr/pkg/etc/pkg_install.conf > /tmp/pki
# rm -f /usr/pkg/etc/pkg_install.conf
# mv /tmp/pki /usr/pkg/etc/pkg_install.conf
# echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /usr/pkg/etc/pkg_install.conf
echo "done installing prerequisites"
EOFF

#copy setup files
echo copy setup files
scp $SSHOPTS openjdk8.patch root@$HOST:/data/pkgsrc/lang/openjdk8
scp $SSHOPTS pkgsrc_lang.patch root@$HOST:/data/pkgsrc/
scp $SSHOPTS $PKG-$$.tar.gz root@$HOST:/data/pkgsrc/lang/$PKG-all.tar.gz

echo starting build
ssh $SSHOPTS root@$HOST << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin
 cd /data/pkgsrc
 gpatch -p1 < pkgsrc_lang.patch
 cd /data/pkgsrc/lang/openjdk8
 gpatch -p0 < openjdk8.patch
  cd /data/pkgsrc/lang
 tar xzvf $PKG-all.tar.gz
if [ "$DIST" = "6.1.5" ] ; then
#  rm -rf pike8.0-GTK2
#  rm -rf pike8.0-Image_SVG
else
pkgin -y in librsvg
fi
pkgin -y in libwebp
  cd /data/pkgsrc/lang
 tar xzvf $PKG-all.tar.gz
  rm $PKG-all.tar.gz
  cd /data/pkgsrc/devel/glib2
  pike -x rsif "TOOL_DEPENDS" "#TOOL_DEPENDS" buildlink3.mk
  make package
  pkg_delete -f glib2
  make install
EOFF
echo "SSH: ssh $SSHOPTS root@$HOST"
