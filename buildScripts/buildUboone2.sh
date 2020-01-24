#!/bin/bash

# build uboonecode and uboone suite packages.
# uses buildFW
# designed to work on Jenkins

# Extract set qualifier from $LARSOFT_QUAL (we don't care about anything else in $LARSOFT_QUAL).

SQUAL=`echo $LARSOFT_QUAL | tr : '\n' | grep ^s`

echo "uboonecode version: $VERSION"
echo "base qualifiers: $QUAL"
echo "set qualifier: $SQUAL"
echo "build labels: $LABEL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

if [ x$LABEL = xnull ]; then
  unset LABEL
fi

# Create area for biuld artifacts.
rm -rf $WORKSPACE/copyBack
mkdir -p $WORKSPACE/copyBack || exit 1

# Check for unsupported combinations of base qualifier, OS, and build label.
if [[ `uname -s` == Darwin ]] && [[ $QUAL == e* ]]; then
  echo "${QUAL} build not supported on `uname -s`"
  echo "${QUAL} build not supported on `uname -s`" > $WORKSPACE/copyBack/skipping_build
  exit 0
fi
if [[ `uname -s` == Darwin ]] && [[ x$LABEL == xpy2 ]]; then
  echo "Python 2 build not supported on `uname -s`"
  echo "Python 2 build not supported on `uname -s`" > $WORKSPACE/copyBack/skipping_build
  exit 0
fi
if [[ `uname -s` == Linux ]] && [[ `lsb_release -rs` == 6* ]] && [[ x$LABEL == x ]] && [[ $QUAL != e17 ]] && [[ $QUAL != c2 ]]; then
  echo "Python 3 build not supported on SL6"
  echo "Python 3 build not supported on SL6" > $WORKSPACE/copyBack/skipping_build
  exit 0
fi

# Create build directory and go there.
blddir=${WORKSPACE}/build
logdir=${WORKSPACE}/log
rm -rf $blddir
rm -rf $logdir
mkdir -p $blddir || exit 1
mkdir -p $logdir || exit 1
cd $blddir || exit 1

# Fetch buildFW script.
echo "Fetching buildFW."
curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/bundles/tools/buildFW || exit 1
chmod +x buildFW

# Do build.
echo
echo "Begin build."
echo
if [ x$LABEL = x ]; then
  ./buildFW -t -b $QUAL -s $SQUAL $blddir $BUILDTYPE uboone-$VERSION || \
  { mv *.log $logdir
    exit 1
  }
else
  ./buildFW -t -b $QUAL -s $SQUAL -l $LABEL $blddir $BUILDTYPE uboone-$VERSION || \
  { mv *.log $logdir
    exit 1
  }
fi

# Save log files.

mv *.log $logdir || exit 1

# Save artifacts.

mv ub*.bz2  $WORKSPACE/copyBack/ || exit 1
mv larlite*.bz2  $WORKSPACE/copyBack/ || exit 1
mv larcv*.bz2  $WORKSPACE/copyBack/ || exit 1
mv swtrigger*.bz2  $WORKSPACE/copyBack/ || exit 1
mv *.txt $WORKSPACE/copyBack/ || exit 1
mv wcp*.bz2  $WORKSPACE/copyBack/ || echo "No wcp tarball"

# Clean up.

cd $WORKSPACE || exit 1
rm -rf $blddir || exit 1

exit 0
