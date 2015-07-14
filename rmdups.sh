#!/bin/bash

master=$1; shift

while (( "$#" )); do
	duplicates=$1; shift	
	rm -Rf ${duplicates}
done

