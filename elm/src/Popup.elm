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


type FormStatus
    = WritingName String
    | NameConfirmed String
    | SelectingColor C.Color


type Status
    = NoInitated
    | Idle
    | WorkspaceInUse W.WorkspaceId
    | CreatingNewWorkspace FormStatus


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , status : Status
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
    }


type alias Flags =
    { window : Int }


type alias Model =
    { data : Data
    , status : Status
    }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , workspacesInfo = Dict.empty
        , status = NoInitated
        }
    , status = NoInitated
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace W.WorkspaceId
    | OnInputName String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedDataFromJS (Ok data) ->
            ( { model
                | data = data
                , status = data.status
              }
            , Cmd.none
            )

        ReceivedDataFromJS (Err error) ->
            ( model, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )

        OnInputName value ->
            ( { model
                | status =
                    if String.isEmpty value then
                        Idle

                    else
                        CreatingNewWorkspace <| WritingName value
              }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- VIEW


view : Model -> Html Msg
view model =
    case model.status of
        WorkspaceInUse id ->
            div []
                [ vieHeaderWorkspaceInUse id model.data
                , viewCards model.data
                ]

        NoInitated ->
            div [ class "flex justifyContent-center alignItems-center" ]
                [ h2 []
                    [ text "Loading..." ]
                ]

        Idle ->
            div []
                [ viewHeaderWithInput model
                , viewCards model.data
                ]

        CreatingNewWorkspace inputState ->
            div []
                [ viewHeaderCreatingWorkspace inputState model
                , viewCards model.data
                ]



-- VIEW HEADER


headerStyle : String
headerStyle =
    String.join " "
        [ "full-width"
        , "height-s"
        , "background-transparent"
        , "sticky"
        , "backdrop-filter-blur"
        , "boxShadow-black"
        , "zIndex-4"
        , "marginBottom-xl"
        , "flex"
        , "alignItems-center"
        , "justifyContent-center"
        ]


vieHeaderWorkspaceInUse : W.WorkspaceId -> Data -> Html Msg
vieHeaderWorkspaceInUse id data =
    let
        title =
            case Dict.get id data.workspacesInfo of
                Just { name, color } ->
                    h2 [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
                        [ Html.text name ]

                Nothing ->
                    Html.text ""
    in
    div [ class headerStyle ]
        [ title ]


viewHeaderWithInput : Model -> Html Msg
viewHeaderWithInput model =
    div [ class headerStyle ]
        [ input
            [ class inputStyle
            , selected True
            , autofocus True
            , onInput OnInputName
            ]
            []
        ]


viewHeaderCreatingWorkspace : FormStatus -> Model -> Html Msg
viewHeaderCreatingWorkspace status model =
    let
        headerStyle_ =
            "background-secondary"

        content =
            case status of
                WritingName value ->
                    input
                        [ class inputStyle
                        , selected True
                        , autofocus True
                        , Html.Attributes.value value
                        , onInput OnInputName
                        ]
                        []

                _ ->
                    text ""
    in
    div [ class <| headerStyle ++ " " ++ headerStyle_ ]
        [ content ]



-- VIEW HEADER HELPERS


inputStyle : String
inputStyle =
    "fontSize-l background-transparent marginTop-none marginBottom-m fontWeight-200 color-contrast padding-xs textAlign-center"



-- VIEW CONTENT


viewContent : Model -> Html Msg
viewContent { data } =
    case data.workspacesIds of
        [] ->
            viewEmptyWorkspacesListMessage

        _ ->
            viewCards data


viewEmptyWorkspacesListMessage : Html Msg
viewEmptyWorkspacesListMessage =
    div [ class "flex justifyContent-center alignItems-center" ]
        [ h2 [ class "color-contrast" ]
            [ text "NO HAY WORKSPACES" ]
        ]


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
    div [ class "grid gridTemplateCol-3 gridGap-xs padding-l" ]
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


stateDecoder : Decoder Status
stateDecoder =
    Decode.oneOf [ workspaceInUseDecoder, idleDecoder ]


idleDecoder : Decoder Status
idleDecoder =
    Decode.succeed Idle


workspaceInUseDecoder : Decoder Status
workspaceInUseDecoder =
    Decode.map WorkspaceInUse <|
        Decode.field "workspaceInUse" Decode.int
