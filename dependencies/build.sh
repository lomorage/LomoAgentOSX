#!/bin/bash
set -xe

# set the env variable below first!

: "${LOMOD_PATH:=/Users/jianfu/Work/playground/lomo-backend/cmd/lomod/lomod}"
: "${LOMOC_PATH:=/Users/jianfu/Work/playground/lomo-backend/cmd/lomoc/lomoc}"
: "${BREW_LIB_PATH:=/opt/homebrew/}"

# lomoupg and rsync has no dependencies, just copy binaries
# following processing code for lomoupg, rsync, ffmpeg, exiftool are commented since they are in place and no changes
: "${LOMOUPG_PATH:=/Users/jeromy/.go/src/github.com/lomorage/lomoUpdate/lomoupg}"
: "${RSYNC_PATH:=/Users/jeromy/work/playground/rsync-3.1.3/rsync}"

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

FFMPEG_HOME_ABS=$(realpath "deps/ffmpeg")
FFMPEG_PATH=$FFMPEG_HOME_ABS/ffmpeg
FFPROBE_PATH=$FFMPEG_HOME_ABS/ffprobe

EXIFTOOL_HOME_ABS=$(realpath "deps/exiftool")
EXIFTOOL_PATH=$EXIFTOOL_HOME_ABS/exiftool
EXIFTOOL_LIB=$EXIFTOOL_HOME_ABS/lib

FRAMEWORKS_DIR=lomod/Contents/Frameworks
BINARY_DIR=lomod/Contents/MacOS

mkdir -p $BINARY_DIR
mkdir -p $FRAMEWORKS_DIR/ffmpeg
mkdir -p $FRAMEWORKS_DIR/lomod

#rm -rf $FRAMEWORKS_DIR/ffmpeg/*
#rm -rf $FRAMEWORKS_DIR/lomod/*
#rm -rf $BINARY_DIR/*

#cp $FFMPEG_PATH $BINARY_DIR
#cp $FFPROBE_PATH $BINARY_DIR
#cp $EXIFTOOL_PATH $BINARY_DIR
#cp -R $EXIFTOOL_LIB $BINARY_DIR
cp $LOMOD_PATH $BINARY_DIR
cp $LOMOC_PATH $BINARY_DIR
#cp $LOMOUPG_PATH $BINARY_DIR
#cp $RSYNC_PATH $BINARY_DIR

cd $BINARY_DIR
python3 ../../../matryoshka_name_tool.py  -L $BREW_LIB_PATH -d ../Frameworks/lomod/ lomoc
python3 ../../../matryoshka_name_tool.py -u -L $BREW_LIB_PATH -d ../Frameworks/lomod/ lomod
#python3 ../../../matryoshka_name_tool.py  -L $FFMPEG_HOME_ABS -d ../Frameworks/ffmpeg/ ffmpeg
#python3 ../../../matryoshka_name_tool.py  -L $FFMPEG_HOME_ABS -d ../Frameworks/ffmpeg/ ffprobe

install_name_tool -add_rpath @executable_path/../Frameworks/lomod lomoc
install_name_tool -add_rpath @executable_path/../Frameworks/lomod lomod
#install_name_tool -add_rpath @executable_path/../Frameworks/ffmpeg ffmpeg
#install_name_tool -add_rpath @executable_path/../Frameworks/ffmpeg ffprobe
cd -
