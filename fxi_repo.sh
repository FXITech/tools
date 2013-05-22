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
#
# Simple wrapper on top of repo tool which use environment file instead of
# arguments.

usage () {
  echo "Usage:"
  echo "$0 init|sync|get|help ENV_FILE_PATH"
  echo
  echo "Actions:"
  echo "init - initialize new repo"
  echo "sync - synchronize source code"
  echo "get - fetch latest repo tool from official source"
  echo "help - display this help message"
}

EXPECTED_ARGS=2
ERROR_BADARGS=128

if [ $# -ne $EXPECTED_ARGS ];then
  usage
  exit $ERROR_BADARGS
fi

ACTION=$1
ENV_FILE_PATH=$2
if [ -f "$ENV_FILE_PATH" ]; then
  source "$ENV_FILE_PATH"
else
  echo "Environment file does not exist"
  exit 1
fi

# Get repo from official website
repo_get() {
  local repo_url=https://dl-ssl.google.com/dl/googlesource/git-repo/repo
  : ${SCRIPT_BIN_PATH:?"SCRIPT_BIN_PATH is not set correctly, check your env"}
  if [ -d $SCRIPT_BIN_PATH ]; then
    echo "Download repo from $repo_url into $SCRIPT_BIN_PATH."
    wget -q -O "$SCRIPT_BIN_PATH/repo" "$repo_url"
    chmod +x "$SCRIPT_BIN_PATH/repo"
  else
    echo "Script bin path doesn't exist: $SCRIPT_BIN_PATH"
    exit 1
  fi
}

repo_init() {
  : ${ANDROID_SRC_PATH:?"ANDROID_SRC_PATH is not set correctly, check your env"}
  : ${REPO_TOOL_PATH:?"REPO_TOOL_PATH is not set correctly, check your env"}
  : ${MANIFEST_REPO_URL:?"MANIFEST_REPO_URL is not set correctly, check your env"}
  : ${MANIFEST_BRANCH_NAME:?"MANIFEST_BARNCH_NAME is not set correctly, check your env"}
  : ${MANIFEST_FILENAME:?"MANIFEST_FILENAME is not set correctly, check your env"}
  if [ -d $ANDROID_SRC_PATH ]
  then
    cd "$ANDROID_SRC_PATH"
    ${REPO_TOOL_PATH} init --reference=${REFERENCE_SRC_PATH} \
                              -u ${MANIFEST_REPO_URL} \
                              -b ${MANIFEST_BRANCH_NAME} \
                              -m ${MANIFEST_FILENAME}
  else
    echo "$ANDROID_SRC_PATH doesn't exist"
    exit 1
  fi
}

repo_sync() {
  : ${ANDROID_SRC_PATH:?"ANDROID_SRC_PATH is not set correctly, check your env"}
  if [ -d $ANDROID_SRC_PATH ]
  then
    cd "$ANDROID_SRC_PATH"
    ${REPO_TOOL_PATH} sync ${REPO_OPTIONAL_OPTIONS}
  else
    echo "$ANDROID_SRC_PATH doesn't exist"
    exit 1
  fi
}

case "$ACTION" in
  init)
    repo_init
    ;;
  get)
    repo_get
    ;;
  sync)
    repo_sync
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Wrong action name"
    usage
    ;;
esac
