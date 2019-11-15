module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Json.Encode as Encode exposing (..)
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


type Color
    = Green
    | Blue
    | Orange
    | Purple
    | Yellow
    | Red
    | Gray
    | Cyan


type WorkspaceState
    = Read
    | Edition


type alias WorkspaceProxy =
    { id : Int
    , proxyColor : Color
    , proxyName : String
    , key : String
    , state : WorkspaceState
    , tabs : List Tab
    }


type State
    = NoInitated
    | Started
    | WorkspaceInUse Int


type alias Tab =
    { title : String
    , url : String
    , icon : Maybe String
    }


type alias Workspace =
    { id : Int
    , color : Color
    , key : String
    , name : String
    , tabs : List Tab
    }


type alias Data =
    { workspacesIds : List Int
    , state : State
    , workspacesInfo : Dict Int Workspace
    }


type alias Model =
    { data : Data
    , test : String
    , workspacesProxy : Dict Int WorkspaceProxy
    }


type alias Flags =
    { window : Int }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , state = NoInitated
        , workspacesInfo = Dict.empty
        }
    , test = ""
    , workspacesProxy = Dict.empty
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace Int
    | ChangeProxyName Int String
    | ChangeProxyColor Int Color
    | EditWorkspace Int
    | UpdateWorkspace WorkspaceProxy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedDataFromJS value ->
            case value of
                Ok data ->
                    ( { model
                        | data = data
                        , workspacesProxy = composeWorkspacesProxy data.workspacesIds data.workspacesInfo
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | test = "error" }, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )

        ChangeProxyName workspaceId value ->
            ( { model
                | workspacesProxy =
                    Dict.update workspaceId (updateProxyName value) model.workspacesProxy
              }
            , Cmd.none
            )

        ChangeProxyColor workspaceId color ->
            ( { model
                | workspacesProxy =
                    Dict.update workspaceId (updateProxyColor color) model.workspacesProxy
              }
            , Cmd.none
            )

        EditWorkspace workspaceId ->
            ( { model
                | workspacesProxy =
                    model.data.workspacesInfo
                        |> composeWorkspacesProxy model.data.workspacesIds
                        |> Dict.map
                            (\id proxy ->
                                if workspaceId == id then
                                    { proxy | state = Edition }

                                else
                                    proxy
                            )
              }
            , Cmd.none
            )

        UpdateWorkspace proxy ->
            ( { model
                | workspacesProxy =
                    Dict.update proxy.id (updateProxyState Read) model.workspacesProxy
              }
            , Ports.updateWorkspace <| encodeWorkspaceProxy proxy
            )

        NoOp ->
            ( model, Cmd.none )


updateProxyState : WorkspaceState -> Maybe WorkspaceProxy -> Maybe WorkspaceProxy
updateProxyState state maybeProxy =
    case maybeProxy of
        Just proxy ->
            Just { proxy | state = state }

        Nothing ->
            Nothing


updateProxyName : String -> Maybe WorkspaceProxy -> Maybe WorkspaceProxy
updateProxyName value maybeProxy =
    case maybeProxy of
        Just proxy ->
            Just { proxy | proxyName = value }

        option2 ->
            Nothing


updateProxyColor : Color -> Maybe WorkspaceProxy -> Maybe WorkspaceProxy
updateProxyColor color maybeProxy =
    case maybeProxy of
        Just proxy ->
            Just { proxy | proxyColor = color }

        option2 ->
            Nothing


composeWorkspacesProxy : List Int -> Dict Int Workspace -> Dict Int WorkspaceProxy
composeWorkspacesProxy workspacesIds workspacesInfos =
    let
        createProxy maybeInfo =
            case maybeInfo of
                Just info ->
                    WorkspaceProxy info.id info.color info.name info.key Read info.tabs

                Nothing ->
                    WorkspaceProxy 0 Gray "" "" Read []
    in
    Dict.fromList <|
        List.map
            (\name ->
                ( name, createProxy <| Dict.get name workspacesInfos )
            )
            workspacesIds



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ viewHeader model
        , div [ class "grid gridTemplateCol-repeat-xl gridGap-m padding-m justifyContent-center" ]
            (model.data.workspacesIds
                |> List.map
                    (\name ->
                        Dict.get name model.data.workspacesInfo
                    )
                |> List.map
                    (\maybeWorkspace ->
                        case maybeWorkspace of
                            Just workspace ->
                                Dict.get workspace.id model.workspacesProxy
                                    |> viewWorkspace workspace

                            Nothing ->
                                text ""
                    )
            )
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        viewName id =
            case Dict.get id model.data.workspacesInfo of
                Just { name, color } ->
                    h2 [ class <| "color-" ++ fromColorToString color ]
                        [ text name ]

                Nothing ->
                    text ""
    in
    div [ class "full-width height-s background-transparent sticky backdrop-filter-blur boxShadow-black zIndex-4 marginBottom-xl flex alignItems-center justifyContent-center" ]
        [ case model.data.state of
            WorkspaceInUse id ->
                viewName id

            _ ->
                text ""
        ]


viewWorkspace : Workspace -> Maybe WorkspaceProxy -> Html Msg
viewWorkspace workspace maybeWorkspaceProxy =
    case maybeWorkspaceProxy of
        Just workspaceProxy ->
            let
                body =
                    div [ class "padding-m" ] <| List.map viewTab workspace.tabs

                openWorkspace =
                    case workspaceProxy.state of
                        Read ->
                            OpenWorkspace workspace.id

                        Edition ->
                            NoOp
            in
            div
                [ class "borderTop-s rounded opacity-70 height-fit-content background-black-2"
                , onClick openWorkspace
                ]
                [ viewWorkspaceHeader workspace workspaceProxy
                , body
                ]

        Nothing ->
            text ""


