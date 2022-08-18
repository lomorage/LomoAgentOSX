#!/bin/bash
set -xe

# https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow

RELEASE_APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/LomoAgent*/Build/Products/Release/LomoAgent.app -type d -maxdepth 0)

#sudo xattr -rd com.apple.quarantine $RELEASE_APP_PATH
#security find-identity -v

codesign --remove-signature "$RELEASE_APP_PATH/Contents/Library/LoginItems/LomoAgentLauncher.app/Contents/Frameworks/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Library/LoginItems/LomoAgentLauncher.app/Contents/Frameworks/"*.dylib

codesign --remove-signature "$RELEASE_APP_PATH/Contents/Library/LoginItems/LomoAgentLauncher.app"
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Library/LoginItems/LomoAgentLauncher.app"

for item in lomoc \
            lomod \
            ffmpeg \
            ffprobe \
            lomoupg \
            rsync
    do
        codesign --remove-signature "$RELEASE_APP_PATH/Contents/MacOS/$item"
        codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/MacOS/$item"
    done

codesign --remove-signature "$RELEASE_APP_PATH/Contents/Frameworks/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Frameworks/"*.dylib

codesign --remove-signature "$RELEASE_APP_PATH/Contents/Frameworks/ffmpeg/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Frameworks/ffmpeg/"*.dylib

codesign --remove-signature "$RELEASE_APP_PATH/Contents/Frameworks/lomod/"*.dylib
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Frameworks/lomod/"*.dylib

for item in Zip \
            Commands \
            CocoaLumberjack \
            CatCrypto
  do
    codesign --remove-signature "$RELEASE_APP_PATH/Contents/Frameworks/$item.framework/Versions/A"
    codesign -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH/Contents/Frameworks/$item.framework/Versions/A"
  done

codesign --remove-signature "$RELEASE_APP_PATH"
codesign --timestamp --deep -s 4C9293BC4416D5D3AFDC9A8EAE4B26384CB71407 -o runtime -v "$RELEASE_APP_PATH"

codesign  -d -vv "$RELEASE_APP_PATH"
codesign -vvv --deep --strict "$RELEASE_APP_PATH"

filename=$(basename "$RELEASE_APP_PATH")
rm -rf $filename.zip
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$RELEASE_APP_PATH" "$filename.zip"
#/usr/bin/ditto -c -k --keepParent $RELEASE_APP_PATH $filename.zip
xcrun altool --notarize-app --primary-bundle-id lomoware.lomorage.$filename --username lomorage@gmail.com --password "@keychain:altool" --file "$filename.zip"

#xcrun stapler staple "$RELEASE_APP_PATH"

#xcrun altool --notarization-info $RequestUUID -u lomorage@gmail.com --password "@keychain:altool"
#spctl --assess -v $RELEASE_APP_PATH

rm -rf build/LomoAgent.app.zip

unzip LomoAgent.app.zip -d build/
