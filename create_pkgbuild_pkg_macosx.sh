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
 echo "SIGN_PACKAGES=gpg" >> /opt/pkg/etc/mk.conf
  echo "GPG=/data/pkgsrc/pgpg" >> /opt/pkg/etc/pkg_install.conf
  echo "GPG_SIGN_AS=$SIGNING_KEY_ID" >> /opt/pkg/etc/pkg_install.conf

sed -i -e 's/always/never/' /opt/pkg/etc/pkg_install.conf 
mkdir -p /data/packages/Darwin/trunk/x86_64/All
echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /opt/pkg/etc/pkg_install.conf
cat /opt/pkg/etc/pkg_install.conf
echo done installing prerequisites
EOFF

copy_phase_1

#copy setup files
echo copy setup files
safe_copy darwin_pkg/* /data/packages/Darwin/trunk/x86_64/All

echo starting build
ssh $SSHOPTS root@$HOST "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/pkg/bin:/opt/pkg/sbin:/data/pkgbuild/scripts run-sandbox osx-$RELEASE-$PLATFORM" << EOFF
 PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/pkg/bin:/opt/pkg/sbin
 mv /usr/bin/java /usr/bin/java.bak
 ln -s /data/pkgbuild /data/pbulk
 sed -i -e 's/https:/http:/'  /opt/pkg/etc/pkg_install.conf
 echo "SIGN_PACKAGES=gpg" >> /opt/pkg/etc/mk.conf

  echo "GPG_KEYRING_VERIFY=/opt/pkg/etc/gnupg/pkgsrc.gpg" > /opt/pkg/etc/pkg_install.conf
  echo "PKG_PATH=/data/packages/Darwin/trunk/x86_64/All;http://pkgsrc.joyent.com/packages/Darwin/trunk/x86_64/All" >> /opt/pkg/etc/pkg_install.conf
  echo "GPG=/data/pkgsrc/pgpg" >> /opt/pkg/etc/pkg_install.conf
  echo "GPG_SIGN_AS=$SIGNING_KEY_ID" >> /opt/pkg/etc/pkg_install.conf

 cd /data/pkgsrc
  pkg_add /data/packages/Darwin/trunk/x86_64/All/*
  pkg_delete sqlite3
  pkg_add pkgin
  echo "https://pkgsrc.joyent.com/packages/Darwin/trunk/x86_64/All/" >> /opt/pkg/etc/pkgin/repositories.conf
  pkgin -y up
  pkgin -y full-upgrade
  pkgin -y in gnupg

 echo "$SIGNING_KEY_PASSWORD" | /opt/pkg/bin/gpg --batch --yes --import /data/pkgsrc/signing_key.txt
 echo "$SIGNING_KEY_PASSWORD" | /opt/pkg/bin/gpg --batch --yes --import /data/pkgsrc/public_signing_key.txt
 /opt/pkg/bin/gpg --batch --import --no-default-keyring --keyring /opt/pkg/etc/gnupg/pkgsrc.gpg /data/pkgsrc/public_signing_key.txt
 /opt/pkg/bin/gpg --list-secret-keys --keyid-format LONG
 /opt/pkg/bin/gpg --list-keys --keyring /opt/pkg/etc/gnupg/pkgsrc.gpg --keyid-format LONG
 SIGNING_KEY_PASSWORD="$SIGNING_KEY_PASSWORD"
 export SIGNING_KEY_PASSWORD 
 GPG_TTY=$(tty)
 export GPG_TTY
  echo "pass: \$SIGNING_KEY_PASSWORD"
  git config --global http.sslVerify false
  cd /data/pkgsrc/lang
 tar xzvf pike8.0-all.tar.gz
  rm pike8.0-all.tar.gz
 JAVA_HOME=""
 export JAVA_HOME
 (cd pike8.0 && bmake clean package install && pike --info) || (cat /tmp/foo; exit 1)
  cd /data/pkgsrc/lang
for x in pike8.0-* ; do if [ -d \$x ]; then (cd \$x && bmake clean package install && (pike --info > ../\$x.info) && cd .. ) || break; fi; done 
exit

EOFF

copy_packages_and_exit

  vmrun stop "$VMIMAGE"
