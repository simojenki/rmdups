# rmdups

bash script for finding and removing duplicate files between a master directory and n directories containing possible duplicates;

Files are deemed duplicates if their md5 checksums are the same.

Concurrency is achieved using gnu parallel.

## Examples

### Compare a master directory with 2 directories containing possible duplicates, removing all duplicates

```shell
./rmdups /master /duplicates1 /duplicates2
```

### Compare a master directory with 2 directories containing possible duplicates, removing all duplicates, with verbose enabled

```shell
./rmdups -v /master /duplicates1 /duplicates2
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
