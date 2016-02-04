#!/bin/sh

docker build -t androidbuild . && docker run -i -t -v $PWD/host:/host androidbuild cp android-local.tar.bz2 /host/ || exit 1

echo "Successfully Built"
