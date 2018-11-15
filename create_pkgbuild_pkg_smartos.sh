#!/bin/sh

OS=SmartOS
RELEASE=2017Q4
#image for pkgbuild
#IMAGE="pkgbuild@16.4.1"
#IMAGE="pkgbuild@17.4.0"
IMAGE="pkgbuild@18.2.0"

. pkgsrc_base.sh

triton create -w -N external -n $HOST $IMAGE sample-1G || exit 1

copy_phase_1

ssh $SSHOPTS root@$HOST "source /root/.profile && run-sandbox $RELEASE-$PLATFORM" << EOFF
 source /root/.profile
 echo "SIGN_PACKAGES=gpg" >> /opt/local/etc/mk.conf
  echo "GPG=/data/pkgsrc/pgpg" >> /opt/local/etc/pkg_install.conf
  echo "GPG_SIGN_AS=$SIGNING_KEY_ID" >> /opt/local/etc/pkg_install.conf
 cat /opt/local/etc/pkg_install.conf
 cd /data/pkgsrc
 git pull
 cd /data/pkgbuild
 git pull
 cd /data/pkgsrc/lang
 tar xzvf pike8.0-all.tar.gz
 pkg_add gnupg patch flex gmake autoconf giflib openjdk8 unixodbc digest nbpatch pkgvi pkgdiff pkgconf m4 nettle libffi pcre mysql-client gdbm tiff gtk2+ libwebp libsvg freetype2 gcc49 gcc49-libs
 pkg_delete pkgin sqlite3
 echo "$SIGNING_KEY_PASSWORD" | /opt/local/bin/gpg --batch --yes --import /data/pkgsrc/signing_key.txt
 echo "$SIGNING_KEY_PASSWORD" | /opt/local/bin/gpg --batch --yes --import /data/pkgsrc/public_signing_key.txt
 /opt/local/bin/gpg --batch --import --no-default-keyring --keyring /opt/local/etc/gnupg/pkgsrc.gpg /data/pkgsrc/public_signing_key.txt
 /opt/local/bin/gpg --list-secret-keys --keyid-format LONG
 /opt/local/bin/gpg --list-keys --keyring /opt/local/etc/gnupg/pkgsrc.gpg --keyid-format LONG
 SIGNING_KEY_PASSWORD="$SIGNING_KEY_PASSWORD"
 export SIGNING_KEY_PASSWORD 
 GPG_TTY=$(tty)
 export GPG_TTY
 cd /data/pkgsrc/
 gpatch -p1 < pkgsrc_lang.patch
 cd /data/pkgsrc/lang/openjdk8
 gpatch -p0 < openjdk8.patch
 cd /data/pkgsrc/graphics/librsvg && bmake deinstall install
 cd /data/pkgsrc/graphics/libwebp && bmake deinstall install
  cd /data/pkgsrc/lang
 tar xzvf $PKG-all.tar.gz
  rm $PKG-all.tar.gz
 (cd $PKG && bmake clean package install && pike --info) || exit 1 
  cd /data/pkgsrc/lang
for x in $PKG-* ; do if [ -d \$x ]; then (cd \$x && bmake mdi clean package install && (pike --info > ../\$x.info) && cd .. ) || break; fi; done 
  exit
EOFF

copy_packages_and_exit
