#!/bin/bash

tmp=$(mktemp -d)
echo "Using tmp dir ${tmp}"
#trap "rm -Rf ${tmp}" EXIT

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
		local file=$1; shift	
		[[ -e "${file}" ]] && pass "${file} exists" || fail "Expected ${file} to exist, but it doesn't"
	done
}

function assert_ne() {
	while (( "$#" )); do
		local file=$1; shift	
		[[ ! -e "${file}" ]] && pass "${file} does not exist" || fail "Expected ${file} to be non-existent, but it would appear to be present..."
	done
}

master=${tmp}/master
dup1=${tmp}/dup1
dup2=${tmp}/dup2

function mkf() {
	local content=$1; shift
	while (( "$#" )); do
		local path=$1; shift
		mkdir -p $(dirname ${path}) && echo ${content} > ${path}
	done
}

mkdir -p ${master} ${dup1} ${dup2} || { echo "failed to create initial paths" && exit 1 ; }

function testSimpleCaseWithNoDirectories() {\
	mkf "simple"	"${master}/simple" \
					"${dup1}/simple" \
					"${dup1}/fileToKeep1" \
					"${dup2}/fileToKeep2" \
					"${dup2}/simple.jpg"

	assert_e	"${master}/simple" \
				"${dup1}/simple" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2" \
				"${dup2}/simple.jpg"

	./rmdups "${master}" "${dup1}" "${dup2}"

	assert_e	"${master}/simple"

	assert_ne	"${dup1}/simple" \
				"${dup2}/simple.jpg"
}


function testCaseWithDirectories() {\
	mkf "dirs"	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"

	assert_e	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"

	./rmdups "${master}" "${dup1}" "${dup2}"

	assert_e	"${master}/file1"

	assert_ne	"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"
}



testSimpleCaseWithNoDirectories
testCaseWithDirectories

print_test_summary
[[ ${failed} == 0 ]] && exit 0 || exit 1


