#!/bin/sh

SCRATCH="scratch"
DEST=`pwd`/"bin"

ARCHS="arm64 armv7 armv7s x86_64 i386"

if [ "$*" ]
then
	ARCHS="$*"
fi

if [ "${SPHINX_VERSION_REQ}" != "" ]; then
	SPHINX_PKG_SUFFIX="-${SPHINX_VERSION_REQ}"
fi

CWD=`pwd`

for ARCH in $ARCHS
do
	SPHINXBASE_DIR=`pwd`/../sphinxbase${SPHINX_VERSION_SUFFIX}/bin/$ARCH
	echo "building $ARCH..."
	mkdir -p "$SCRATCH/$ARCH"
	cd "$SCRATCH/$ARCH"

	MIN_IOS_VERSION="8.0"
	if [[ "${ARCH}" == "arm64" || "${ARCH}" == "x86_64" ]]; then
            MIN_IOS_VERSION="7.0" # 7.0 as this is the minimum for these architectures
	fi

	if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
	then
	    PLATFORM="iPhoneSimulator"
	    IOS_CFLAGS="-arch $ARCH -mios-simulator-version-min=$MIN_IOS_VERSION"
	else
	    PLATFORM="iPhoneOS"
	    IOS_CFLAGS="-arch $ARCH -mios-version-min=$MIN_IOS_VERSION -fembed-bitcode"
	fi	

	HOST_TYPE="${ARCH}-apple-darwin"
	if [ "${ARCH}" == "arm64" ]; then
        # Fix unknown type for arm64 cpu (which is aarch64)
	    HOST_TYPE="aarch64-apple-darwin"
	fi

	export DEVELOPER=`xcode-select --print-path`
	export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${IPHONE_SDK}.sdk"
	export CC=`xcrun -find clang`
	export LD=`xcrun -find ld`
	export CFLAGS="-O3 ${IOS_CFLAGS} -isysroot ${SDKROOT}"
	export LDFLAGS="${IOS_CFLAGS} -isysroot ${SDKROOT}"
	export CPPFLAGS="${CFLAGS}"

	$CWD/configure \
	    --host="${HOST_TYPE}" \
	    --prefix="$DEST/$ARCH" \
	    --without-lapack \
	    --without-python \
	    --with-sphinxbase="$SPHINXBASE_DIR" \
	|| exit 1

	make -j3 install || exit 1
	cd $CWD
done

PROJECT=sphinxbase

if [ ! "$*" ]
then
	LIPO_ARGS="-output $DEST/lib$PROJECT.a"
	for ARCH in $ARCHS
	do
		LIPO_ARGS="$LIPO_ARGS $DEST/$ARCH/lib/lib$PROJECT.a"
	done
	lipo -create $LIPO_ARGS || exit 1
fi
# libsphinxad
if [ ! "$*" ]
then
	LIPO_ARGS="-output $DEST/libsphinxad.a"
	for ARCH in $ARCHS
	do
		LIPO_ARGS="$LIPO_ARGS $DEST/$ARCH/lib/libsphinxad.a"
	done
	lipo -create $LIPO_ARGS || exit 1
fi

echo Done
