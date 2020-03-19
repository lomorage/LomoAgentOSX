#!/bin/bash
set -e

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

FFMPEG_HOME_ABS=$(realpath "deps/ffmpeg")
FFMPEG_PATH=$FFMPEG_HOME_ABS/ffmpeg
FFPROBE_PATH=$FFMPEG_HOME_ABS/ffprobe

EXIFTOOL_HOME_ABS=$(realpath "deps/exiftool")
EXIFTOOL_PATH=$EXIFTOOL_HOME_ABS/exiftool
EXIFTOOL_LIB=$EXIFTOOL_HOME_ABS/lib

LOMOD_PATH=/Users/jeromy/.go/src/bitbucket.org/lomoware/lomo-backend/cmd/lomod/lomod
LOMOWEB_PATH=/Users/jeromy/.go/src/github.com/lomorage/lomo-web/lomo-web

# lomoupg and rsync has no dependencies, just copy binaries
LOMOUPG_PATH=/Users/jeromy/.go/src/github.com/lomorage/lomoUpdate/lomoupg
RSYNC_PATH=/Users/jeromy/work/playground/rsync-3.1.3/rsync

FRAMEWORKS_DIR=lomod/Contents/Frameworks
BINARY_DIR=lomod/Contents/MacOS

mkdir -p $BINARY_DIR
mkdir -p $FRAMEWORKS_DIR/ffmpeg
mkdir -p $FRAMEWORKS_DIR/lomod

rm -rf $FRAMEWORKS_DIR/ffmpeg/*
rm -rf $FRAMEWORKS_DIR/lomod/*
rm -rf $BINARY_DIR/*

cp $FFMPEG_PATH $BINARY_DIR
cp $FFPROBE_PATH $BINARY_DIR
cp $EXIFTOOL_PATH $BINARY_DIR
cp -R $EXIFTOOL_LIB $BINARY_DIR
cp $LOMOD_PATH $BINARY_DIR
cp $LOMOWEB_PATH $BINARY_DIR
cp $LOMOUPG_PATH $BINARY_DIR
cp $RSYNC_PATH $BINARY_DIR

cd $BINARY_DIR
python ../../../matryoshka_name_tool.py  -L /usr/local/ -d ../Frameworks/lomod/ lomod
python ../../../matryoshka_name_tool.py  -L $FFMPEG_HOME_ABS -d ../Frameworks/ffmpeg/ ffmpeg
python ../../../matryoshka_name_tool.py  -L $FFMPEG_HOME_ABS -d ../Frameworks/ffmpeg/ ffprobe
cd -
