#!/bin/sh

PKG=pike8.0
VER=`grep PIKE_VERSION= ports/pike8.0/version.mk | cut -f 2 -d '=' | tr '\t' ' ' | sed -e 's/^[ ]*//;s/[ ]*$//'`
PLATFORM=x86_64
SIGNING_KEY_ID=276FE0FA

stty -echo
echo Enter passphrase for signing key $SIGNING_KEY_ID
read a
stty echo

SIGNING_KEY_PASSWORD=$a

safe_copy()
{
  end=$#

  end=$((end - 1))

  until false ; do
  scp $SSHOPTS ${@:1:$end} root@$HOST:${!#} && break
  sleep 2
  done
}

fatal() 
{
  echo "FATAL: ${1}" 
  exit 1;
}

[[ -z $VER ]]  && fatal "Unable to find version for pike package build. aborting."

echo "Building a package for Pike $VER for OS $OS $RELEASE".
  cd ports
  tar czf ../$PKG-$$.tar.gz $PKG*
  cd ..


SSHOPTS="-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"
DATE=`date +%y%m%d%H%M`
HOST=$OS-$RELEASE-pkgbuild-$DATE

echo exporting secret key
echo "$SIGNING_KEY_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --armor --pinentry-mode loopback --export-secret-keys -o signing_key.txt$$ $SIGNING_KEY_ID 
echo "$SIGNING_KEY_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --armor --pinentry-mode loopback --export -o public_signing_key.txt$$ $SIGNING_KEY_ID 
echo preparing to build

copy_phase_1() 
{
sleep 50
#copy setup files
safe_copy signing_key.txt$$ /data/pkgsrc/signing_key.txt
safe_copy public_signing_key.txt$$ /data/pkgsrc/public_signing_key.txt
safe_copy pgpg /data/pkgsrc/pgpg
rm signing_key.txt$$
rm public_signing_key.txt$$
safe_copy openjdk8.patch /data/pkgsrc/lang/openjdk8
safe_copy pkgsrc_lang.patch /data/pkgsrc/
safe_copy $PKG-$$.tar.gz /data/pkgsrc/lang/$PKG-all.tar.gz
}

copy_packages_and_exit()
{
  INP_DESTDIR=$1
  OUP_DESTDIR=$2

  if [ -n "$OUP_DESTDIR" ] ; then
    DESTDIR=$OUP_DESTDIR
  else
    DESTDIR=packages/$OS/$RELEASE/$PLATFORM/All
  fi

  if [ -n "$INP_DESTDIR" ] ; then
    SRC_DESTDIR=$INP_DESTDIR
  else
    SRC_DESTDIR=/data/$DESTDIR
  fi
mkdir -p $DESTDIR
echo "scp $SSHOPTS root@$HOST:$SRC_DESTDIR/$PKG*-$VER.tgz $DESTDIR"
scp $SSHOPTS root@$HOST:$SRC_DESTDIR/$PKG*-$VER.tgz $DESTDIR
if [ -f $DESTDIR/$PKG-$VER.tgz ] ; then
  echo build successful.
  ls -l $DESTDIR/$PKG*-$VER.tgz
  echo deleting build host
  triton instance delete $HOST
else
  echo build failed. preserving host $HOST.
 exit 3
fi
rm $PKG-$$.tar.gz
}
