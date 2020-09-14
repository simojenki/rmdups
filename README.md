# rmdups

Finds and removes duplicate files.

![Tests](https://github.com/simojenki/rmdups/workflows/CI/badge.svg)

Compares a single master directory with multiple secondary directories, files that are present in both a secondary directory and the master result in the secondary directories file being removed.

- md5 checksum comparison
- Recursive
- Dry Run
- Concurrency using gnu parallel
- Tested, in bash!

## Examples

### Compare a master directory with 2 other directories containing possible duplicates, removing any duplicates found in /duplicates1 or /duplicates2

```shell
./rmdups /master /duplicates1 /duplicates2
```

### Compare a master directory with another directory containing possible duplicates, removing all duplicates, with verbose enabled

```shell
./rmdups -v /master /some-directory-that-might-have-duplicates
```

### Compare a master directory with a directory containing possible duplicates, however perform a dry run and do not delete anything

```shell
./rmdups -d /master /duplicates
```

## Pre-requisites

### gnu-parallel

### Installation on ubuntu

```shell
sudo apt-get install parallel
```
