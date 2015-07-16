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
function cleanup() { rm -Rf "${master}" "${dup1}" "${dup2}"; }

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

function assert_matches() {
	echo "$1" | grep -G "$2" &>/dev/null && pass "$1 matches $2" || fail "Expected '$1' to match '$2'."
}

master=${tmp}/master
dup1=${tmp}/dup1
dup2="${tmp}/dup 2"

function mkf() {
	local content="$1"; shift
	while (( "$#" )); do
		local path="$1"; shift
		mkdir -p "$(dirname "${path}")" && echo "${content}" > "${path}"
	done
}

mkdir -p ${master} ${dup1} ${dup2} || { echo "failed to create initial paths" && exit 1 ; }

function testSimpleCaseWithNoDirectories() {
	mkf "simple"	"${master}/simple" \
					"${dup1}/simple" \
					"${dup2}/simple.jpg"

	mkf "toKeep"	"${dup1}/fileToKeep1" \
					"${dup2}/fileToKeep2"

	assert_e	"${master}/simple" \
				"${dup1}/simple" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2" \
				"${dup2}/simple.jpg"

	out=$(./rmdups "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/simple" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2"

	assert_ne	"${dup1}/simple" \
				"${dup2}/simple.jpg"
	
	assert_matches "${out}" "Total files processed = 4, duplicates = 2, unique files = 2, removed = 2"
}


function testCaseWithDirectories() {
	mkf "dirs"	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"

	mkf "keep"  "${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_e	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	out=$(./rmdups "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/file1" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_ne	"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"
				
	assert_matches "${out}" "Total files processed = 5, duplicates = 3, unique files = 2, removed = 3"				
}

function testUsingDryRunDoesntDeleteAnything() {
	mkf "dirs"	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"

	mkf "keep"  "${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_e	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	out=$(./rmdups -d "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"
				
	assert_matches "${out}" "Total files processed = 5, duplicates = 3, unique files = 2, removed = 0 (dry run)"				
}

testSimpleCaseWithNoDirectories
cleanup
testCaseWithDirectories
cleanup
testUsingDryRunDoesntDeleteAnything
cleanup

print_test_summary
[[ ${failed} == 0 ]] && exit 0 || exit 1


