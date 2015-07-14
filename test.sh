#!/bin/bash

tmp=$(mktemp -d)
echo "Using tmp dir ${tmp}"
trap "rm -Rf ${tmp}" EXIT

passed=0
failed=0

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
		[[ ! -e "${file}" ]] && pass "${file} does not exist" || fail "Expected ${file} to be non-existent, but it would appear to be present..."
		shift
	done
}

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

mkdir -p ${master} ${dup1} ${dup2} || { echo "failed to create initial paths" && exit 1 ; }

function testSimpleCaseWithNoDirectories() {\
	mkf "simple"	"${master}/simple" \
					"${dup1}/simple.txt" \
					"${dup2}/simple.jpg"

	assert_e	"${master}/simple" \
				"${dup1}/simple.txt" \
				"${dup2}/simple.jpg"

	./rmdups.sh "${master}" "${dup1}" "${dup2}"

	assert_e	"${master}/simple"

	assert_ne	"${dup1}/simple.txt" \
				"${dup2}/simple.jpg"
}

testSimpleCaseWithNoDirectories

print_test_summary
[[ ${failed} == 0 ]] && exit 0 || exit 1


