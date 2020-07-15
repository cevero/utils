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

#
# Boot delay.
#
# Adust this so as to force cluster 0 to be the first one to boot.
#
BOOT_DELAY=2

#
# GDB Port.
#
GDB_PORT=1234

#
# Sets up development tools.
#
function setup_toolchain
{
	# Required variables.
	local CURDIR=`pwd`
	local WORKDIR=$CURDIR/toolchain/riscv32
	local PREFIX=$WORKDIR
	local TARGET=riscv32-elf
	local COMMIT=ab8b80604f02db4b00af24302bc9d20ebfcdd911
	
	# Retrieve the number of processor cores
	local NCORES=`grep -c ^processor /proc/cpuinfo`

	mkdir -p $WORKDIR
	cd $WORKDIR

	# Get toolchain.
	wget "https://github.com/nanvix/toolchain/archive/$COMMIT.zip"
	unzip $COMMIT.zip
	mv toolchain-$COMMIT/* .

	# Cleanup.
	rm -rf toolchain-$COMMIT
	rm -rf $COMMIT.zip

	# Build binutils.
	cd binutils*/
	./configure --target=$TARGET --prefix=$PREFIX --disable-nls
	make -j $NCORES all
	make install

	# Cleanup.
	cd $WORKDIR
	rm -rf binutils*

	# Build GCC.
	cd gcc*/
	./contrib/download_prerequisites
	mkdir build
	cd build
	../configure --target=$TARGET --prefix=$PREFIX --disable-nls \
             --enable-languages=c --without-headers --disable-multilib \
             --enable-libgomp --enable-libatomic --enable-libitm \
             --enable-libsanitizer --enable-libvtv --enable-libstdc++-v3 \
             --enable-zlib --enable-libbacktrace  --enable-libffi \
             --liboffloadmic=yes

	make -j $NCORES all-gcc
	make -j $NCORES all-target-libgcc
	make -j $NCORES all-target-libgomp
	make install-gcc
	make install-target-libgcc
	make install-target-libgomp

    # Cleanup.
	cd $WORKDIR
	rm -rf gcc*

	# Build GDB.
	cd $WORKDIR
	cd gdb*/
	./configure --target=$TARGET --prefix=$PREFIX --with-auto-load-safe-path=/ --with-guile=no
	make -j $NCORES
	make install

	# Cleanup.
	cd $WORKDIR
	rm -rf gdb*

	# Back to the current folder
	cd $CURDIR
}

#
# Builds system image.
#
function build
{
	local image=$1
	local bindir=$2
	local imgsrc=$3

	# Create multi-binary image.
	truncate -s 0 $image
	for binary in `cat $imgsrc`;
	do
		echo $binary >> $image
	done
}

#
# Parses an execution output.
#
# $1 Output file.
#
function parse_output
{
	local outfile=$1

	line=$(cat $outfile | tail -1)
	if [[ "$line" = *"powering off"* ]] || [[ $line == *"halting"* ]];
	then
		echo "Succeed !"
	else
		echo "Failed !"
		return -1
	fi

	return 0
}

#
# Spawns binaries.
#
# $1 Binary directory.
# $2 Multibinary image.
# $3 Spawn mode.
#
function spawn_binaries
{
	local bindir=$1
	local image=$2
	local mode=$3
	local timeout=$4
	local cmd=""

	let i=0

	# Target configuration.
	local MEMSIZE=128M # Memory Size
	local NCORES=5     # Number of Cores

	qemu_cmd="qemu-system-riscv32
			-machine virt
			-serial stdio
			-display none
			-m $MEMSIZE
			-mem-prealloc
			-smp $NCORES"

	for binary in `cat $image`;
	do
		cmd="$qemu_cmd -gdb tcp::$GDB_PORT"
		cmd="$cmd -kernel $bindir/$binary"

		echo "spawning $binary..."

		if [ ! -z $timeout ];
		then
			cmd="timeout --foreground $timeout $cmd"
		fi

		# Spawn cluster.
		if [ $mode == "--debug" ];
		then
			cmd="$cmd -S"
			$cmd &
		else
			if [ $i == "0" ]; then
				$cmd | tee $OUTFILE-$i &
			else
				$cmd &> $OUTFILE-$i &
			fi
		fi

		# Force cluster to boot.
		sleep $BOOT_DELAY

		let i++
		let GDB_PORT++
	done
}

#
# Runs a binary in the platform (simulator).
#
function run
{
	local image=$1    # Multibinary image.
	local bindir=$2   # Binary directory.
	local target=$3   # Target (unused).
	local variant=$4  # Cluster variant (unused)
	local mode=$5     # Spawn mode (run or debug).
	local timeout=$6  # Timeout for test mode.
	local ret=0       # Return value.

	# Test
	if [ ! -z $timeout ];
	then
		spawn_binaries $bindir $image "--test" $timeout

		# Parse output.
		wait

		parse_output $OUTFILE-0
		ret=$?

	# Run/Debug
	else
		spawn_binaries $bindir $image $mode
	fi

	wait

	return $ret
}
