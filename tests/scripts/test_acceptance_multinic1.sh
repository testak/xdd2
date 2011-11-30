#!/bin/sh
#
# Acceptance test for XDD.
#
# Validate xdd E2E running over multiple NICs 
#
###### set -x
#
# Source the test configuration environment
#
DATESTAMP="`date +%m%d%y%H%M%S`"
###############################################################
# Set variables to control test configuration
#

#
# Executables to use
#
XDDTEST_XDD_PATH=~/bin
XDDTEST_XDD_EXE=~/bin/xdd
XDDTEST_TESTS_DIR=.

#
# Mounts to use for testing
#
XDDTEST_SOURCE_MOUNT=/data/xfs
XDDTEST_DEST_MOUNT=/data/xfs

#
# Directory for storing logs generated by the test scripts themselves
#
XDDTEST_OUTPUT_DIR=./output
XDDTEST_OUTPUT_LOGFILE=${XDDTEST_OUTPUT_DIR}/multinic_log_${DATESTAMP}.log

#
# Hosts to use for E2E transfers
#
XDDTEST_E2E_CONTROL=osa
XDDTEST_E2E_SOURCE=osb
XDDTEST_E2E_DEST=osc
###############################################################
REQSIZE=4096
MBYTES=4096
QUEUE_DEPTH=4
DEST_DATA_NETWORK_1=osc-net2
DEST_DATA_NETWORK_2=osc-net3
DEST_DATA_NETWORK_3=osc-net4
DEST_DATA_NETWORK_4=osc-net5

# Perform pre-test 
echo "Beginning XDD Multi NIC Test 1 on CONTROL machine $XDDTEST_E2E_CONTROL - DATESTAMP $DATESTAMP " | tee -a ${XDDTEST_OUTPUT_LOGFILE}
test_source=$XDDTEST_SOURCE_MOUNT/source
echo "Multi NIC Test 1 - Making directory $test_source on $XDDTEST_E2E_SOURCE" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE "rm -rf $test_source " | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE "mkdir -p $test_source " | tee -a ${XDDTEST_OUTPUT_LOGFILE}
test_dest=$XDDTEST_SOURCE_MOUNT/dest
echo "Multi NIC Test 1 - Making directory $test_dest on $XDDTEST_E2E_DEST" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_DEST "rm -rf $test_dest" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_DEST "mkdir -p $test_dest" | tee -a ${XDDTEST_OUTPUT_LOGFILE}

source_file=$test_source/multinic_test_file_source
source_output_file_prefix=$test_source/multinic_test_${DATESTAMP}
file_create_output=${source_output_file_prefix}_file_create_output.csv
file_create_errors=${source_output_file_prefix}_file_create_errors.txt
file_create_ts=${source_output_file_prefix}_file_create_ts
copy_source_output=${source_output_file_prefix}_copy_source_output.csv
copy_source_errors=${source_output_file_prefix}_copy_source_errors.txt
copy_source_ts=${source_output_file_prefix}_copy_source_ts
dest_file=$test_dest/multinic_test_file_dest
dest_output_file_prefix=$test_dest/multinic_test_${DATESTAMP}
copy_dest_output=${dest_output_file_prefix}_copy_dest_output.csv
copy_dest_errors=${dest_output_file_prefix}_copy_dest_errors.txt
copy_dest_ts=${dest_output_file_prefix}_copy_dest_ts

#
# Create the source file
#
echo "Multi NIC Test 1 - Making test file $source_file on $XDDTEST_E2E_SOURCE using $XDDTEST_XDD_EXE" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE \
	$XDDTEST_XDD_EXE \
		-target $source_file \
		-op write \
		-dio \
		-reqsize $REQSIZE \
		-mbytes $MBYTES \
		-qd $QUEUE_DEPTH \
		-hb 1 \
		-hb bw \
		-hb etc \
		-ts output $file_create_ts \
		-output $file_create_output \
		-errout $file_create_errors \
		-datapattern random > /dev/null
sleep 5
#
# Start a copy over two interfaces
#
echo "Multi NIC Test 1 - Starting copy from $XDDTEST_E2E_SOURCE to $XDDTEST_E2E_DEST" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
echo "Multi NIC Test 1 - Destination side first... $XDDTEST_E2E_DEST" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_DEST \
	$XDDTEST_XDD_EXE \
		-target $dest_file \
		-op write \
		-reqsize $REQSIZE \
		-mbytes $MBYTES \
		-e2e isdest \
		-hb 1 \
		-hb bw \
		-hb ops \
		-hb etc \
		-qd $QUEUE_DEPTH \
		-ts output $copy_dest_ts \
		-output $copy_dest_output \
		-errout $copy_dest_errors \
		-e2e destination $DEST_DATA_NETWORK_1 \
		-e2e destination $DEST_DATA_NETWORK_2 \
		-e2e destination $DEST_DATA_NETWORK_3 \
		-e2e destination $DEST_DATA_NETWORK_4  > /dev/null &
sleep 2
echo "Multi NIC Test 1 - ...Now the source side... $XDDTEST_E2E_SOURCE" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE \
	$XDDTEST_XDD_EXE \
		-target $source_file \
		-op read \
		-reqsize $REQSIZE \
		-mbytes $MBYTES \
		-qd $QUEUE_DEPTH \
		-ts output $copy_source_ts \
		-output $copy_source_output \
		-errout $copy_source_errors \
		-e2e issource \
		-e2e destination $DEST_DATA_NETWORK_1 \
		-e2e destination $DEST_DATA_NETWORK_2 \
		-e2e destination $DEST_DATA_NETWORK_3 \
		-e2e destination $DEST_DATA_NETWORK_4  > /dev/null &

echo "Multi NIC Test 1 - WAITING FOR COMPLETION.... `date`" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
wait

echo "Multi NIC Test 1 - COPY complete.... `date`" | tee -a ${XDDTEST_OUTPUT_LOGFILE}

echo "Multi NIC Test 1 - Collecting output files from the test..." | tee -a ${XDDTEST_OUTPUT_LOGFILE}
scp $XDDTEST_E2E_SOURCE:${file_create_ts}* $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_SOURCE:${file_create_output} $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_SOURCE:${file_create_errors} $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_SOURCE:${copy_source_ts}* $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_SOURCE:${copy_source_output} $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_SOURCE:${copy_source_errors} $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_DEST:${copy_dest_ts}* $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_DEST:${copy_dest_output} $XDDTEST_OUTPUT_DIR
scp $XDDTEST_E2E_DEST:${copy_dest_errors} $XDDTEST_OUTPUT_DIR

echo "Multi NIC Test 1 - Source and destination files look like so:"  | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE "ls -l $source_file " | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_DEST "ls -l $dest_file" | tee -a ${XDDTEST_OUTPUT_LOGFILE}

echo "Multi NIC Test 1 - Generating MD5 sums for source and destination files:" | tee -a ${XDDTEST_OUTPUT_LOGFILE}
ssh $XDDTEST_E2E_SOURCE "md5sum $source_file " | tee -a ${XDDTEST_OUTPUT_LOGFILE} 
ssh $XDDTEST_E2E_DEST   "md5sum $dest_file   " | tee -a ${XDDTEST_OUTPUT_LOGFILE}

echo "Multi NIC Test 1 - COMPLETED! `date`" | tee -a ${XDDTEST_OUTPUT_LOGFILE}

