#!/bin/sh
SPHINX_VERSION_REQ=5prealpha
SPHINXBASE_RELEASE=sphinxbase-${SPHINX_VERSION_REQ}
POCKETSPHINX_RELEASE=pocketsphinx-${SPHINX_VERSION_REQ}
export SPHINX_VERSION_REQ

SPHINXBASE_PKG=${SPHINXBASE_RELEASE}.tar.gz
POCKETSPHINX_PKG=${POCKETSPHINX}.tar.gz

#Check Sphinx libraries are in place
if [ ! -f `pwd`/cmusphinx/${SPHINXBASE_RELEASE}.tar.gz ]; then
	echo "Please follow the readme instrunctions on how to download ${SPHINXBASE_PKG}"
	exit 1
fi

if [ ! -f `pwd`/cmusphinx/${POCKETSPHINX_RELEASE}.tar.gz ]; then
	echo "Please follow the readme instrunctions on how to download ${POCKETSPHINX_PKG}"
	exit 1
fi

cd cmusphinx
rm -f build.log > /dev/null 2>&1

for SPHINX_PROJECT in ${SPHINXBASE_RELEASE} ${POCKETSPHINX_RELEASE}
do
	#Delete previous build directory if found
	if [ -d ${SPHINX_PROJECT} ]; then
		rm -rf ${SPHINX_PROJECT}
	fi
	tarfile=${SPHINX_PROJECT}.tar.gz
	echo "Decompressing ${tarfile}..."
	tar zxf $tarfile || exit 1
done

#Copy build scripts
cp -f ../ios-build-sphinxbase.sh ${SPHINXBASE_RELEASE}/
cp -f ../ios-build-pocketsphinx.sh ${POCKETSPHINX_RELEASE}/

#Compile SphinxBase
cd $SPHINXBASE_RELEASE
./ios-build-sphinxbase.sh || exit 1
cd ..
#Compile PocketSphinx
cd $POCKETSPHINX_RELEASE
./ios-build-pocketsphinx.sh || exit 1
cd ..

#rm -rf ../../../lib/*sphinx*
#rm -rf ../../../include/*sphinx*

cd $SPHINXBASE_RELEASE
echo
echo "Installing SphinxBase libraries..."
cp -f bin/arm64/lib/libsphinx*.a ../../../lib/sphinxbase/arm64/  &&
cp -f bin/armv7/lib/libsphinx*.a ../../../lib/sphinxbase/armv7/  &&
cp -f bin/armv7s/lib/libsphinx*.a ../../../lib/sphinxbase/armv7s/  &&
cp -f bin/i386/lib/libsphinx*.a ../../../lib/sphinxbase/i386/  &&
cp -f bin/x86_64/lib/libsphinx*.a ../../../lib/sphinxbase/x86_64/  &&
cp -f bin/libsphinxad.a ../../../lib/sphinxbase/  &&
cp -f bin/libsphinxbase.a ../../../lib/sphinxbase/ || exit 1
echo
echo "Installing SphinxBase header..."
cp -f include/sphinxbase/*.h ../../../include/sphinxbase/ &&
cp -f include/sphinx_config.h ../../../include/sphinxbase/ || exit 1
cd ..

cd $POCKETSPHINX_RELEASE
echo
echo "Installing PocketSphinx libraries..."
cp -f bin/arm64/lib/libpocketsphinx.a ../../../lib/pocketsphinx/arm64/ &&
cp -f bin/armv7/lib/libpocketsphinx.a ../../../lib/pocketsphinx/armv7/ &&
cp -f bin/armv7s/lib/libpocketsphinx.a ../../../lib/pocketsphinx/armv7s/ &&
cp -f bin/i386/lib/libpocketsphinx.a ../../../lib/pocketsphinx/i386/ &&
cp -f bin/x86_64/lib/libpocketsphinx.a ../../../lib/pocketsphinx/x86_64/ &&
cp -f bin/libpocketsphinx.a ../../../lib/pocketsphinx/ || exit 1
echo
echo "Installing PocketSphinx headers..."
cp -vf include/*.h ../../../include/pocketsphinx/ || exit 1

cd ..
echo Done
