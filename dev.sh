#!/bin/sh

# how to use: sh dev.sh popup|newtab|background
# This script is to watch changes in files and creat bundles from it

trap before_exit EXIT

before_exit() {
  echo "End"
}

watch_newtab() {
  cd src/elm
  elm-live src/NewTab.elm -- --debug --output=../newtab/newtab.bundle.js
}

watch_popup() {
  cd src/elm
  elm-live src/Popup.elm -- --debug --output=../popup/popup.bundle.js
}

watch_background() {
  # this works to me to make de "denon" command available
  # but I think this shouldn't be here. I have to research more about this
  # 
  # export PATH="/Users/<your account>/.deno/bin:$PATH"
  #
  export PATH="/Users/hadercardona/.deno/bin:$PATH"
  denon start
}

case $1 in
  "newtab")
    watch_newtab
    ;;
  "popup")
    watch_popup
    ;;
  "background")
    watch_background
    ;;
  *)
    echo "command not found"
    ;;
esac