viewWorkspaceHeader : Workspace -> WorkspaceProxy -> Html Msg
viewWorkspaceHeader workspace workspaceProxy =
    case workspaceProxy.state of
        Read ->
            viewWorkspaceHeaderInRead workspace

        Edition ->
            viewWorkspaceHeaderInEdition workspace.id workspaceProxy


viewWorkspaceHeaderInRead : Workspace -> Html Msg
viewWorkspaceHeaderInRead { id, name, color } =
    let
        viewName =
            h3
                [ class <| "marginTop-none fontWeight-200 opacity-70 color-" ++ fromColorToString color ]
                [ text name ]

        editButton =
            button
                [ class "padding-m background-secondary rounded marginLeft-l marginBottom-xs color-contrast show-in-hover"
                , customOnClick <| EditWorkspace id
                ]
                [ text "Edit" ]
    in
    div [ class "padding-m flex alignItems-center justifyContent-space-between background-black" ]
        [ viewName
        , editButton
        ]


viewWorkspaceHeaderInEdition : Int -> WorkspaceProxy -> Html Msg
viewWorkspaceHeaderInEdition workspaceId proxy =
    let
        inputName =
            input
                [ class <| "fontSize-l background-transparent marginTop-none marginBottom-m fontWeight-200 opacity-70 color-" ++ fromColorToString proxy.proxyColor
                , Html.Attributes.selected True
                , Html.Attributes.autofocus True
                , Html.Attributes.value proxy.proxyName
                , Html.Events.onInput <| ChangeProxyName workspaceId
                ]
                []

        saveButton =
            button
                [ class "padding-m background-secondary rounded marginLeft-l marginBottom-xs color-contrast show-in-hover"
                , customOnClick <| UpdateWorkspace proxy
                ]
                [ text "Save" ]

        radio color =
            let
                isChecked =
                    color == proxy.proxyColor

                stringColor =
                    fromColorToString color

                handleOnInput value =
                    ChangeProxyColor workspaceId <| fromStringToColor value
            in
            label [ class "radioLabel" ]
                [ input
                    [ type_ "radio"
                    , name <| String.fromInt workspaceId ++ "-" ++ stringColor
                    , class "absolute width-0 height-0"
                    , checked isChecked
                    , Html.Attributes.value stringColor
                    , onInput handleOnInput
                    ]
                    []
                , span [ class <| "checkmark background-" ++ stringColor ] []
                ]

        colorsGroup =
            div [ class "flex" ]
                [ radio Green
                , radio Blue
                , radio Orange
                , radio Purple
                , radio Yellow
                , radio Red
                , radio Gray
                , radio Cyan
                ]
    in
    div [ class "padding-m flex flexDirection-col background-black" ]
        [ div [ class "flex alignItems-center justifyContent-space-between" ]
            [ inputName
            , saveButton
            ]
        , colorsGroup
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



-- HELPERS


customOnClick : Msg -> Attribute Msg
customOnClick msg =
    Html.Events.custom
        "click"
        (Decode.succeed
            { stopPropagation = True
            , preventDefault = True
            , message = msg
            }
        )


fromColorToString : Color -> String
fromColorToString color =
    case color of
        Green ->
            "green"

        Blue ->
            "blue"

        Orange ->
            "orange"

        Purple ->
            "purple"

        Yellow ->
            "yellow"

        Red ->
            "red"

        Gray ->
            "gray"

        Cyan ->
            "cyan"


fromStringToColor : String -> Color
fromStringToColor str =
    case str of
        "green" ->
            Green

        "blue" ->
            Blue

        "orange" ->
            Orange

        "purple" ->
            Purple

        "yellow" ->
            Yellow

        "red" ->
            Red

        "gray" ->
            Gray

        "cyan" ->
            Cyan

        _ ->
            Gray



-- DECODERS


dataDecoder : Decoder Data
dataDecoder =
    Decode.field "data" <|
        Decode.map3 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)


workspacesInfoDecoder : Decoder (Dict Int Workspace)
workspacesInfoDecoder =
    Decode.dict workspaceDecoder
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


workspaceDecoder : Decoder Workspace
workspaceDecoder =
    Decode.map5 Workspace
        (Decode.field "id" Decode.int)
        (Decode.field "color" colorDecoder)
        (Decode.field "key" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "tabs" tabListDecoder)


colorDecoder : Decoder Color
colorDecoder =
    Decode.string
        |> Decode.andThen (Decode.succeed << fromStringToColor)


tabListDecoder : Decoder (List Tab)
tabListDecoder =
    Decode.list tabDecoder


tabDecoder : Decoder Tab
tabDecoder =
    Decode.map3 Tab
        (Decode.field "title" Decode.string)
        (Decode.field "url" Decode.string)
        (Decode.maybe <| Decode.field "favIconUrl" Decode.string)



-- ENCODERS


encodeWorkspaceProxy : WorkspaceProxy -> Encode.Value
encodeWorkspaceProxy proxy =
    Encode.object
        [ ( "id", Encode.int proxy.id )
        , ( "key", Encode.string proxy.key )
        , ( "name", Encode.string proxy.proxyName )
        , ( "color", Encode.string <| fromColorToString proxy.proxyColor )
        , ( "tabs", Encode.list encodeTab proxy.tabs )
        ]


encodeTab : Tab -> Encode.Value
encodeTab tab =
    Encode.object
        [ ( "url", Encode.string tab.url )
        , ( "title", Encode.string tab.title )
        , ( "favIconUrl", encodeIcon tab.icon )
        ]


encodeIcon : Maybe String -> Encode.Value
encodeIcon maybeIcon =
    case maybeIcon of
        Just icon ->
            Encode.string icon

        Nothing ->
            Encode.string ""
