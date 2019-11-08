module Main exposing (..)

-- Press buttons to increment and decrement a counter.
--
-- Read how it works:
--   https://guide.elm-lang.org/architecture/buttons.html
--

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode as Decode exposing (..)
import Ports



-- MAIN


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
    | WorkspaceInUse Workspace


type alias Tab =
    { id : Int
    , title : String
    , url : String
    , icon : Maybe String
    }


type alias Workspace =
    { color : String
    , key : String
    , name : String
    , tabs : List Tab
    }


type alias Data =
    { workspacesNames : List String
    , state : State
    , workspacesInfo : Dict String Workspace
    }


type alias Model =
    { data : Data
    , test : String
    }


type alias Flags =
    { window : Int }


initModel : Model
initModel =
    { data =
        { workspacesNames = []
        , state = NoInitated
        , workspacesInfo = Dict.empty
        }
    , test = ""
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedDataFromJS value ->
            case value of
                Ok data ->
                    ( { model | data = data }, Cmd.none )

                Err error ->
                    ( { model | test = "error" }, Cmd.none )

        OpenWorkspace name ->
            ( model, Ports.openWorkspace name )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "grid gridTemplateCol-repeat-xl gridGap-m padding-m justifyContent-center" ]
        (model.data.workspacesNames
            |> List.map
                (\name ->
                    Dict.get name model.data.workspacesInfo
                )
            |> List.map
                (\maybeWorkspace ->
                    case maybeWorkspace of
                        Just workspace ->
                            viewWorkspace workspace

                        Nothing ->
                            text ""
                )
        )


viewWorkspace : Workspace -> Html Msg
viewWorkspace { name, tabs } =
    let
        header =
            div [ class "flex alignItems-center justifyContent-space-between" ]
                [ h3 [ class "color-alternate marginTop-none" ]
                    [ text name ]
                , button
                    [ class "padding-m background-secondary rounded marginLeft-l marginBottom-xs color-contrast show-in-hover"
                    , onClick <| OpenWorkspace name
                    ]
                    [ text "Open" ]
                ]

        divider =
            div [ class "marginBottom-m borderBottom-s borderColor-secondary" ]
                []

        body =
            div [] <| List.map viewTab tabs
    in
    div [ class "padding-m border-s rounded borderColor-secondary width-xl height-fit-content" ]
        [ header
        , divider
        , body
        ]


viewTab : Tab -> Html Msg
viewTab { title, url, icon } =
    let
        srcIcon =
            case icon of
                Just value ->
                    value

                Nothing ->
                    ""
    in
    div [ class "flex alignItems-center marginBottom-s" ]
        [ img
            [ src srcIcon
            , class "width-xs height-xs beforeBackgroundColor-secondary marginRight-s"
            ]
            []
        , span [ class "ellipsis overflowHidden whiteSpace-nowrap color-contrast" ]
            [ text title ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- DECODERS


dataDecoder : Decoder Data
dataDecoder =
    Decode.field "data" <|
        Decode.map3 Data
            (Decode.field "workspaces" (Decode.list Decode.string))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)


workspacesInfoDecoder : Decoder (Dict String Workspace)
workspacesInfoDecoder =
    Decode.dict workspaceDecoder


stateDecoder : Decoder State
stateDecoder =
    Decode.oneOf [ workspaceInUseDecoder, startedDecoder ]


startedDecoder : Decoder State
startedDecoder =
    Decode.succeed Started


workspaceInUseDecoder : Decoder State
workspaceInUseDecoder =
    Decode.map WorkspaceInUse <|
        Decode.field "workspaceInUse" workspaceDecoder


workspaceDecoder : Decoder Workspace
workspaceDecoder =
    Decode.map4 Workspace
        (Decode.field "color" Decode.string)
        (Decode.field "key" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "tabs" tabListDecoder)


tabListDecoder : Decoder (List Tab)
tabListDecoder =
    Decode.list tabDecoder


tabDecoder : Decoder Tab
tabDecoder =
    Decode.map4 Tab
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "url" Decode.string)
        (Decode.maybe <| Decode.field "favIconUrl" Decode.string)
