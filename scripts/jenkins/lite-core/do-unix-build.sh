#!/bin/bash -ex

# Global define
PRODUCT=${1}
VERSION=${2}
BLD_NUM=${3}

mkdir -p ${WORKSPACE}/build_release ${WORKSPACE}/build_debug

case "${OSTYPE}" in
    darwin*)  OS="macosx" 
              PKG_CMD='zip -r'
              PKG_TYPE='zip'
              PROP_FILE=${WORKSPACE}/publish.prop
              if [[ ${TVOS} == 'true' ]]; then
                  OS="macosx-tvos"
                  BUILD_TVOS_REL_TARGET='build_tvos_release'
                  BUILD_TVOS_DEBUG_TARGET='build_tvos_debug'
                  PROP_FILE=${WORKSPACE}/publish_tvos.prop
                  mkdir -p ${WORKSPACE}/${BUILD_TVOS_REL_TARGET} ${WORKSPACE}/${BUILD_TVOS_DEBUG_TARGET}
              fi
              if [[ ${IOS} == 'true' ]]; then
                  OS="macosx-ios"
                  BUILD_IOS_REL_TARGET='build_ios_release'
                  BUILD_IOS_DEBUG_TARGET='build_ios_debug'
                  PROP_FILE=${WORKSPACE}/publish_ios.prop
                  mkdir -p ${WORKSPACE}/${BUILD_IOS_REL_TARGET} ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
              fi;;
    linux*)   OS="linux"
              PKG_CMD='tar czf'
              PKG_TYPE='tar.gz'
              PROP_FILE=${WORKSPACE}/publish.prop;;
    *)        echo "unknown: $OSTYPE"
              exit 1;;
esac
# Global define end

if [[ ${TVOS} == 'true' ]]; then
    echo "====  Building tvos Release binary  ==="
    cd ${WORKSPACE}/${BUILD_TVOS_REL_TARGET}
    xcodebuild -project  ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Release -derivedDataPath tvos -scheme "LiteCore dylib" -sdk appletvos
    xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Release -derivedDataPath tvos -scheme "LiteCore dylib" -sdk appletvsimulator
    lipo -create tvos/Build/Products/Release-appletvos/libLiteCore.dylib tvos/Build/Products/Release-appletvsimulator/libLiteCore.dylib -output ${WORKSPACE}/${BUILD_TVOS_REL_TARGET}/libLiteCore.dylib
    cd ${WORKSPACE}
elif [[ ${IOS} == 'true' ]]; then
    echo "====  Building ios Release binary  ==="
    cd ${WORKSPACE}/${BUILD_IOS_REL_TARGET}
    xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Release -derivedDataPath ios -scheme "LiteCore dylib" -sdk iphoneos BITCODE_GENERATION_MODE=bitcode CODE_SIGNING_ALLOWED=NO
    xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Release -derivedDataPath ios -scheme "LiteCore dylib" -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
    lipo -create ios/Build/Products/Release-iphoneos/libLiteCore.dylib ios/Build/Products/Release-iphonesimulator/libLiteCore.dylib -output ${WORKSPACE}/${BUILD_IOS_REL_TARGET}/libLiteCore.dylib
    cd ${WORKSPACE}
else
    if [[ "${OS}" == 'linux' ]]; then
        BUILD_SQLITE='-DLITECORE_BUILD_SQLITE=1'
    else
        BUILD_SQLITE=''
    fi
    echo "====  Building macosx/linux Release binary  ==="
    cd ${WORKSPACE}/build_release
    cmake -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=RelWithDebInfo ${BUILD_SQLITE}  ..
    make -j8
    make install
    if [[ -z "${SKIP_TESTS}" ]]; then
        chmod 777 ${WORKSPACE}/couchbase-lite-core/build_cmake/scripts/test_unix.sh
        cd ${WORKSPACE}/build_release/couchbase-lite-core && ../../couchbase-lite-core/build_cmake/scripts/test_unix.sh
    fi
    cd ${WORKSPACE}
fi

