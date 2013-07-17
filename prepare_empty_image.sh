#!/bin/bash
#
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
#
# Description:
# Prepare empty Android image for Cotton Candy

command -v kpartx >/dev/null 2>&1 || { echo >&2 "I require kpartx but it's not installed. Aborting."; exit 1; }
command -v parted >/dev/null 2>&1 || { echo >&2 "I require parted but it's not installed. Aborting."; exit 1; }

# Read human readable size and convert it to bytes
# Usage: convert_to_bytes SIZE
# SIZE - Human readbale size like: 1T, 1G, 1M, 1K
convert_to_bytes () {
  substitute_t_by_kg='s/t/kg/i'
  substitute_g_by_km='s/g/km/i'
  substitute_m_by_kk='s/m/kk/i'
  substitute_k_by_1024='s/k/*1024/ig'
  remove_b='s/b//i'
  SED_REG_EXP="${substitute_t_by_kg};${substitute_g_by_km};${substitute_m_by_kk};${substitute_k_by_1024};${remove_b}"
  in_bytes=`echo $1 | sed -e $SED_REG_EXP`
  echo $((in_bytes))
}


# Print error message and quit the script
# Usage: die ERROR_MESSAGE
# ERROR_MESSAGE - string
die () {
  echo $1 >&2
  exit 1
}

# Set defaults:
: ${IMAGE_SIZE:="7600M"}
: ${ROOT_SIZE:="50M"}
: ${SYSTEM_SIZE:="1G"}
: ${CACHE_SIZE:="500MB"}
: ${DATA_SIZE:="3G"}
: ${BLOCK_SIZE:=512}

IMAGE_SIZE_IN_BYTES=`convert_to_bytes $IMAGE_SIZE`
ERROR_BARDARGS=128

# Partition table:
ROOT_SIZE_IN_BYTES=`convert_to_bytes $ROOT_SIZE`
ROOT_START=$((1024*1024/BLOCK_SIZE))
ROOT_END=$((ROOT_START + ROOT_SIZE_IN_BYTES/BLOCK_SIZE - 1))
SYSTEM_SIZE_IN_BYTES=`convert_to_bytes $SYSTEM_SIZE`
SYSTEM_START=$((ROOT_END + 1))
SYSTEM_END=$((SYSTEM_START + SYSTEM_SIZE_IN_BYTES/BLOCK_SIZE - 1))
# As we are using msdos table we need to create extended partition for storing
# more then 4 partitions
EXTENDED_START=$((SYSTEM_END + 1))
CACHE_SIZE_IN_BYTES=`convert_to_bytes $CACHE_SIZE`
CACHE_START=$((EXTENDED_START + 1))
CACHE_END=$((CACHE_START + CACHE_SIZE_IN_BYTES/BLOCK_SIZE - 1))
DATA_SIZE_IN_BYTES=`convert_to_bytes $DATA_SIZE`
DATA_START=$((CACHE_END + 2))
EXTENDED_SIZE=$((CACHE_SIZE_IN_BYTES + DATA_SIZE_IN_BYTES))
EXTENDED_END=$(( EXTENDED_START + EXTENDED_SIZE/BLOCK_SIZE - 1))
DATA_END=$((EXTENDED_END - 1))
SDCARD_SIZE=`convert_to_bytes $SDCARD_SIZE`
SDCARD_START=$((EXTENDED_END + 1))
SDCARD_END=$((IMAGE_SIZE_IN_BYTES/BLOCK_SIZE - 1))

usage () {
  echo "Prepare empty Android image for Cotton Candy."
  echo "$0 [options]"
  echo "  Options:"
  echo "    --help: Print usage."
  echo "    --image-size <size>: Image size in megabytes [M] ( default: ${IMAGE_SIZE} ) "
  echo "    --image-path <path>: Path for new created image "
  echo "    --block-size <size>: Block size used for calculating partition table" \
       "(default: $BLOCK_SIZE bytes ) "
  echo
  echo "  To specify a size you can use sufix like: T - terabytes, G - gigabytes," \
       "M - megabytes, K - kilobytes, all values MUST be an integer e.g. 1GB, 1300M"
  exit 1
}

GETOPT_TEMP=$(getopt -o h --longoptions help,image-size:,image-path: -- "$@")

eval set -- "$GETOPT_TEMP"

