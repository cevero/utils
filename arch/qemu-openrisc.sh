#
# MIT License
#
# Copyright(c) 2011-2019 The Maintainers of Nanvix
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
# Sets up development tools.
#
function setup_toolchain
{
	# Required variables.
	local CURDIR=`pwd`
	local WORKDIR=$CURDIR/toolchain/or1k
	local PREFIX=$WORKDIR
	local TARGET=or1k-elf
	local COMMIT=ccfd3f43e29a0b02249ffb3a256330a3717cca18

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
	./configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-sim
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
	../configure --target=$TARGET --prefix=$PREFIX --disable-nls --enable-languages=c --without-headers
	make -j $NCORES all-gcc
	make -j $NCORES all-target-libgcc
	make install-gcc
	make install-target-libgcc

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
	# Nothing to do.
	echo ""
}

#
# Runs a binary in the platform (simulator).
#
function run
{
	local image=$1
	local bindir=$2
	local binary=$3
	local target=$4
	local variant=$5
	local mode=$6
	local timeout=$7

	# Target configuration.
	local MEMSIZE=128M # Memory Size
	local NCORES=2     # Number of Cores
 
 	if [ -z "$IMAGE_ID" ]
	then
		IMAGE_ID=1
	else
		local binary=$binary$IMAGE_ID
	fi

	local tapname="nanvix-tap"$IMAGE_ID
	local gdb_tcp_port="1234"$IMAGE_ID
	local mac="52:54:00:12:34:"$IMAGE_ID

	local qemu_command='qemu-system-or1k	
						-gdb tcp::$gdb_tcp_port
						-kernel $bindir/$binary
						-serial stdio          
						-display none          
						-m $MEMSIZE            
						-mem-prealloc          
						-smp $NCORES           
						-net nic,macaddr=$mac -net tap,ifname=$tapname,script=no,downscript=no'

	if [ $mode == "--debug" ];
	then
		if [ -z "$NB_IMAGES" ]
			then
				local command="$qemu_command -S" 
				eval $command
			else
				for (( i=1; i<=$NB_IMAGES; i++ ))
				do
					local tapname="nanvix-tap"$i
					local gdb_tcp_port="1234"$i
					local binary="test-driver"$i
					local mac="52:54:00:12:34:"$i

					local command="xterm -e \" $qemu_command -S \" &"
					eval $command
				done
			fi
	else
		if [ ! -z $timeout ];
		then
			local command="timeout --foreground $timeout $qemu_command |& tee $OUTFILE"
			eval $command

			line=$(cat $OUTFILE | tail -2 | head -1)
			if [ "$line" = "[hal] powering off..." ] || [ "$line" = "[hal] halting..." ];
			then
				echo "Succeed !"
			else
				echo "Failed !"
				return -1
			fi
		else
			if [ -z "$NB_IMAGES" ]
			then
				local command="$qemu_command"
				eval $qemu_command
			else
				for (( i=1; i<=$NB_IMAGES; i++ ))
				do
					local tapname="nanvix-tap"$i
					local gdb_tcp_port="1234"$i
					local binary="test-driver"$i
					local mac="52:54:00:12:34:"$i

					local command="xterm -e \" $qemu_command \" &"
					eval $command
				done
			fi
		fi
	fi
}