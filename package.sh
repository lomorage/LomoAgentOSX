#!/bin/bash
# try "diskutil unmountDisk force /dev/disk#" if appdmg error
set -e

rm -rf build/LomoAgent.dmg
appdmg LomoAgent/Assets.xcassets/dmg.json build/LomoAgent.dmg
python3 dependencies/licenseDMG.py build/LomoAgent.dmg dependencies/lomoware_license.rtf
cd build
zip -r LomoAgent.zip LomoAgent.app

shasum -a256 LomoAgent.zip
