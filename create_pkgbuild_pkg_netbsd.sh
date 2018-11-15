#!/bin/sh

OS=NetBSD
DIST=$1
RELEASE=2018Q3
MAKE=make
PKGSRC_REL=$RELEASE

case "$DIST" in
  netbsd6)
DIST=6.1.5
;;
  netbsd7)
DIST=7.1
;;
  netbsd8)
DIST=8.0
;;
  *)
    echo need a valid netbsd version. "$DIST" not valid.
    echo "usage: $0 6|7|8"
    exit 1;
  ;;
esac

IMAGE=netbsd-$DIST

. pkgsrc_base.sh

HOST=$OS-$DIST-$RELEASE-pkgbuild-$DATE
HOST=`echo $HOST | tr "." "-"`

triton create -w -N external -n $HOST $IMAGE kvm-1g || exit 1
sleep 60
# bootstrap and install prerequisite packages

for y in sets-netbsd-$DIST/* ; do
safe_copy $y /
done

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

 echo "SIGN_PACKAGES=gpg" >> /usr/pkg/etc/mk.conf
 echo "SIGN_PACKAGES=gpg" >> /etc/mk.conf
  echo "GPG=/data/pkgsrc/pgpg" >> /usr/pkg/etc/pkg_install.conf
  echo "GPG_SIGN_AS=$SIGNING_KEY_ID" >> /usr/pkg/etc/pkg_install.conf
 cat /usr/pkg/etc/pkg_install.conf

echo "cloning pkgsrc"
mkdir -p /data
 cd /data
 git clone https://github.com/joyent/pkgsrc.git > /dev/null
cd pkgsrc && git checkout pkgsrc-$RELEASE > /dev/null
# git checkout trunk > /dev/null
echo "cloning pkgbuild"
cd /data
git clone https://github.com/joyent/pkgbuild.git > /dev/null


echo "installing prerequisites"
 pkgin -y in gnupg libtool-base alsa-lib unixodbc 
echo adding gtk and friends
 pkgin -y in gtk2+ libXext libX1 libXt libXtst pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto 
echo adding other library dependencies
 pkgin -y in nettle libffi pcre mysql-client-5.5 gdbm tiff freetype2 gcc49 autoconf bison gcc49-libs patch gmake digest openjdk8 digest nbpatch pkgvi pkgdiff pkg_alternatives pkgconf m4 
 pkgin -y in openjdk8
 pkgin -y in gtk2+
 pkgin -y in gtk2
 pkgin -y in atk
 pkgin -y in guile20
 pkgin -y in openjdk8
 pkgin -y fug
 pkgin -y fug
#cd /data/pkgsrc/bootstrap
#./bootstrap
# pkg_delete sqlite3 pkgin
# sed -e 's/always/never/' < /usr/pkg/etc/pkg_install.conf > /tmp/pki
# rm -f /usr/pkg/etc/pkg_install.conf
# mv /tmp/pki /usr/pkg/etc/pkg_install.conf
# echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /usr/pkg/etc/pkg_install.conf
echo "done installing prerequisites"
EOFF

copy_phase_1

echo starting build
ssh $SSHOPTS root@$HOST << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin
 mkdir -p /usr/pkg/etc/gnupg
 echo "$SIGNING_KEY_PASSWORD" | gpg --batch --yes --import /data/pkgsrc/signing_key.txt
 echo "$SIGNING_KEY_PASSWORD" | gpg --batch --yes --import /data/pkgsrc/public_signing_key.txt
 gpg --batch --import --no-default-keyring --keyring /usr/pkg/etc/gnupg/pkgsrc.gpg /data/pkgsrc/public_signing_key.txt
 gpg --list-secret-keys --keyid-format LONG
 gpg --list-keys --keyring /usr/pkg/etc/gnupg/pkgsrc.gpg --keyid-format LONG
 SIGNING_KEY_PASSWORD="$SIGNING_KEY_PASSWORD"
 export SIGNING_KEY_PASSWORD 
 GPG_TTY=$(tty)
 export GPG_TTY

 cd /data/pkgsrc
 gpatch -p1 < pkgsrc_lang.patch
 cd /data/pkgsrc/lang/openjdk8
 gpatch -p0 < openjdk8.patch
  cd /data/pkgsrc/lang
 tar xzvf $PKG-all.tar.gz
if [ "$DIST" = "6.1.5" ] ; then
  rm -rf pike8.0-GTK2
  rm -rf pike8.0-Image_SVG
else
pkgin -y in librsvg
fi
pkgin -y in libwebp
  cd /data/pkgsrc/lang
  rm $PKG-all.tar.gz
 (cd $PKG && $MAKE clean && $MAKE package && $MAKE install && pike --info) || exit 1 
  cd /data/pkgsrc/devel/glib2
  pike -x rsif "TOOL_DEPENDS" "#TOOL_DEPENDS" buildlink3.mk
#  make package
#  pkg_delete -f glib2
#  make install
  pkgin -y fug
  cd /data/pkgsrc/x11/fixesproto && make deinstall && make install
for x in $PKG-* ; do if [ -d \$x ]; then (cd \$x && $MAKE clean && $MAKE package && $MAKE install && (pike --info > ../\$x.info) && cd .. ) || break; fi; done 
  exit
EOFF
copy_packages_and_exit /data/pkgsrc/packages/All packages/NetBSD/$DIST/$PLATFORM/All
