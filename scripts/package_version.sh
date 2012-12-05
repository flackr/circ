#!/usr/bin/env bash

CURRENT_VERSION=`egrep "\"version\": \"[^\"]*\"" manifest.json | cut -d\" -f 4`

if [ $# -lt 1 ]
then
  echo "CIRC is currently at version $CURRENT_VERSION."
  echo "Run $0 [version] to update and package CIRC for the specified version."
  exit 1
fi

VERSION="$1"
sed -i 's/"version": "[^"]*",/"version": "'"$VERSION"'",/g' \
  manifest.json manifest_public.json
sed -i 's/exports\.VERSION = "[^"]*"/exports.VERSION = "'"$VERSION"'"/g' \
  src/irc/irc.coffee

mkdir -p packages
make package

# Make public app
cp manifest_public.json package/manifest.json
(cd package && zip -r "../packages/circ-public.zip" *)

# Make private app
grep -v "\"key\":" manifest.json > package/manifest.json
(cd package && zip -r "../packages/circ-internal.zip" *)
