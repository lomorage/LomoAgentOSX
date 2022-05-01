#!/bin/bash
set -xe

#security find-identity -v

codesign --remove-signature "$1/Contents/Library/LoginItems/LomoAgentLauncher.app/Contents/Frameworks/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Library/LoginItems/LomoAgentLauncher.app/Contents/Frameworks/"*.dylib

codesign --remove-signature "$1/Contents/Library/LoginItems/LomoAgentLauncher.app"
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Library/LoginItems/LomoAgentLauncher.app"

for item in lomoc \
            lomod \
            ffmpeg \
            ffprobe \
            lomoupg \
            rsync
    do
        codesign --remove-signature "$1/Contents/MacOS/$item"
        codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/MacOS/$item"
    done

codesign --remove-signature "$1/Contents/Frameworks/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Frameworks/"*.dylib

codesign --remove-signature "$1/Contents/Frameworks/ffmpeg/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Frameworks/ffmpeg/"*.dylib

codesign --remove-signature "$1/Contents/Frameworks/lomod/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Frameworks/lomod/"*.dylib

for item in Zip \
            Commands \
            CocoaLumberjack \
            CatCrypto
  do
    codesign --remove-signature "$1/Contents/Frameworks/$item.framework/Versions/A"
    codesign -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1/Contents/Frameworks/$item.framework/Versions/A"
  done

codesign --remove-signature "$1"
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$1"

codesign  -d -vv "$1"
codesign -vvv --deep --strict "$1"

filename=$(basename "$1")
rm -rf $filename.zip
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$1" "$filename.zip"
#/usr/bin/ditto -c -k --keepParent $1 $filename.zip
xcrun altool --notarize-app --primary-bundle-id lomoware.lomorage.$filename --username lomorage@gmail.com --password "@keychain:altool" --file "$filename.zip"

#xcrun altool --notarization-info $RequestUUID -u lomorage@gmail.com --password "@keychain:altool"
#spctl --assess -v $1
