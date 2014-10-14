#!/usr/bin/env bash

CURRENT_VERSION=`egrep "\"version\": \"[^\"]*\"" package/manifest.json | cut -d\" -f 4`

if [ $# -lt 1 ]
then
  echo "CIRC is currently at version $CURRENT_VERSION."
  echo "Run $0 [version] to update and package CIRC for the specified version."
  exit 1
fi

VERSION="$1"
sed -i "s/\"version\": \"[^\"]*\",/\"version\": \"$VERSION\",/g" \
  package/manifest.json
sed -i "s/VERSION: '[^']*'/VERSION: '$VERSION'/g" \
  package/bin/util.js

rm -rf circ circ.zip
cp -rv package circ
# Make app
grep -v "\"key\":" package/manifest.json > circ/manifest.json
(cd circ; zip -r ../circ.zip *)
