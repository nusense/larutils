#!/bin/bash

# build uboonecode and ubutil
# use mrb
# designed to work on Jenkins
# this is a proof of concept script

echo "uboonecode version: $UBOONE"
echo "base qualifiers: $QUAL"
echo "larsoft qualifiers: $LARSOFT_QUAL"
echo "build type: $BUILDTYPE"
echo "workspace: $WORKSPACE"

# Don't do ifdh build on macos.

#if uname | grep -q Darwin; then
#  if ! echo $QUAL | grep -q noifdh; then
#    echo "Ifdh build requested on macos.  Quitting."
#    exit
#  fi
#fi

# Get number of cores to use.

if [ `uname` = Darwin ]; then
  #ncores=`sysctl -n hw.ncpu`
  #ncores=$(( $ncores / 4 ))
  ncores=1
else
  ncores=`cat /proc/cpuinfo 2>/dev/null | grep -c -e '^processor'`
fi
if [ $ncores -lt 1 ]; then
  ncores=1
fi
echo "Building using $ncores cores."

# Environment setup, uses /grid/fermiapp or cvmfs.

echo "ls /cvmfs/uboone.opensciencegrid.org"
ls /cvmfs/uboone.opensciencegrid.org
echo

if [ `uname` = Darwin -a -f /grid/fermiapp/products/uboone/setup_uboone_bluearc.sh ]; then
  source /grid/fermiapp/products/uboone/setup_uboone_bluearc.sh || exit 1
elif [ -f /cvmfs/uboone.opensciencegrid.org/products/setup_uboone.sh ]; then
  if [ -x /cvmfs/grid.cern.ch/util/cvmfs-uptodate ]; then
    /cvmfs/grid.cern.ch/util/cvmfs-uptodate /cvmfs/uboone.opensciencegrid.org/products
  fi
  source /cvmfs/uboone.opensciencegrid.org/products/setup_uboone.sh || exit 1
else
  echo "No setup file found."
  exit 1
fi

# Use system git on macos.

if ! uname | grep -q Darwin; then
  setup git || exit 1
fi
setup gitflow || exit 1
# skip around a version of mrb that does not work on macOS

if [ `uname` = Darwin ]; then
  if [[ x`which mrb | grep v1_17_02` != x ]]; then
    unsetup mrb || exit 1
    setup mrb v1_16_02 || exit 1
  fi
fi

export MRB_PROJECT=uboone
echo "Mrb path:"
which mrb

set -x
rm -rf $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/temp || exit 1
mkdir -p $WORKSPACE/copyBack || exit 1
rm -f $WORKSPACE/copyBack/* || exit 1
cd $WORKSPACE/temp || exit 1
mrb newDev  -v $UBOONE -q $QUAL:$BUILDTYPE || exit 1

set +x
source localProducts*/setup || exit 1
echo "PRODUCTS=$PRODUCTS"

# some shenanigans so we can use getopt v1_1_6
if [ `uname` = Darwin ]; then
#  cd $MRB_INSTALL
#  curl --fail --silent --location --insecure -O http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 || \
#      { cat 1>&2 <<EOF
#ERROR: pull of http://scisoft.fnal.gov/scisoft/packages/getopt/v1_1_6/getopt-1.1.6-d13-x86_64.tar.bz2 failed
#EOF
#        exit 1
#      }
#  tar xf getopt-1.1.6-d13-x86_64.tar.bz2 || exit 1
  setup getopt v1_1_6  || exit 1
#  which getopt
fi

#set -x
cd $MRB_SOURCE  || exit 1
# make sure we get a read-only copy
mrb g -r -t $UBOONE uboonecode || exit 1

# Extract ubutil version from uboonecode product_deps
ubutil_version=`grep ubutil $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
echo "ubuitil version: $ubutil_version"
mrb g -r -t $ubutil_version ubutil || exit 1

# Extract uboonedata version from uboonecode product_deps (if any).
uboonedata_version=`grep uboonedata $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
echo "uboonedata version: $uboonedata_version"
if [ x$uboonedata_version != x ]; then
  mrb g -r -t $uboonedata_version uboonedata || exit 1
fi


cd $MRB_BUILDDIR || exit 1
mrbsetenv || exit 1
mrb b -j$ncores || exit 1
if uname | grep -q Linux; then
  cp /usr/lib64/libXmu.so.6 uboonecode/lib
fi
mrb mp -n uboone -- -j$ncores || exit 1

# add uboone_photon_propagation to the manifest.

