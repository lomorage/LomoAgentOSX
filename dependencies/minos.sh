#!/bin/bash

for libfile in lomod/Contents/Frameworks/lomod/*.dylib; do
  echo "lib file: $libfile"
  otool -l $libfile | grep -E "(minos|sdk)"
done
