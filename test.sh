#!/usr/bin/env bash

set -o nounset
set -o pipefail

tmp=$(mktemp -d)
echo "Using tmp dir ${tmp}"
trap "rm -Rf ${tmp}" EXIT

master=${tmp}/master
dup1="${tmp}/dup1"
dup2="${tmp}/dup2"

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

function assert_eq() {
	[[ $1 == $2 ]] && pass || fail "Expected $1 == $2"  
}

function assert_e() {
	while (( "$#" )); do
		local file=$1; shift	
		[[ -e "${file}" ]] && pass "${file} exists" || fail "Expected ${file} to exist, but it doesn't"
	done
}

function assert_c() {
	local expected="$1"; shift
	while (( "$#" )); do
		local file="$1"; shift
		if [ -e "${file}" ]; then
			[[  $(cat ${file}) == "${expected}" ]] && pass "${file} contains '${expected}'" || fail "Expected ${file} to contain '${expected}', but has '$(cat ${file})'"
		else
			fail "Expected ${file} to contain '${expected}', but file doesnt exist"
		fi
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
	
	assert_c "simple1" 	"${master}/simple"

	assert_c "toKeep" 	"${dup1}/fileToKeep1" \
						"${dup2}/fileToKeep2"

	assert_matches "${out}" "Total files processed = 4, duplicates = 2, unique files = 2, removed = 2"
}

