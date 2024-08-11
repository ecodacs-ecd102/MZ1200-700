#!/bin/bash

ITNR="[31;1m"
ITNG="[32;1m"
ITNY="[33;1m"
ITNB="[34;1m"
ITNM="[35;1m"
ITNC="[36;1m"
ITNW="[37;1m"
ITN="${ITNY}"
NOR="[0m"

# Catch errors and display the offending line number:
set -e
trap 'echo "${ITNR}$0 FAILED at line ${LINENO}${NOR}"' ERR

cd "$(dirname "$0")" || exit 1
export CWD="$(pwd)"

echo "CWD=$CWD"

. ./env.sh

rm -rf "$CWD/build_examples"
rm -rf "$CWD/build_w"
mkdir -vp "$CWD/build_examples"
mkdir -vp "$CWD/build_w"
cd "$CWD/build_examples"
cmake "$PICO_examples_PATH/CMakeLists.txt"
ninja

cd "$CWD/build_w"
cmake -DPICO_BOARD=pico_w "$PICO_examples_PATH/CMakeLists.txt"
ninja

rm -rf /tmp/tmp-piP
