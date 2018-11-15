#!/bin/sh

OS=Linux
PKG=pike8.0
DIST=el$1
VER=`grep PIKE_VERSION= ports/pike8.0/version.mk | cut -f 2 -d '=' | tr '\t' ' ' | sed -e 's/^[ ]*//;s/[ ]*$//'`
RELEASE=trunk
PLATFORM=x86_64

BOOTSTRAP_TAR="bootstrap-trunk-x86_64-20170127.tar.gz"

case "$DIST" in
  el6)
#el6
BOOTSTRAP_SHA="dcb6128284e7e8529a8a770d55cf93d97550558c"
IMAGE="centos-6"
;;
  el7)
#el7
BOOTSTRAP_SHA="eb0d6911489579ca893f67f8a528ecd02137d43a"
IMAGE="centos-7"
PKGSRC_REL=$RELEASE
;;
  *)
    echo need a valid centos version. "$DIST" not valid.
    echo "usage: $0 6|7"
    exit 1;
  ;;
esac

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

triton create -w -N external -n $HOST $IMAGE sample-1G || exit 1
sleep 40
# bootstrap and install prerequisite packages
ssh $SSHOPTS root@$HOST << EOFF

  yum update -y
  yum install -y tar bzip2 ed gcc gcc-c++ git psmisc screen
  useradd -U -m -s /bin/bash -c "pbulk user" pbulk

  echo downloading pkgsrc bootstrap from https://pkgsrc.joyent.com/packages/Linux/$DIST/bootstrap/$BOOTSTRAP_TAR
  # Download the bootstrap kit to the current directory.
  cd / && curl -O https://pkgsrc.joyent.com/packages/Linux/$DIST/bootstrap/$BOOTSTRAP_TAR

  # Verify the SHA1 checksum.
  echo "${BOOTSTRAP_SHA}  ${BOOTSTRAP_TAR}" >check-shasum
  sha1sum -c check-shasum

  # Install bootstrap kit to /usr/pkg
  cd / 
  tar zxpf ${BOOTSTRAP_TAR}

  PATH=/usr/pkg/bin:/usr/pkg/sbin:$PATH

 mkdir -p /data
 cd /data
 git clone https://github.com/joyent/pkgsrc.git
 git clone https://github.com/joyent/pkgbuild.git

 pkg_add gtk2+ gtk2 gobject-introspection libtool-base flex giflib alsa-lib unixodbc libX11 libXext libX1 libXt libXtst pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto
 pkg_add nettle libffi pcre unixodbc mysql-client gdbm tiff freetype2 gcc49 autoconf bison gcc49-libs patch gmake digest openjdk8 digest nbpatch pkgvi pkgdiff pkgconf m4 oracle-jdk8
 pkg_delete sqlite3 pkgin
 sed -e 's/always/never/' < /usr/pkg/etc/pkg_install.conf > /tmp/pki
 rm -f /usr/pkg/etc/pkg_install.conf
 mv /tmp/pki /usr/pkg/etc/pkg_install.conf
 echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /usr/pkg/etc/pkg_install.conf
IFS=' ' 
PKGS_TO_INSTALL='png-1.6.30 alsa-lib-1.1.4.1 oracle-jre8-8.0.131 oracle-jdk8-8.0.131'
 pkg_delete -f png
 for x in $PKGS_TO_INSTALL ; do
  echo "installing $x"
  pkg_add -f http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/$x.tgz
 done

EOFF

#copy setup files
scp $SSHOPTS openjdk8.patch root@$HOST:/data/pkgsrc/lang/openjdk8
scp $SSHOPTS pkgsrc_lang.patch root@$HOST:/data/pkgsrc/
scp $SSHOPTS $PKG-$$.tar.gz root@$HOST:/data/pkgsrc/lang/$PKG-all.tar.gz
#ssh $SSHOPTS root@$HOST "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin:/data/pkgbuild/scripts run-sandbox $DIST-$RELEASE-$PLATFORM" << EOFF
ssh $SSHOPTS root@$HOST << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin
 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/png-1.6.30.tgz
 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/oracle-jre8-8.0.131.tgz
 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/oracle-jdk8-8.0.131.tgz
 cd /data/pkgsrc
 gpatch -p1 < pkgsrc_lang.patch
 cd /data/pkgsrc/lang/openjdk8
 gpatch -p0 < openjdk8.patch
 cd /data/pkgsrc/lang
 tar xzvf pike8.0-all.tar.gz
 cd /data/pkgsrc/graphics/librsvg && bmake deinstall install
 cd /data/pkgsrc/graphics/libwebp && bmake deinstall install
  cd /data/pkgsrc/lang
 tar xzvf $PKG-all.tar.gz
EOFF
PKGFILE=$PKG-$VER.tgz
echo ssh $SSHOPTS root@$HOST
rm $PKG-$$.tar.gz