manifest=uboone-*_MANIFEST.txt
if [ x$uboonedata_version != x ]; then
  uboone_photon_propagation_version=`grep uboone_photon_propagation $MRB_SOURCE/uboonedata/ups/product_deps | grep -v qualifier | awk '{print $2}'`
  uboone_photon_propagation_dot_version=`echo ${uboone_photon_propagation_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
fi
if [ x$uboone_photon_propagation_version != x ]; then
  echo "uboone_photon_propagation ${uboone_photon_propagation_version}       uboone_photon_propagation-${uboone_photon_propagation_dot_version}-noarch.tar.bz2" >>  $manifest
fi

# add uboone_data to the manifest.

manifest=uboone-*_MANIFEST.txt
uboone_data_version=`grep uboone_data $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
uboone_data_dot_version=`echo ${uboone_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
if [ x$uboone_data_version != x ]; then
  echo "uboone_data          ${uboone_data_version}       uboone_data-${uboone_data_dot_version}-noarch.tar.bz2" >>  $manifest
fi

# add uboone_example_data to the manifest.

manifest=uboone-*_MANIFEST.txt
uboone_example_data_version=`grep ^uboone_example_data $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
uboone_example_data_dot_version=`echo ${uboone_example_data_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
if [ x$uboone_example_data_version != x ]; then
  echo "uboone_example_data          ${uboone_example_data_version}       uboone_example_data-${uboone_example_data_dot_version}-noarch.tar.bz2" >>  $manifest
fi

# add uboonedaq_datatypes to the manifest

manifest=uboone-*_MANIFEST.txt
uboonedaq_datatypes_version=`grep uboonedaq_datatypes $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
uboonedaq_datatypes_dot_version=`echo ${uboonedaq_datatypes_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
os=`get-directory-name os`
plat=`get-directory-name platform`
qual=`echo $QUAL |  sed 's/:*noifdh:*//'`
if [ x$uboonedaq_datatypes_version != x ]; then
  echo "uboonedaq_datatypes  ${uboonedaq_datatypes_version}       uboonedaq_datatypes-${uboonedaq_datatypes_dot_version}-${os}-${plat}-${qual}-${BUILDTYPE}.tar.bz2" >>  $manifest
fi

# add swtrigger to the manifest

manifest=uboone-*_MANIFEST.txt
swtrigger_version=`grep swtrigger $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
swtrigger_dot_version=`echo ${swtrigger_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
os=`get-directory-name os`
plat=`get-directory-name platform`
qual=`echo $QUAL |  sed 's/:*noifdh:*//'`
if [ x$swtrigger_version != x ]; then
  echo "swtrigger            ${swtrigger_version}       swtrigger-${swtrigger_dot_version}-${os}-${plat}-${qual}-${BUILDTYPE}.tar.bz2" >>  $manifest
fi

# add larlite to the manifest

manifest=uboone-*_MANIFEST.txt
larlite_version=`grep larlite $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larlite_dot_version=`echo ${larlite_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
os=`get-directory-name os`
plat=`get-directory-name platform`
qual=`echo $QUAL |  sed 's/:*noifdh:*//'`
if [ x$larlite_version != x ]; then
  echo "larlite            ${larlite_version}       larlite-${larlite_dot_version}-${os}-${plat}-${qual}-${BUILDTYPE}.tar.bz2" >>  $manifest
fi

# add larcv to the manifest

manifest=uboone-*_MANIFEST.txt
larcv_version=`grep larcv $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larcv_dot_version=`echo ${larcv_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
os=`get-directory-name os`
plat=`get-directory-name platform`
qual=`echo $QUAL |  sed 's/:*noifdh:*//'`
if [ x$larcv_version != x ]; then
  echo "larcv            ${larcv_version}       larcv-${larcv_dot_version}-${os}-${plat}-${qual}-${BUILDTYPE}.tar.bz2" >>  $manifest
fi

# add larbatch to the manifest.

manifest=uboone-*_MANIFEST.txt
larbatch_version=`grep larbatch $MRB_SOURCE/ubutil/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larbatch_dot_version=`echo ${larbatch_version} | sed -e 's/_/./g' | sed -e 's/^v//'`
if [ x$larbatch_version != x ]; then
  echo "larbatch             ${larbatch_version}       larbatch-${larbatch_dot_version}-noarch.tar.bz2" >>  $manifest
fi

# Extract larsoft version from product_deps.

larsoft_version=`grep larsoft $MRB_SOURCE/uboonecode/ups/product_deps | grep -v qualifier | awk '{print $2}'`
larsoft_dot_version=`echo ${larsoft_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

# Extract flavor.

flvr=''
if uname | grep -q Darwin; then
  flvr=`ups flavor -2`
else
  flvr=`ups flavor -4`
fi

# Construct name of larsoft manifest.

larsoft_hyphen_qual=`echo $LARSOFT_QUAL | tr : - | sed 's/-noifdh//'`
larsoft_manifest=larsoft-${larsoft_dot_version}-${flvr}-${larsoft_hyphen_qual}-${BUILDTYPE}_MANIFEST.txt
echo "Larsoft manifest:"
echo $larsoft_manifest
echo

# Fetch laraoft manifest from scisoft and append to uboonecode manifest.
# Filter out larbatch because we already added that.

curl --fail --silent --location --insecure http://scisoft.fnal.gov/scisoft/bundles/larsoft/${larsoft_version}/manifest/${larsoft_manifest} | grep -v larbatch >> $manifest || exit 1

# Special handling of noifdh builds goes here.

if echo $QUAL | grep -q noifdh; then

  if uname | grep -q Darwin; then

    # If this is a macos build, then rename the manifest to remove noifdh qualifier in the name

    noifdh_manifest=`echo $manifest | sed 's/-noifdh//'`
    mv $manifest $noifdh_manifest

  else

    # Otherwise (for slf builds), delete the manifest entirely.

    rm -f $manifest

  fi
fi

# Save artifacts.

mv *.bz2  $WORKSPACE/copyBack/ || exit 1
manifest=uboone-*_MANIFEST.txt
if [ -f $manifest ]; then
  mv $manifest  $WORKSPACE/copyBack/ || exit 1
fi
cp $MRB_BUILDDIR/uboonecode/releaseDB/*.html $WORKSPACE/copyBack/
ls -l $WORKSPACE/copyBack/
cd $WORKSPACE || exit 1
rm -rf $WORKSPACE/temp || exit 1
set +x

exit 0
