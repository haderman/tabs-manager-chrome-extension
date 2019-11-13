port module Ports exposing
    ( openWorkspace
    , receivedDataFromJS
    , updateWorkspace
    )

import Json.Decode as D
import Json.Encode as E



-- Output


port openWorkspace : Int -> Cmd msg


port updateWorkspace : E.Value -> Cmd msg



-- Input


port receivedDataFromJS : (D.Value -> msg) -> Sub msg
