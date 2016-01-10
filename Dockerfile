FROM ubuntu:latest
MAINTAINER OKAMURA Yasunobu <okamura@informationsea.info>

RUN apt-get update
RUN apt-get install -y curl build-essential
RUN mkdir -p /data/data/jackpal.androidterm/app_HOME/ /opt/androidbuild
WORKDIR /opt/androidbuild
RUN curl -O http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin
RUN chmod +x android-ndk-r10e-linux-x86_64.bin
RUN ./android-ndk-r10e-linux-x86_64.bin

# Setup Build Environment
RUN bash /opt/androidbuild/android-ndk-r10e/build/tools/make-standalone-toolchain.sh --ndk-dir=/opt/androidbuild/android-ndk-r10e --install-dir=/opt/android-ndk --platform=android-19 --arch=arm
ENV PATH /opt/android-ndk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV CC arm-linux-androideabi-gcc
ENV LD arm-linux-androideabi-ld
ENV CXX arm-linux-androideabi-c++
ENV AR arm-linux-androideabi-ar
ENV RANLIB arm-linux-androideabi-ranlib
ENV HOSTCONFIG arm-linux-androideabi
ENV PREFIX=/data/data/jackpal.androidterm/app_HOME/local

# Setup Busybox
RUN mkdir -p $PREFIX/bin
WORKDIR $PREFIX/bin
RUN curl -o busybox https://busybox.net/downloads/binaries/busybox-x86_64
RUN chmod +x ./busybox
RUN ./busybox --install -s .
RUN curl -o busybox https://busybox.net/downloads/binaries/busybox-armv5l

# Zlib
WORKDIR /tmp
RUN curl -O http://zlib.net/zlib-1.2.8.tar.gz && tar xzf zlib-1.2.8.tar.gz
WORKDIR /tmp/zlib-1.2.8
RUN ./configure --prefix=$PREFIX && make && make install

# Setup Dropbear
WORKDIR /tmp
RUN curl -O https://matt.ucc.asn.au/dropbear/releases/dropbear-2015.71.tar.bz2 && tar xjf dropbear-2015.71.tar.bz2
WORKDIR /tmp/dropbear-2015.71
ADD dropbear-2015.71-android.patch .
RUN patch -p1 < dropbear-2015.71-android.patch
RUN ./configure --host=$HOSTCONFIG --disable-loginfunc --disable-syslog --disable-lastlog --disable-shadow --disable-utmp --disable-wtmp --prefix=$PREFIX
RUN make && make scp && make install && cp scp $PREFIX/bin && ln -s $PREFIX/bin/dbclient $PREFIX/bin/ssh
RUN mkdir -p $PREFIX/etc/dropbear/

# Setup ncurses
WORKDIR /tmp/
RUN curl -O http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz && tar xzf ncurses-6.0.tar.gz
WORKDIR /tmp/ncurses-6.0
ADD ncurses-6.0.patch .
RUN patch -p1 < ncurses-6.0.patch
RUN ./configure --prefix $PREFIX --host $HOSTCONFIG && make -j4 && make install
RUN find $PREFIX/share/terminfo -type f -or -type l -not -name 'screen' -not -name 'vt100' -not -name 'linux' -not -name 'screen-256color' -not -name 'xterm' -delete

# zsh
WORKDIR /tmp
RUN curl -L -o zsh-5.2.tar.gz http://downloads.sourceforge.net/project/zsh/zsh/5.2/zsh-5.2.tar.gz && tar xzf zsh-5.2.tar.gz
WORKDIR /tmp/zsh-5.2
ADD zsh-5.2.patch .
RUN cp ../ncurses-6.0/config.sub ../ncurses-6.0/config.guess .
RUN patch -p1 < zsh-5.2.patch
RUN ./configure --prefix $PREFIX --host $HOSTCONFIG --disable-largefile --disable-locale --with-term-lib=ncurses --disable-dynamic --disable-multibyte LIBS="-L$PREFIX/lib" LDFLAGS="-static"
RUN make && make install

# openssl
WORKDIR /tmp
RUN curl -LO https://www.openssl.org/source/openssl-1.0.2e.tar.gz && tar xzf openssl-1.0.2e.tar.gz
WORKDIR openssl-1.0.2e
RUN ./Configure zlib no-asm --prefix=$PREFIX android-armv7 && make CC=arm-linux-androideabi-gcc CXX=arm-linux-androideabi-c++ AR="arm-linux-androideabi-ar r" RANLIB=arm-linux-androideabi-ranlib && make install CC=arm-linux-androideabi-gcc CXX=arm-linux-androideabi-c++ AR="arm-linux-androideabi-ar r" RANLIB=arm-linux-androideabi-ranlib

# curl
WORKDIR /tmp/
RUN curl -LO http://curl.haxx.se/download/curl-7.46.0.tar.bz2 && tar xjf curl-7.46.0.tar.bz2
WORKDIR /tmp/curl-7.46.0
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX --disable-ipv6  --with-ssl=$PREFIX CFLAGS="-I$PREFIX/include" && make && make install

# vim
WORKDIR /tmp/
RUN curl -OL ftp://ftp.vim.org/pub/vim/unix/vim-7.4.tar.bz2 && tar xjf vim-7.4.tar.bz2
WORKDIR /tmp/vim74
ADD vim-config.site config.site
ADD vim74.patch .
RUN patch -p1 < vim74.patch
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX LDFLAGS="-L$PREFIX/lib" CFLAGS="-I$PREFIX/include" --cache-file=config.cache --disable-nls --disable-netbeans --disable-gpm --disable-multibyte --with-tlib=ncurses CONFIG_SITE=$PWD/config.site --enable-gui=no --disable-gtktest --disable-xim --with-features=normal --without-x --disable-netbeans
RUN make && make install STRIP=arm-linux-androideabi-strip

WORKDIR /data/data/jackpal.androidterm
RUN tar cjf android-local.tar.bz2 local
