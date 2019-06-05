#!/bin/bash

releaseStr=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" LomoAgent/Info.plist)
echo $releaseStr
hub release create -a build/LomoAgent.dmg -a build/LomoAgent.zip -m $releaseStr $releaseStr

