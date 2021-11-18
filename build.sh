#!/bin/bash

(
cd $(dirname "${BASH_SOURCE[0]}")

#update and init only libmoon, libmoons build.sh will do the rest recursivly
git submodule update --init

pwd
find . -type d
cd libmoon/deps/dpdk/config
curl -O https://raw.githubusercontent.com/rafaelfolco/dpdk/master/config/common_linuxapp
cd -
exit 0

(
cd libmoon
./build.sh $@ --moongen
)

)

