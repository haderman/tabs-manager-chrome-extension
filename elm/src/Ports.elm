port module Ports exposing
    ( openWorkspace
    , receivedDataFromJS
    )

import Json.Decode exposing (..)



-- Output


port openWorkspace : String -> Cmd msg



-- Input


port receivedDataFromJS : (Json.Decode.Value -> msg) -> Sub msg
