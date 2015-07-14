#!/bin/bash

tmp=$(mktemp -d)
echo "Using tmp dir ${tmp}"
trap "rm -Rf ${tmp}" EXIT

passed=0
failed=0

master=${tmp}/master
dup1=${tmp}/dup1
dup2=${tmp}/dup2

function mkf() {
	local content=$1
	shift
	while (( "$#" )); do
		local path=$1
		mkdir -p $(dirname ${path}) && echo ${content} > ${path}
		shift
	done
}

function pass() { let passed+=1; echo "."; }
function fail() { let failed+=1; echo "X: $1"; }
function print_test_summary() {
	echo "------"
	printf "passed=${passed}\nfailed=${failed}\n"		
	echo "------"
}

function assert_e() {
	while (( "$#" )); do
		local file=$1	
		[[ -e "${file}" ]] && pass "${file} exists" || fail "Expected ${file} to exist, but it doesn't"
		shift
	done
}

function assert_ne() {
	while (( "$#" )); do
		local file=$1	
		[[ -e "${file}" ]] && pass "${file} does not exist" || fail "Expected ${file} to be non-existent, but it would appear to be present..."
		shift
	done
}

mkdir -p ${master} ${dup1} ${dup2} || { echo "failed to create initial paths" && exit 1 ; }

mkf "content1"	"${master}/file1" \
		"${master}/dir1/file1" \
		"${dup1}/someDir/someFile.txt" \
		"${dup2}/someDir/.someHiddenDir/.someHiddenFile.jpg"

assert_e 	"${master}/file1" \
	 	"${master}/dir1/file1" \
		"${dup1}/someDir/someFile.txt" \
		"${dup2}/someDir/.someHiddenDir/.someHiddenFile.jpg" 

./rmdups.sh "${master}" "${dup1}" "${dup2}"

assert_e 	"${master}/file1" \
	 	"${master}/dir1/file1" 

assert_ne 	"${dup1}/someDir/someFile.txt" \
		"${dup2}/someDir/.someHiddenDir/.someHiddenFile.jpg" 


print_test_summary
[[ ${failed} == 0 ]] && exit 0 || exit 1