while true; do
  case "$1" in
    -h|--help)
      usage
    ;;
    --image-size)
      IMAGE_SIZE=$2
      shift 2
    ;;
    --image-path)
      IMAGE_PATH=$2
      shift 2
    ;;
    --)
      shift
      break
    ;;
    *)
      usage
      die "Unknown arguments"
    ;;
  esac
done

if [ $EUID -ne 0 ]; then
  die "Must be run as root to get access to the loop device"
fi

MODULES=`lsmod | grep loop`
if [ -z "$MODULES" ]; then
  die "Missing the loop module, try: modprobe loop"
fi

if [ $? != 0 ]; then
  echo "Invalid command line options."
  exit $ERROR_BARDARGS
fi

if [ -z "$IMAGE_PATH" ]; then
  echo "No image specified, nothing to do!"
  echo ""
  usage;
fi

if [ -f $IMAGE_PATH ]
then
  die "$IMAGE_PATH can't create new image, file already exists"
fi

echo "Creating image file: $IMAGE_PATH ..."
dd of=$IMAGE_PATH bs=1 count=0 seek=$IMAGE_SIZE

echo "Creating new partitions on $IMAGE_PATH ..."

# The order of the partitions is very important for few reasons:
# - our u-boot environment setup is currently being _hardcoded_ and has been
# setup to load the kernel from the second partition, and the partition type
# must be ext2.
# - windows will force you to format the sd card if there will not be fat
# partition as a first

parted -s $IMAGE_PATH \
  mklabel msdos \
  mkpart primary fat32 ${SDCARD_START}s ${SDCARD_END}s \
  mkpart primary ext2 ${ROOT_START}s ${ROOT_END}s \
  mkpart primary ext4 ${SYSTEM_START}s ${SYSTEM_END}s \
  mkpart extended ${EXTENDED_START}s ${EXTENDED_END}s \
  mkpart logical ext4 ${CACHE_START}s ${CACHE_END}s \
  mkpart logical ext4 ${DATA_START}s ${DATA_END}s \
  print || die "Partitioning faild"

echo "Fetching partition from loop device ..."
# We should retrieve those numbers base on the start points of the partition
# which is calculated above then the grep will be al
SDCARD=`kpartx -l ${IMAGE_PATH} | head -1 | awk '{print $1}'`
ROOT=`kpartx -l ${IMAGE_PATH} | head -2 | tail -1 | awk '{print $1}'`
SYSTEM=`kpartx -l ${IMAGE_PATH} | head -3 | tail -1 | awk '{print $1}'`
CACHE=`kpartx -l ${IMAGE_PATH} | head -5 | tail -1 | awk '{print $1}'`
USERDATA=`kpartx -l ${IMAGE_PATH} | head -6 | tail -1 | awk '{print $1}'`

: ${ROOT_FILE_SYSTEM:=ext2}
: ${SYSTEM_FILE_SYSTEM:=ext4}
: ${CACHE_FILE_SYSTEM:=ext4}
: ${USERDATA_FILE_SYSTEM:=ext4}

echo "SDCard: ${SDCARD}"
echo "Root: ${ROOT}"
echo "System: ${SYSTEM}"
echo "Cache: ${CACHE}"
echo "Userdata: ${USERDATA}"

read -p "Are you sure to format all above partitions? [Y|n]" -n 1
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "Mounting image ..."
  kpartx -a ${IMAGE_PATH}

  echo "Formatting root file system (ext2) on /dev/mapper/${ROOT} ..."
  mke2fs -q -L root -t $ROOT_FILE_SYSTEM /dev/mapper/${ROOT}
  echo "Formatting system file system (ext4) on /dev/mapper/${SYSTEM} ..."
  mke2fs -q -L system -t $SYSTEM_FILE_SYSTEM -j /dev/mapper/${SYSTEM}
  echo "Formatting cache file system (ext4) on /dev/mapper/${CACHE} ..."
  mke2fs -q -L cache -t $CACHE_FILE_SYSTEM -j /dev/mapper/${CACHE}
  echo "Formatting userdata file system (ext4) on /dev/mapper/${USERDATA} ..."
  mke2fs -q -L data -t $USERDATA_FILE_SYSTEM -j /dev/mapper/${USERDATA}
  echo "Formatting sdcard file system (fat32) on /dev/mapper/${SDCARD} ..."
  mkdosfs -I -n sdcard /dev/mapper/${SDCARD}
  echo "done"

  echo "Umounting image ..."
  kpartx -d $IMAGE_PATH
else
  echo -e "\nAborting ..."
  exit 1
fi
