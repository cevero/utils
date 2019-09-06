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
# Number of clusters (deprecated).
#
NCLUSTERS=18

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
	# Nothing to do.
	echo ""
}

#
# Builds system image.
#
function build
{
	local image=$1
	local bindir=$2
	local binaries=$3

	# Create multi-binary image.
	truncate -s 0 $image
	for binary in $binaries;
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
	if [ "$line" = "[hal] powering off..." ];
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

	echo $image
	cat $image

	while read -r binary;
	do
		echo "spawning $binary..."

		cmd="$bindir/$binary --nclusters $NCLUSTERS"

		if [ ! -z $timeout ];
		then
			cmd="timeout --foreground $timeout $cmd"
		fi

		# Spawn cluster.
		if [ $mode == "--debug" ];
		then
			gdbserver localhost:$(($GDB_PORT + $i)) $cmd &
		else
			if [ $i == "0" ]; then
				$cmd |& tee $OUTFILE-$i &
			else
				$cmd 2> $OUTFILE-$i &
			fi	
		fi

		# Force cluster to boot.
		sleep $BOOT_DELAY

		let i++
	done < "$image"
}

#
# Runs a binary in the platform (simulator).
#
function run
{
	local image=$1    # Multibinary image.
	local bindir=$2   # Binary directory.
	local binaries=$3 # List of binaries (unused).
	local target=$4   # Target (unused).
	local variant=$5  # Cluster variant (unused)
	local mode=$6     # Spawn mode (run or debug).
	local timeout=$7  # Timeout for test mode.
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

	# House keeping.
	rm -rf /dev/mqueue/*nanvix-*
	rm -rf /dev/shm/*nanvix-*

	return $ret
}