#!/bin/bash

rm -rf build/LomoAgent.dmg
appdmg LomoAgent/Assets.xcassets/dmg.json build/LomoAgent.dmg
