#!/bin/sh

# Create dist folder
rm -rf dist
mkdir dist
mkdir dist/src
mkdir dist/src/newtab
mkdir dist/src/popup

# Copy newtab and popup files into dist folder
cp src/newtab/newtab.html src/newtab/index.js dist/src/newtab
cp src/popup/popup.html src/popup/index.js dist/src/popup

# Make bundles of elm files
cd src/elm
elm make src/NewTab.elm --output ../../dist/src/newtab/newtab.bundle.js
elm make src/Popup.elm --output ../../dist/src/popup/popup.bundle.js
cd ../..

# Copy styles and assets into dist folder
cp -r assets dist
cp -r src/styles dist/src

cp background.bundle.js manifest.json dist


