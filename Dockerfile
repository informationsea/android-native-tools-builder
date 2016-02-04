FROM ubuntu:latest
MAINTAINER OKAMURA Yasunobu <okamura@informationsea.info>

RUN apt-get update
RUN apt-get install -y curl build-essential
RUN mkdir -p /data/data/jackpal.androidterm/app_HOME/ /opt/androidbuild
WORKDIR /opt/androidbuild
RUN curl -O http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin
RUN chmod +x android-ndk-r10e-linux-x86_64.bin
RUN ./android-ndk-r10e-linux-x86_64.bin > /dev/null

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
ENV CPPFLAGS -I$PREFIX/include -I$PREFIX/include/ncurses -L$PREFIX/lib
ENV LDFLAGS -L$PREFIX/lib

# Setup Busybox
RUN mkdir -p $PREFIX/bin
WORKDIR $PREFIX/bin
RUN curl -o busybox https://busybox.net/downloads/binaries/busybox-x86_64
RUN chmod +x ./busybox
RUN ./busybox --install -s .
RUN curl -o busybox https://busybox.net/downloads/binaries/busybox-armv5l
RUN chmod +x ./busybox

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
RUN ./configure --host=$HOSTCONFIG --disable-loginfunc --disable-syslog --disable-lastlog --disable-shadow --disable-utmp --disable-wtmp --prefix=$PREFIX CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie"
RUN make && make scp && make install && cp scp $PREFIX/bin && ln -s $PREFIX/bin/dbclient $PREFIX/bin/ssh
RUN mkdir -p $PREFIX/etc/dropbear/

# Setup ncurses
WORKDIR /tmp/
RUN curl -O http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz && tar xzf ncurses-6.0.tar.gz
WORKDIR /tmp/ncurses-6.0
ADD ncurses-6.0.patch .
RUN patch -p1 < ncurses-6.0.patch
RUN ./configure --prefix $PREFIX --host $HOSTCONFIG --disable-shared CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make -j4 && make install
RUN find $PREFIX/share/terminfo -type f -or -type l -not -name 'screen' -not -name 'vt100' -not -name 'linux' -not -name 'screen-256color' -not -name 'xterm' -delete

# zsh
WORKDIR /tmp
RUN curl -L -o zsh-5.2.tar.gz http://downloads.sourceforge.net/project/zsh/zsh/5.2/zsh-5.2.tar.gz && tar xzf zsh-5.2.tar.gz
WORKDIR /tmp/zsh-5.2
ADD zsh-5.2.patch .
RUN cp ../ncurses-6.0/config.sub ../ncurses-6.0/config.guess .
RUN patch -p1 < zsh-5.2.patch
RUN ./configure --prefix $PREFIX --host $HOSTCONFIG --disable-largefile --disable-locale --with-term-lib=ncurses --disable-dynamic --disable-multibyte LIBS="-L$PREFIX/lib" CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie"
RUN make && make install

# openssl
WORKDIR /tmp
RUN curl -LO https://www.openssl.org/source/openssl-1.0.2f.tar.gz && tar xzf openssl-1.0.2f.tar.gz
WORKDIR openssl-1.0.2f
RUN ./Configure zlib no-asm no-shared --prefix=$PREFIX android-armv7 && make CC="arm-linux-androideabi-gcc -fPIE -pie" AR="arm-linux-androideabi-ar r" RANLIB=arm-linux-androideabi-ranlib && make install CC="arm-linux-androideabi-gcc -fPIE -pie" AR="arm-linux-androideabi-ar r" RANLIB=arm-linux-androideabi-ranlib

# curl
WORKDIR /tmp/
RUN curl -LO http://curl.haxx.se/download/curl-7.46.0.tar.bz2 && tar xjf curl-7.46.0.tar.bz2
WORKDIR /tmp/curl-7.46.0
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX --disable-ipv6  --with-ssl=$PREFIX --disable-shared CFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# vim
WORKDIR /tmp/
RUN curl -OL ftp://ftp.vim.org/pub/vim/unix/vim-7.4.tar.bz2 && tar xjf vim-7.4.tar.bz2
WORKDIR /tmp/vim74
ADD vim-config.site config.site
ADD vim74.patch .
RUN patch -p1 < vim74.patch
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX --cache-file=config.cache --disable-nls --disable-netbeans --disable-gpm --disable-multibyte --with-tlib=ncurses CONFIG_SITE=$PWD/config.site --enable-gui=no --disable-gtktest --disable-xim --with-features=normal --without-x --disable-netbeans CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie"
RUN make && make install STRIP=arm-linux-androideabi-strip

