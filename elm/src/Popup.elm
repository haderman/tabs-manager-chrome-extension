module Popup exposing (..)

import Browser
import Color as C
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Json.Encode as Encode exposing (..)
import Ports
import Workspace as W



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type State
    = NoInitated
    | Started
    | WorkspaceInUse W.WorkspaceId


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , state : State
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
    }


type alias Flags =
    { window : Int }


type alias Model =
    { data : Data
    }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , state = NoInitated
        , workspacesInfo = Dict.empty
        }
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace W.WorkspaceId


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedDataFromJS (Ok data) ->
            ( { model | data = data }, Cmd.none )

        ReceivedDataFromJS (Err error) ->
            ( model, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "padding-l" ]
        [ viewCards model.data ]


viewCards : Data -> Html Msg
viewCards data =
    let
        getWorkspace id =
            Dict.get id data.workspacesInfo

        viewCardOrEmptyText maybeWorkspace =
            case maybeWorkspace of
                Just workspace ->
                    viewCard workspace

                Nothing ->
                    text ""
    in
    div [ class "grid gridTemplateCol-3 gridGap-xs" ]
        (data.workspacesIds
            |> List.map getWorkspace
            |> List.map viewCardOrEmptyText
        )


viewCard : W.Workspace -> Html Msg
viewCard workspace =
    let
        title name color =
            div [ class <| "fontSize-l ellipsis overflowHidden whiteSpace-nowrap textAlign-left color-" ++ C.fromColorToString color ]
                [ text name ]

        tabsCount num =
            div [ class "fontSize-xs color-contrast textAlign-left" ]
                [ text <| String.fromInt num ++ " Tabs" ]
    in
    button
        [ class "background-black padding-m rounded"
        , autofocus True
        , onClick <| OpenWorkspace workspace.id
        ]
        [ title workspace.name workspace.color
        , tabsCount <| List.length workspace.tabs
        ]



-- DECODERS


dataDecoder : Decoder Data
dataDecoder =
    Decode.field "data" <|
        Decode.map3 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)


workspacesInfoDecoder : Decoder (Dict W.WorkspaceId W.Workspace)
workspacesInfoDecoder =
    Decode.dict W.decode
        |> Decode.map stringDictToIntDict


stringDictToIntDict : Dict String a -> Dict Int a
stringDictToIntDict stringDict =
    Dict.foldl
        (\k v newDict ->
            case String.toInt k of
                Just k_ ->
                    Dict.insert k_ v newDict

                Nothing ->
                    newDict
        )
        Dict.empty
        stringDict


stateDecoder : Decoder State
stateDecoder =
    Decode.oneOf [ workspaceInUseDecoder, startedDecoder ]


startedDecoder : Decoder State
startedDecoder =
    Decode.succeed Started


workspaceInUseDecoder : Decoder State
workspaceInUseDecoder =
    Decode.map WorkspaceInUse <|
        Decode.field "workspaceInUse" Decode.int
