#!/bin/bash

AVCONV_PATH=/usr/local/bin/avconv
LOMOD_PATH=/Users/jeromy/.go/src/bitbucket.org/lomoware/lomo-backend/cmd/lomod/lomod

# lomoupg and rsync has no dependencies, just copy binaries
LOMOUPG_PATH=/Users/jeromy/.go/src/bitbucket.org/lomoware/lomo-backend/cmd/lomoupg/lomoupg
RSYNC_PATH=/Users/jeromy/work/playground/rsync-3.1.3/rsync

FRAMEWORKS_DIR=lomod/Contents/Frameworks
BINARY_DIR=lomod/Contents/MacOS

mkdir -p $BINARY_DIR
mkdir -p $FRAMEWORKS_DIR/avconv
mkdir -p $FRAMEWORKS_DIR/lomod

rm -rf $FRAMEWORKS_DIR/avconv/*
rm -rf $FRAMEWORKS_DIR/lomod/*
rm -rf $BINARY_DIR/*

cp $AVCONV_PATH $BINARY_DIR
cp $LOMOD_PATH $BINARY_DIR
cp $LOMOUPG_PATH $BINARY_DIR
cp $RSYNC_PATH $BINARY_DIR

cd $BINARY_DIR
python ../../../matryoshka_name_tool.py  -L /usr/local/ -d ../Frameworks/lomod/ lomod
python ../../../matryoshka_name_tool.py  -L /usr/local/ -d ../Frameworks/avconv/ avconv
cd -
