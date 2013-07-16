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
# Flow:
# - Init
# - Fetch manifest with submodule if exists.
# - Sync
#

EXPECTED_ARGS=1
ERROR_BARDARGS=128

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` ENV_FILE_PATH"
  exit $ERROR_BARDARGS
fi

ENV_FILE_PATH=$1
if [ -f "$ENV_FILE_PATH" ]; then
  source $ENV_FILE_PATH
else
  echo "Environment file does not exist"
  exit 1
fi

$FXI_REPO_PATH/fxi_repo.sh init $ENV_FILE_PATH || { echo "fxi_repo.sh init failed"; exit 1; }
# Repo tool do not provide (yet) possibility to have submodules in manifest
# repository.
# This temporary workaround is to allow you to include another manifest inside
# existing one from git submodule.

MANIFEST_REPO_PATH=$ANDROID_SRC_PATH/.repo/manifests/
if [ -f $MANIFEST_REPO_PATH/.gitmodules ];
then
  cd $MANIFEST_REPO_PATH
  git submodule update --init
  $FXI_REPO_PATH/fxi_repo.sh init $ENV_FILE_PATH || { echo "fxi_repo.sh init failed"; exit 1; }
fi
$FXI_REPO_PATH/fxi_repo.sh sync $ENV_FILE_PATH || { echo "fxi_repo.sh sync failed"; exit 1; }
