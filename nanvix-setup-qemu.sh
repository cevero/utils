#
# MIT License
#
# Copyright(c) 2011-2020 The Maintainers of Nanvix
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Build and install variables.
export CURDIR=`pwd`
export WORKDIR=$CURDIR/toolchain/qemu
export PREFIX=$WORKDIR

# QEMU Version
export QEMU_VERSION=4.0.0

# Number of Cores
NCORES=`grep -c "^processor" /proc/cpuinfo`

# Set working directory.
mkdir -p $WORKDIR
cd $WORKDIR

# Get QEMU.
wget "http://wiki.qemu-project.org/download/qemu-$QEMU_VERSION.tar.bz2"
tar -xjvf qemu-$QEMU_VERSION.tar.bz2
rm -f qemu-$QEMU_VERSION.tar.bz2

# Build qemu
cd qemu-$QEMU_VERSION
./configure --prefix=$PREFIX --target-list=i386-softmmu,or1k-softmmu,riscv32-softmmu --enable-sdl --enable-curses
make -j $NCORES all
sudo make install

# Cleans files.
cd $WORKDIR
rm -rf qemu-$QEMU_VERSION

echo "==============================================================================="
echo "QEMU $QEMU_VERSION installed in $PREFIX"
echo "==============================================================================="
