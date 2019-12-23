port module Ports exposing
    ( deleteWorkspace
    , openWorkspace
    , receivedDataFromJS
    , updateWorkspace
    , createWorkspace
    )

import Json.Decode as D
import Json.Encode as E



-- Output


port openWorkspace : Int -> Cmd msg


port updateWorkspace : E.Value -> Cmd msg


port deleteWorkspace : Int -> Cmd msg


port createWorkspace : ( String, String ) -> Cmd msg



-- Input


port receivedDataFromJS : (D.Value -> msg) -> Sub msg