if [[ "${OS}" == "macosx" ]] || [[ "${OS}" ==  "macosx-tvos" ]] || [[ "${OS}" == "macosx-ios" ]]
then
    if [[ ${TVOS} == 'true' ]]; then
        echo "====  Building tvos Debug binary  ==="
        cd ${WORKSPACE}/${BUILD_TVOS_DEBUG_TARGET}
        xcodebuild -project  ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Debug -derivedDataPath tvos -scheme "LiteCore dylib" -sdk appletvos
        xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Debug -derivedDataPath tvos -scheme "LiteCore dylib" -sdk appletvsimulator
        lipo -create tvos/Build/Products/Debug-appletvos/libLiteCore.dylib tvos/Build/Products/Debug-appletvsimulator/libLiteCore.dylib -output ${WORKSPACE}/${BUILD_TVOS_DEBUG_TARGET}/libLiteCore.dylib
        cd ${WORKSPACE}
    elif [[ ${IOS} == 'true' ]]; then
        echo "====  Building ios Debug binary  ==="
        cd ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
        xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Debug -derivedDataPath ios -scheme "LiteCore dylib" -sdk iphoneos BITCODE_GENERATION_MODE=bitcode CODE_SIGNING_ALLOWED=NO
        xcodebuild -project ${WORKSPACE}/couchbase-lite-core/Xcode/LiteCore.xcodeproj -configuration Debug -derivedDataPath ios -scheme "LiteCore dylib" -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
        lipo -create ios/Build/Products/Debug-iphoneos/libLiteCore.dylib ios/Build/Products/Debug-iphonesimulator/libLiteCore.dylib -output ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}/libLiteCore.dylib
        cd ${WORKSPACE}
    else
        if [[ "${OS}" == 'linux' ]]; then
            BUILD_SQLITE='-DLITECORE_BUILD_SQLITE=1'
        else
            BUILD_SQLITE=''
        fi
        echo "====  Building macosx/linux Debug binary  ==="
        cd ${WORKSPACE}/build_debug/
        cmake -DCMAKE_INSTALL_PREFIX=`pwd`/install -DCMAKE_BUILD_TYPE=Debug ${BUILD_SQLITE} ..
        make -j8
        make install
        cd ${WORKSPACE}/build_debug/couchbase-lite-core && ../../couchbase-lite-core/build_cmake/scripts/test_unix.sh
        cd ${WORKSPACE}
    fi
fi

VERSION=$(cd "${WORKSPACE}/couchbase-lite-core" && git rev-parse HEAD)

# Create zip package
for FLAVOR in release debug;
do
    if [[ "${FLAVOR}" == 'debug' && "${OS}" == 'linux' ]]
    then
        continue
    fi

    PACKAGE_NAME=${PRODUCT}-${OS}-${VERSION}-${FLAVOR}.${PKG_TYPE}
    echo
    echo  "=== Creating ${WORKSPACE}/${PACKAGE_NAME} package ==="
    echo

    if [[ "${FLAVOR}" == 'debug' ]]
    then
        if [[ ${TVOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_TVOS_DEBUG_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} libLiteCore.dylib
            cd ${WORKSPACE}
            DEBUG_TVOS_PKG_NAME=${PACKAGE_NAME}
        elif [[ ${IOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_IOS_DEBUG_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} libLiteCore.dylib
            cd ${WORKSPACE}
            DEBUG_IOS_PKG_NAME=${PACKAGE_NAME}
        else
            DEBUG_PKG_NAME=${PACKAGE_NAME}
            cd ${WORKSPACE}/build_${FLAVOR}/install
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
            cd ${WORKSPACE}
        fi
    else
        if [[ ${TVOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_TVOS_REL_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} libLiteCore.dylib
            cd ${WORKSPACE}
            RELEASE_TVOS_PKG_NAME=${PACKAGE_NAME}
        elif [[ ${IOS} == 'true' ]]; then
            cd ${WORKSPACE}/${BUILD_IOS_REL_TARGET}
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} libLiteCore.dylib
            cd ${WORKSPACE}
            RELEASE_IOS_PKG_NAME=${PACKAGE_NAME}
        else
            RELEASE_PKG_NAME=${PACKAGE_NAME}
            cd ${WORKSPACE}/build_${FLAVOR}/install
            ${PKG_CMD} ${WORKSPACE}/${PACKAGE_NAME} *
            cd ${WORKSPACE}
        fi
    fi
done

# Create Nexus publishing prop file
cd ${WORKSPACE}
echo "PRODUCT=${PRODUCT}"  >> ${PROP_FILE}
echo "BLD_NUM=${BLD_NUM}"  >> ${PROP_FILE}
echo "VERSION=${VERSION}" >> ${PROP_FILE}
echo "PKG_TYPE=${PKG_TYPE}" >> ${PROP_FILE}
if [[ ${TVOS} == 'true' ]]; then
    echo "DEBUG_TVOS_PKG_NAME=${DEBUG_TVOS_PKG_NAME}" >> ${PROP_FILE}
    echo "RELEASE_TVOS_PKG_NAME=${RELEASE_TVOS_PKG_NAME}" >> ${PROP_FILE}
elif [[ ${IOS} == 'true' ]]; then
    echo "DEBUG_IOS_PKG_NAME=${DEBUG_IOS_PKG_NAME}" >> ${PROP_FILE}
    echo "RELEASE_IOS_PKG_NAME=${RELEASE_IOS_PKG_NAME}" >> ${PROP_FILE}
else
    echo "DEBUG_PKG_NAME=${DEBUG_PKG_NAME}" >> ${PROP_FILE}
    echo "RELEASE_PKG_NAME=${RELEASE_PKG_NAME}" >> ${PROP_FILE}
fi

echo  
echo  "=== Created ${WORKSPACE}/${PROP_FILE} ==="
echo

cat ${PROP_FILE}