# Readline
WORKDIR /tmp/
RUN curl -OL http://www.ring.gr.jp/archives/GNU/readline/readline-6.2.tar.gz && tar xzf readline-6.2.tar.gz
WORKDIR readline-6.2
RUN cp ../ncurses-6.0/config.sub ../ncurses-6.0/config.guess support/
RUN ./configure --prefix $PREFIX --host $HOSTCONFIG --disable-shared --disable-multibyte CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# Lua
WORKDIR /tmp/
RUN curl -OL http://www.lua.org/ftp/lua-5.3.2.tar.gz && tar xzf lua-5.3.2.tar.gz
WORKDIR /tmp/lua-5.3.2
ADD lua-5.3.2.patch .
RUN patch -p1 < lua-5.3.2.patch
RUN make linux CC=$CC CFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie"
RUN make install INSTALL_TOP=$PREFIX

#SQLite
WORKDIR /tmp/
RUN curl -OL https://www.sqlite.org/2016/sqlite-autoconf-3100000.tar.gz && tar xzf sqlite-autoconf-3100000.tar.gz
WORKDIR /tmp/sqlite-autoconf-3100000
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX --enable-readline --disable-shared LIBS="-lreadline -lncurses -L$PREFIX/lib" CPPFLAGS="-I$PREFIX/include -L$PREFIX/lib -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# make
WORKDIR /tmp/
RUN curl -OL http://www.ring.gr.jp/archives/GNU/make/make-4.1.tar.gz && tar xzf make-4.1.tar.gz
WORKDIR /tmp/make-4.1
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# patch
WORKDIR /tmp/
RUN curl -OL http://www.ring.gr.jp/archives/GNU/patch/patch-2.7.tar.gz && tar xzf patch-2.7.tar.gz
WORKDIR /tmp/patch-2.7
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# diffutils
WORKDIR /tmp/
RUN curl -OL http://www.ring.gr.jp/archives/GNU/diffutils/diffutils-3.3.tar.xz && tar xJf diffutils-3.3.tar.xz
WORKDIR /tmp/diffutils-3.3
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

# rsync
WORKDIR /tmp/
RUN curl -OL https://download.samba.org/pub/rsync/src/rsync-3.1.2.tar.gz && tar xzf rsync-3.1.2.tar.gz
WORKDIR /tmp/rsync-3.1.2
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install
#
## bash
##WORKDIR /tmp/
##RUN curl -OL http://www.ring.gr.jp/archives/GNU/bash/bash-4.3.30.tar.gz && tar xzf bash-4.3.30.tar.gz
##WORKDIR /tmp/bash-4.3.30
##RUN bash -c "for i in {31..42}; do curl -OL http://www.ring.gr.jp/archives/GNU/bash/bash-4.3-patches/bash43-0$i; done"
##RUN ./configure --host $HOSTCONFIG --prefix $PREFIX && make && make install
#
# atomic opts
WORKDIR /tmp/
RUN curl -OL http://www.ivmaisoft.com/_bin/atomic_ops/libatomic_ops-7.4.2.tar.gz && tar xzf libatomic_ops-7.4.2.tar.gz

# bohme gc
WORKDIR /tmp
RUN curl -OL http://www.hboehm.info/gc/gc_source/gc-7.4.2.tar.gz && tar xzf gc-7.4.2.tar.gz
WORKDIR /tmp/gc-7.4.2
RUN ln -s ../libatomic_ops-7.4.2 libatomic_ops
RUN ./configure --host $HOSTCONFIG --prefix $PREFIX --disable-shared LIBS="-lreadline -lncurses -L$PREFIX/lib -fPIE -pie" CPPFLAGS="-I$PREFIX/include -L$PREFIX/lib -fPIE" && make && make install

## zile
#WORKDIR /tmp/
#RUN curl -OL http://www.ring.gr.jp/archives/GNU/zile/zile-2.4.9.tar.gz && tar xzf zile-2.4.9.tar.gz
#WORKDIR /tmp/zile-2.4.9
#RUN ./configure --host $HOSTCONFIG --prefix $PREFIX LIBS="-lreadline -lncurses -L$PREFIX/lib -fPIE -pie" CPPFLAGS="-I$PREFIX/include -I$PREFIX/include/ncurses -L$PREFIX/lib -fPIE" && make -j4 && make install

## libbsd
#WORKDIR /tmp
#RUN curl -OL http://libbsd.freedesktop.org/releases/libbsd-0.8.1.tar.xz && tar xJf libbsd-0.8.1.tar.xz
#WORKDIR /tmp/libbsd-0.8.1
#RUN ./configure --prefix $PREFIX --host $HOSTCONFIG --disable-shared CPPFLAGS="$CPPFLAGS -fPIE" LDFLAGS="$LDFLAGS -fPIE -pie" && make && make install

WORKDIR $PREFIX/..
RUN du -h --max-depth 2
RUN tar cjf android-local.tar.bz2 local
