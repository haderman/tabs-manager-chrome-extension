port module Ports exposing (receivedDataFromJS)

import Json.Decode exposing (..)



-- Input


port receivedDataFromJS : (Json.Decode.Value -> msg) -> Sub msg
