
CURDIR=`pwd`
WORKDIR=$CURDIR/toolchain/riscv32
PREFIX=$WORKDIR
TARGET=riscv32-elf

cd $WORKDIR
cd riscv-gcc*/build

rm -rf *
../configure --target=$TARGET --prefix=$PREFIX --disable-nls \
             --enable-languages=c --without-headers --disable-multilib \
             --enable-libgomp --with-arch=rv32imac #  --enable-threads=posix


	make -j $NCORES all-gcc
	make -j $NCORES all-target-libgcc

    make install-gcc
    make install-target-libgcc
