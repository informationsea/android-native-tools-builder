# android-native-tools-builder
Build Native Android Tools in Docker

## How to use

1. Setup Docker
2. run `docker build -t androidbuild .`
3. mkdir host
4. run `docker run -i -t -v $PWD/host:/host androidbuild cp android-local.tar.bz2 /host/`
5. copy host/android-local.tar.bz2 to your smartphone (or download prebuilt from https://github.com/informationsea/android-native-tools-builder/releases)
6. download `https://busybox.net/downloads/binaries/busybox-armv5l` and copy to your smartphone
7. Install Android Terminal Emulator
8. Extract android-local.tar.bz2 on /data/data/jackpal.androidterm/app_HOME using busybox

## Supported Softwares

* busybox
* zlib
* dropbear
* ncurses
* zsh
* openssl
* curl
* vim
