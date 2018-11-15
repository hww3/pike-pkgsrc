#!/bin/sh

OS=Linux
DIST=el$1
RELEASE=trunk

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

. pkgsrc_base.sh

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

 pkg_add gnupg gtk2+ gtk2 gobject-introspection libtool-base flex giflib alsa-lib unixodbc libX11 libXext libX1 libXt libXtst pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto
 pkg_add nettle libffi pcre unixodbc mysql-client gdbm tiff freetype2 gcc49 autoconf bison gcc49-libs patch gmake digest openjdk8 digest nbpatch pkgvi pkgdiff pkgconf m4 oracle-jdk8
 sed -i -e 's/always/never/' /usr/pkg/etc/pkg_install.conf
 echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /usr/pkg/etc/pkg_install.conf
EOFF

copy_phase_1

#copy setup files
#ssh $SSHOPTS root@$HOST "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin:/data/pkgbuild/scripts run-sandbox $DIST-$RELEASE-$PLATFORM" << EOFF
ssh $SSHOPTS root@$HOST << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/pkg/sbin

 echo "SIGN_PACKAGES=gpg" >> /usr/pkg/etc/mk.conf
 echo "GPG=/data/pkgsrc/pgpg" >> /usr/pkg/etc/pkg_install.conf
 echo "GPG_SIGN_AS=$SIGNING_KEY_ID" >> /usr/pkg/etc/pkg_install.conf
 cat /usr/pkg/etc/pkg_install.conf

 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/png-1.6.30.tgz
 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/oracle-jre8-8.0.131.tgz
 pkg_add http://bill.welliver.org/dist/pike/pkgsrc/$OS/$DIST/$RELEASE/$PLATFORM/oracle-jdk8-8.0.131.tgz

 pkg_delete libarchive
pkg_add pkgin
 pkgin -y up
 pkgin -y fug
 pkgin -y in gnupg

 mkdir -p /usr/pkg/etc/gnupg

 echo "$SIGNING_KEY_PASSWORD" | /usr/pkg/bin/gpg --batch --yes --import /data/pkgsrc/signing_key.txt
 echo "$SIGNING_KEY_PASSWORD" | /usr/pkg/bin/gpg --batch --yes --import /data/pkgsrc/public_signing_key.txt
 /usr/pkg/bin/gpg --batch --import --no-default-keyring --keyring /usr/pkg/etc/gnupg/pkgsrc.gpg /data/pkgsrc/public_signing_key.txt
 /usr/pkg/bin/gpg --list-secret-keys --keyid-format LONG
 /usr/pkg/bin/gpg --list-keys --keyring /usr/pkg/etc/gnupg/pkgsrc.gpg --keyid-format LONG
 SIGNING_KEY_PASSWORD="$SIGNING_KEY_PASSWORD"
 export SIGNING_KEY_PASSWORD 
 GPG_TTY=$(tty)
 export GPG_TTY

 pkg_delete -f sqlite3 pkgin

 cd /data/pkgsrc/databases/sqlite3 && bmake reinstall
 pkg_add pkgin

 cd /data/pkgsrc
 gpatch -p1 < pkgsrc_lang.patch
 cd /data/pkgsrc/lang/openjdk8
 gpatch -p0 < openjdk8.patch
 cd /data/pkgsrc/lang
 tar xzvf pike8.0-all.tar.gz
#cd /data/pkgsrc/graphics/librsvg && bmake deinstall install
pkgin -y in libwebp
# cd /data/pkgsrc/graphics/libwebp && bmake deinstall install
  cd /data/pkgsrc/lang
  rm -rf pike8.0-GTK2
  rm -rf pike8.0-Image_SVG
 # rm -rf pike8.0-Image_WebP
  rm $PKG-all.tar.gz
 (cd $PKG && bmake clean package install && pike --info) || exit 1 
  cd /data/pkgsrc/lang
for x in $PKG-* ; do if [ -d \$x ]; then (cd \$x && bmake clean package install && (pike --info > ../\$x.info) && cd .. ) || break; fi; done 
  exit
EOFF

copy_packages_and_exit /data/pkgsrc/packages/All packages/$OS/$DIST/$RELEASE/$PLATFORM/All

