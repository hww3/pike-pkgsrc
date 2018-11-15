#
# Copy and paste the lines below to install the 64-bit EL 7.x set.
#
BOOTSTRAP_TAR="bootstrap-trunk-x86_64-20170127.tar.gz"
#BOOTSTRAP_SHA="eb0d6911489579ca893f67f8a528ecd02137d43a"

#el6
BOOTSTRAP_SHA="dcb6128284e7e8529a8a770d55cf93d97550558c"

PKGSRC_REL=2017Q1
DIST=el6

# Download the bootstrap kit to the current directory.
curl -O https://pkgsrc.joyent.com/packages/Linux/$DIST/bootstrap/${BOOTSTRAP_TAR}

# Verify the SHA1 checksum.
echo "${BOOTSTRAP_SHA}  ${BOOTSTRAP_TAR}" >check-shasum
sha1sum -c check-shasum

# Install bootstrap kit to /usr/pkg
tar -zxpf ${BOOTSTRAP_TAR} -C /

 yum update -y
 yum install -y bzip2 ed gcc gcc-c++ git psmisc screen
 useradd -U -m -s /bin/bash -c "pbulk user" pbulk
 hostnamectl set-hostname pkgsrc-pbulk.local

PATH=/usr/pkg/bin:/usr/pkg/sbin:$PATH

 mkdir -p /data
 cd /data
 git clone https://github.com/joyent/pkgsrc.git
 git clone https://github.com/joyent/pkgbuild.git

/usr/pkg/bin/pkgin -y in libtool-base alsa-lib unixodbc libX11 libXext libX1 libXt libXtst pax kbproto xproto xcb-proto xextproto inputproto fixesproto recordproto
/usr/pkg/bin/pkgin -y in digest nbpatch pkgvi pkgdiff pkgconf m4 nettle libffi pcre mysql-client sqlite3 gdbm tiff freetype2 oracle-jdk8
 sed -e 's/always/never/' < /usr/pkg/etc/pkg_install.conf > /tmp/pki
 rm -f /usr/pkg/etc/pkg_install.conf
 mv /tmp/pki /usr/pkg/etc/pkg_install.conf
 echo "ACCEPTABLE_LICENSES= oracle-binary-code-license" >> /usr/pkg/etc/pkg_install.conf
IFS=' ' 
PKGS_TO_INSTALL='png-1.6.30 alsa-lib-1.1.4.1 oracle-jre8-8.0.131 oracle-jdk8-8.0.131'
PKGS_TO_REMOVE='png-1.6.30'
for x in $PKGS_TO_REMOVE ; do
  echo "removing $x"
  pkg_delete -f $x
done

 for x in $PKGS_TO_INSTALL ; do
  echo "installing $x"
  pkg_add -f http://bill.welliver.org/dist/pike/pkgsrc/Linux/$DIST/$PKGSRC_REL/x86_64/$x.tgz
 done
