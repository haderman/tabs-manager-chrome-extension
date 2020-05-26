#!/bin/sh


FIRST_ARGUMENT="$1"

echo "hola mundo: ${FIRST_ARGUMENT}"


cd_elm_folder()
{
  cd src/elm
}

watch_newtab()
{
  elm-live src/NewTab.elm -- --debug --output=../newtab/newtab.bundle.js
}

watch_popup()
{
  elm-live src/Popup.elm -- --debug --output=../popup/popup.bundle.js
}

cd_elm_folder
watch_newtab
