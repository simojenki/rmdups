#!/bin/bash

tmp=$(mktemp -d)
echo "Using tmp dir ${tmp}"
trap "rm -Rf ${tmp}" EXIT

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

function assert_e() {
	while (( "$#" )); do
		local file=$1	
		[[ -e "${file}" ]] || { echo "Expected ${file} to exist, but it doesn't" && exit 1; }
		shift
	done
}

function assert_ne() {
	while (( "$#" )); do
		local file=$1	
		[[ -e "${file}" ]] || { echo "Expected ${file} to exist, but it doesn't" && exit 1; }
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




