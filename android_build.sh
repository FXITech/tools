#!/bin/bash
# Copyright (C) 2013 FXI Technologies AS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Build source code of the Android OS

EXPECTED_ARGS=1
ERROR_BARDARGS=128

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` ENV_FILE_PATH"
  exit $ERROR_BARDARGS
fi

ENV_FILE_PATH=$1
source $ENV_FILE_PATH

: ${ANDROID_TOOLCHAIN_URL:="http://releases.linaro.org/12.05/components/android/toolchain/4.6/android-toolchain-eabi-linaro-4.6-2012.05-1-2012-05-18_15-55-36-linux-x86.tar.bz2"}
: ${ANDROID_TOOLCHAIN_VERSION:="arm-linux-androideabi-gcc (Linaro GCC 4.7-2012.06) 4.7.1 20120531 (prerelease)"}
: ${ANDROID_TOOLCHAIN_MD5:="554c78e93ffbd33f54baf4c8b519e78b"}

check_toolchain_version () {
  CURRENT_VERSION=`${TARGET_TOOLS_PREFIX}gcc --version | head -1`
  if [ "${ANDROID_TOOLCHAIN_VERSION}" != "$CURRENT_VERSION" ]; then
    echo "Current version ( $CURRENT_VERSION ) is not valid version " \
      "for this build, please use: $ANDROID_TOOLCHAIN_VERSION"
    exit 1
  else
    echo "Current version: ${CURRENT_VERSION}"
  fi
}

check_toolchain_tarball_md5 () {
  ANDROID_TOOLCHAIN_TARBALL_PATH="${ANDROID_TOOLCHAIN_PATH}/${ANDROID_TOOLCHAIN_TARBALL}"
  CURRENT_MD5=`md5sum ${ANDROID_TOOLCHAIN_TARBALL_PATH} | awk '{print $1}'`
  if [ "$ANDROID_TOOLCHAIN_MD5" != "$CURRENT_MD5" ]; then
    echo "md5 verification faild"
    exit 1
  else
    echo "md5 verification success"
  fi
}

ANDROID_TOOLCHAIN_TARBALL=android-toolchain.tar.gz
ANDROID_TOOLCHAIN_DIR=$ANDROID_TOOLCHAIN_PATH/android-toolchain-eabi

if [ -d $ANDROID_TOOLCHAIN_DIR ]; then
  check_toolchain_version
else
  if [ -d $ANDROID_TOOLCHAIN_PATH ]; then
    pushd $ANDROID_TOOLCHAIN_PATH
    wget -O $ANDROID_TOOLCHAIN_TARBALL -c $ANDROID_TOOLCHAIN_URL
    check_toolchain_tarball_md5
    echo "Extracting toolchain ..."
    tar jxf $ANDROID_TOOLCHAIN_TARBALL
    popd
    check_toolchain_version
  else
    echo "$ANDROID_TOOLCHAIN_PATH does not exist"
    exit 1
  fi
fi

if [ -d "$ANDROID_SRC_PATH" ]; then
  cd $ANDROID_SRC_PATH
else
  echo "$ANDROID_SRC_PATH does not exist"
fi

make -j$JOBS_NUMBER USE_CCACHE=1 CCACHE_DIR=$CCACHE_PATH TARGET_BUILD_VARIANT=user HOST_CC=gcc-4.6 HOST_CXX=g++-4.6 HOST_CPP=cpp-4.6 TARGET_PRODUCT=cottoncandy TARGET_SIMULATOR=false TARGET_TOOLS_PREFIX=$TARGET_TOOLS_PREFIX $PHONY_TARGETS &> $LOGS_OUTPUT