function testWhereThereAreDuplicatesInTheMasterDirectoryDoesNotRemoveThem() {
	mkf "content"	"${master}/master-copy1" \
					"${master}/master-copy2" \
					"${master}/some-dir/master-copy3" \
					"${dup1}/duplicate1" \
					"${dup1}/duplicate2"

	mkf "toKeep"	"${dup1}/fileToKeep1" \
					"${dup2}/fileToKeep2"

	assert_e	"${master}/master-copy1" \
				"${master}/master-copy2" \
				"${master}/some-dir/master-copy3" \
				"${dup1}/duplicate1" \
				"${dup1}/duplicate2" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2"

	out=$(./rmdups "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/master-copy1" \
				"${master}/master-copy2" \
				"${master}/some-dir/master-copy3" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2"

	assert_ne	"${dup1}/duplicate1" \
				"${dup1}/duplicate2"
	
	assert_c "content"	"${master}/master-copy1" \
						"${master}/master-copy2" \
						"${master}/some-dir/master-copy3"

	assert_c "toKeep"	"${dup1}/fileToKeep1" \
						"${dup2}/fileToKeep2"

	assert_matches "${out}" "Total files processed = 4, duplicates = 2, unique files = 2, removed = 2"
}

function testSimpleCaseWithNoDirectoriesAndVerboseEnabled() {
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

	out=$(./rmdups -v "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/simple" \
				"${dup1}/fileToKeep1" \
				"${dup2}/fileToKeep2"

	assert_ne	"${dup1}/simple" \
				"${dup2}/simple.jpg"
	
	assert_c "simple"	"${master}/simple"

	assert_c "toKeep"	"${dup1}/fileToKeep1" \
						"${dup2}/fileToKeep2"

	assert_matches "${out}" "Total files processed = 4, duplicates = 2, unique files = 2, removed = 2"
	assert_matches "${out}" "removed ${dup1}/simple as duplicate of ${master}/simple"
	assert_matches "${out}" "removed ${dup2}/simple.jpg as duplicate of ${master}/simple"
}

function testCaseWithDirectories() {
	mkf "has-dups"	"${master}/file1" \
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

	assert_c "has-dups" "${master}/file1"

	assert_c "keep" 	"${dup1}/directory/keep1" \
						"${dup2}/directory3/keep.txt"
				
	assert_matches "${out}" "Total files processed = 5, duplicates = 3, unique files = 2, removed = 3"				
}

function testCaseWithMultipleFilesInMultipleDirectories() {
	mkf "file1"	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob"

	mkf "file2"	"${master}/file2" \
				"${dup1}/directory/file2" \
				"${dup2}/directory2/file2.jpg" \
				"${dup2}/directory3/file2.bob"

	mkf "keep"  "${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_e 	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${master}/file2" \
				"${dup1}/directory/file2" \
				"${dup2}/directory2/file2.jpg" \
				"${dup2}/directory3/file2.bob" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	out=$(./rmdups "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e 	"${master}/file1" \
				"${master}/file2" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_ne 	"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${dup1}/directory/file2" \
				"${dup2}/directory2/file2.jpg" \
				"${dup2}/directory3/file2.bob"

	assert_c "file1"	"${master}/file1"

	assert_c "file2"	"${master}/file2" 

	assert_c "keep"  	"${dup1}/directory/keep1" \
						"${dup2}/directory3/keep.txt"

	assert_matches "${out}" "Total files processed = 8, duplicates = 6, unique files = 2, removed = 6"				
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

	assert_c "dirs" 	"${master}/file1" \
						"${dup1}/directory/file1" \
						"${dup2}/directory2/file1.jpg" \
						"${dup2}/directory3/file1.bob"

	assert_c "keep"  	"${dup1}/directory/keep1" \
						"${dup2}/directory3/keep.txt"

	assert_matches "${out}" "Total files processed = 5, duplicates = 3, unique files = 2, removed = 0 (dry run)"				
}

function testUsingDryRunWithVerboseDoesntDeleteAnythingButStillIsVerbose() {
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

	out=$(./rmdups -v -d "${master}" "${dup1}" "${dup2}" 2>&1)

	assert_e	"${master}/file1" \
				"${dup1}/directory/file1" \
				"${dup2}/directory2/file1.jpg" \
				"${dup2}/directory3/file1.bob" \
				"${dup1}/directory/keep1" \
				"${dup2}/directory3/keep.txt"

	assert_c "dirs"	"${master}/file1" \
					"${dup1}/directory/file1" \
					"${dup2}/directory2/file1.jpg" \
					"${dup2}/directory3/file1.bob"

	assert_c "keep" "${dup1}/directory/keep1" \
					"${dup2}/directory3/keep.txt"

	assert_matches "${out}" "Total files processed = 5, duplicates = 3, unique files = 2, removed = 0 (dry run)"				
	assert_matches "${out}" "removed ${dup1}/directory/file1 as duplicate of ${master}/file1"
	assert_matches "${out}" "removed ${dup2}/directory2/file1.jpg as duplicate of ${master}/file1"
	assert_matches "${out}" "removed ${dup2}/directory3/file1.bob as duplicate of ${master}/file1"
}

function runningItWithAMasterDirectoryThatDoesntExistFails() {
	mkdir -p ${tmp}/exists
	out=$(./rmdups ${tmp}/path/that/doesnt/exist ${tmp}/exists 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Directory ${tmp}/path/that/doesnt/exist doesn't exist"				
}

function runningItWithADuplicateDirectoryThatDoesntExistFails() {
	mkf "file1"	"${master}/file1" \
				"${dup1}/file1" 

	out=$(./rmdups ${master} ${tmp}/path/that/doesnt/exist 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Directory ${tmp}/path/that/doesnt/exist doesn't exist"				
}

function runningItWithAMasterPathSameAsADuplicatePathCausesItToDie() {
	mkf "file1"	"${master}/file1" \
				"${dup1}/file1" 

	out=$(./rmdups ${master} ${master} 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Master path and duplicate(s) path are the same!"				
}

function runningItWithAMasterPathSameAsADuplicatePathCausesItToDie2() {
	mkf "file1"	"${master}/file1" \
				"${dup1}/file1" 

	out=$(./rmdups ${master} ${dup1} ${master} 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Master path and duplicate(s) path are the same!"				
}

function runningItWithAMasterPathSameAsADuplicatePathCausesItToDie3() {
	mkf "file1"	"${master}/file1" \
				"${dup1}/file1" 

	out=$(./rmdups ${master} ${dup1} ${master}/../master 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Master path and duplicate(s) path are the same!"				
}

function calledWithNotEnoughArgsCausesItToDie() {
	out=$(./rmdups -d ${master} 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Usage: .* MASTER_PATH"				
}

function calledWithNotEnoughArgsCausesItToDie2() {
	out=$(./rmdups -d 2>&1)
	assert_eq $? 1
	assert_matches "${out}" "Usage: .* MASTER_PATH"				
}

function runTest() {
	testName=$1
	echo "Executing test case $testName"
	cleanup
	$testName
}

runTest "testSimpleCaseWithNoDirectories"
runTest "testSimpleCaseWithNoDirectoriesAndVerboseEnabled"
runTest "testCaseWithMultipleFilesInMultipleDirectories"
runTest "testWhereThereAreDuplicatesInTheMasterDirectoryDoesNotRemoveThem"
runTest "testCaseWithDirectories"
runTest "testUsingDryRunDoesntDeleteAnything"
runTest "testUsingDryRunWithVerboseDoesntDeleteAnythingButStillIsVerbose"
runTest "runningItWithAMasterDirectoryThatDoesntExistFails"
runTest "runningItWithADuplicateDirectoryThatDoesntExistFails"
runTest "runningItWithAMasterPathSameAsADuplicatePathCausesItToDie"
runTest "runningItWithAMasterPathSameAsADuplicatePathCausesItToDie2"
runTest "runningItWithAMasterPathSameAsADuplicatePathCausesItToDie3"
runTest "calledWithNotEnoughArgsCausesItToDie"
runTest "calledWithNotEnoughArgsCausesItToDie2"

print_test_summary
[[ ${failed} == 0 ]] && exit 0 || exit 1


