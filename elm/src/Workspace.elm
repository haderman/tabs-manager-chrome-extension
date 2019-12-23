module Workspace exposing (..)

import Color as C
import Json.Decode as D
import Json.Encode as E


type alias WorkspaceId =
    Int


type alias Workspace =
    { id : WorkspaceId
    , color : C.Color
    , name : String
    , tabs : List Tab
    }


type alias Tab =
    { title : String
    , url : String
    , icon : Maybe String
    }



-- DECODERS


decode : D.Decoder Workspace
decode =
    D.map4 Workspace
        (D.field "id" D.int)
        (D.field "color" C.decoder)
        (D.field "name" D.string)
        (D.field "tabs" tabListDecoder)


tabListDecoder : D.Decoder (List Tab)
tabListDecoder =
    D.list tabDecoder


tabDecoder : D.Decoder Tab
tabDecoder =
    D.map3 Tab
        (D.field "title" D.string)
        (D.field "url" D.string)
        (D.maybe <| D.field "favIconUrl" D.string)



-- ENCODERS


encode : Workspace -> E.Value
encode workspace =
    E.object
        [ ( "id", E.int workspace.id )
        , ( "name", E.string workspace.name )
        , ( "color", E.string <| C.fromColorToString workspace.color )
        , ( "tabs", E.list encodeTab workspace.tabs )
        ]


encodeTab : Tab -> E.Value
encodeTab tab =
    E.object
        [ ( "url", E.string tab.url )
        , ( "title", E.string tab.title )
        , ( "favIconUrl", encodeIcon tab.icon )
        ]


encodeIcon : Maybe String -> E.Value
encodeIcon maybeIcon =
    E.string <| Maybe.withDefault "" maybeIcon
