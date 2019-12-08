module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Json.Encode as Encode exposing (..)
import Ports
import Svg exposing (..)
import Svg.Attributes exposing (..)



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


type alias WorkspaceId =
    Int


type CardStatus
    = Showing
    | Editing Workspace


type State
    = NoInitated
    | Started
    | WorkspaceInUse WorkspaceId


type alias Tab =
    { title : String
    , url : String
    , icon : Maybe String
    }


type alias Workspace =
    { id : WorkspaceId
    , color : Color
    , key : String
    , name : String
    , tabs : List Tab
    }


type alias Data =
    { workspacesIds : List WorkspaceId
    , state : State
    , workspacesInfo : Dict WorkspaceId Workspace
    }


type alias Model =
    { data : Data
    , test : String
    , cards : List ( WorkspaceId, CardStatus )
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
    , cards = []
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace WorkspaceId
    | PressedCancelButton WorkspaceId
    | PressedSaveButton Workspace
    | PressedEditButton WorkspaceId
    | PressedDeleteButton WorkspaceId
    | ChangeField WorkspaceId (String -> Workspace -> Workspace) String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedDataFromJS (Ok data) ->
            ( { model
                | data = data
                , cards = List.map (\workspaceId -> ( workspaceId, Showing )) data.workspacesIds
              }
            , Cmd.none
            )

        ReceivedDataFromJS (Err error) ->
            ( { model | test = "error" }, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )

        PressedCancelButton workspaceId ->
            let
                cards =
                    resetCardsToShowingStatus model.cards
            in
            ( { model | cards = cards }, Cmd.none )

        PressedSaveButton workspace ->
            ( model, Ports.updateWorkspace <| encodeWorkspace workspace )

        PressedEditButton workspaceId ->
            case Dict.get workspaceId model.data.workspacesInfo of
                Just workspace ->
                    ( { model
                        | cards =
                            model.cards
                                |> resetCardsToShowingStatus
                                |> changeCardStatus workspaceId (Editing workspace)
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        PressedDeleteButton workspaceId ->
            ( model, Ports.deleteWorkspace workspaceId )

        ChangeField workspaceId setter value ->
            ( { model
                | cards =
                    List.map
                        (\( id, cardStatus ) ->
                            if id == workspaceId then
                                case cardStatus of
                                    Editing workspace ->
                                        ( id, Editing <| setter value workspace )

                                    _ ->
                                        ( id, cardStatus )

                            else
                                ( id, cardStatus )
                        )
                        model.cards
              }
            , Cmd.none
            )


resetCardsToShowingStatus : List ( WorkspaceId, CardStatus ) -> List ( WorkspaceId, CardStatus )
resetCardsToShowingStatus cards =
    let
        toShowing ( id, _ ) =
            ( id, Showing )
    in
    List.map toShowing cards


changeCardStatus : WorkspaceId -> CardStatus -> List ( WorkspaceId, CardStatus ) -> List ( WorkspaceId, CardStatus )
changeCardStatus workspaceId newStatus cards =
    let
        changeStatus ( id, status ) =
            if id == workspaceId then
                ( id, newStatus )

            else
                ( id, status )
    in
    List.map changeStatus cards


setName : String -> Workspace -> Workspace
setName newName workspace =
    { workspace | name = newName }


setColor : String -> Workspace -> Workspace
setColor color workspace =
    { workspace | color = fromStringToColor color }



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ viewHeader model
        , viewCards model.cards model.data
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        viewName id =
            case Dict.get id model.data.workspacesInfo of
                Just { name, color } ->
                    h2 [ Html.Attributes.class <| "color-" ++ fromColorToString color ]
                        [ Html.text name ]

                Nothing ->
                    Html.text ""
    in
    div [ Html.Attributes.class "full-width height-s background-transparent sticky backdrop-filter-blur boxShadow-black zIndex-4 marginBottom-xl flex alignItems-center justifyContent-center" ]
        [ case model.data.state of
            WorkspaceInUse id ->
                viewName id

            _ ->
                Html.text ""
        ]


viewCards : List ( WorkspaceId, CardStatus ) -> Data -> Html Msg
viewCards cards { workspacesInfo } =
    let
        numColumns =
            3

        assignToCol bucket index ( id, cardStatus ) =
            if modBy numColumns index == bucket then
                ( id, cardStatus )

            else
                ( -1, cardStatus )

        removeCardsOfOtherCols ( id, cardStatus ) =
            not (id == -1)

        createCard =
            viewCard workspacesInfo

        col0 =
            cards
                |> List.indexedMap (assignToCol 0)
                |> List.filter removeCardsOfOtherCols
                |> List.map createCard

        col1 =
            cards
                |> List.indexedMap (assignToCol 1)
                |> List.filter removeCardsOfOtherCols
                |> List.map createCard

        col2 =
            cards
                |> List.indexedMap (assignToCol 2)
                |> List.filter removeCardsOfOtherCols
                |> List.map createCard
    in
    div [ Html.Attributes.class "grid gridTemplateCol-repeat-xl gridGap-m padding-m justifyContent-center" ]
        [ div [] col0
        , div [] col1
        , div [] col2
        ]



--List.map (viewCard workspacesInfo) cards


viewCard : Dict WorkspaceId Workspace -> ( WorkspaceId, CardStatus ) -> Html Msg
viewCard workspacesInfo ( workspaceId, cardStatus ) =
    case cardStatus of
        Showing ->
            case Dict.get workspaceId workspacesInfo of
                Just workspace ->
                    viewShowingCard workspace

                Nothing ->
                    Html.text ""

        Editing workspace ->
            viewEditingCard workspace


viewShowingCard : Workspace -> Html Msg
viewShowingCard { id, name, color, tabs } =
    let
        header =
            let
                viewName =
                    h3
                        [ Html.Attributes.class <| "marginTop-none fontWeight-200 color-" ++ fromColorToString color ]
                        [ Html.text name ]

                buttonStyle =
                    Html.Attributes.class "width-xs height-xs background-secondary circle marginLeft-l marginBottom-xs color-contrast show-in-hover"

                actions =
                    div []
                        [ button
                            [ buttonStyle
                            , customOnClick <| PressedEditButton id
                            ]
                            [ Html.text "E" ]
                        ]
            in
            div [ Html.Attributes.class "padding-m flex alignItems-center justifyContent-space-between background-black" ]
                [ viewName
                , actions
                ]

        body =
            div [ Html.Attributes.class "padding-m opacity-70" ] <| List.map viewTab tabs
    in
    div
        [ Html.Attributes.class <| "borderTop-s rounded height-fit-content background-black-2 cursor-rocket marginBottom-xl"
        , onClick <| OpenWorkspace id
        ]
        [ header
        , body
        ]


viewEditingCard : Workspace -> Html Msg
viewEditingCard workspace =
    let
        body =
            div [ Html.Attributes.class "padding-m opacity-70" ] <| List.map viewTab workspace.tabs

        header =
            let
                inputName =
                    input
                        [ Html.Attributes.class <| "fontSize-l background-transparent marginTop-none marginBottom-m fontWeight-200 color-" ++ fromColorToString workspace.color
                        , Html.Attributes.selected True
                        , Html.Attributes.autofocus True
                        , Html.Attributes.value workspace.name
                        , Html.Events.onInput <| ChangeField workspace.id setName
                        ]
                        []

                buttonStyle =
                    Html.Attributes.class "width-xs height-xs background-secondary circle marginLeft-l marginBottom-xs color-contrast show-in-hover"
            in
            div [ Html.Attributes.class "padding-m flex flexDirection-col background-black" ]
                [ div [ Html.Attributes.class "flex alignItems-center justifyContent-space-between" ]
                    [ inputName
                    , div []
                        [ button
                            [ buttonStyle
                            , customOnClick <| PressedDeleteButton workspace.id
                            ]
                            [ Html.text "D" ]
                        , button
                            [ buttonStyle
                            , customOnClick <| PressedSaveButton workspace
                            ]
                            [ Html.text "S" ]
                        , button
                            [ buttonStyle
                            , customOnClick <| PressedCancelButton workspace.id
                            ]
                            [ Html.text "X" ]
                        ]
                    ]
                , viewRadioGroupColors workspace.id workspace.color
                ]
    in
    div
        [ Html.Attributes.class <| "borderTop-s rounded height-fit-content background-black-2 marginBottom-xl"
        , onClick NoOp
        ]
        [ header
        , body
        ]


viewRadioGroupColors : WorkspaceId -> Color -> Html Msg
viewRadioGroupColors workspaceId color =
    let
        radio color_ =
            let
                isChecked =
                    color_ == color

                stringColor =
                    fromColorToString color_

                handleOnInput value =
                    ChangeField workspaceId setColor value
            in
            label [ Html.Attributes.class "radioLabel" ]
                [ input
                    [ Html.Attributes.type_ "radio"
                    , Html.Attributes.name <| String.fromInt workspaceId ++ "-" ++ stringColor
                    , Html.Attributes.class "absolute width-0 height-0"
                    , checked isChecked
                    , Html.Attributes.value stringColor
                    , onInput handleOnInput
                    ]
                    []
                , span [ Html.Attributes.class <| "checkmark background-" ++ stringColor ] []
                ]
    in
    div [ Html.Attributes.class "flex opacity-70" ]
        [ radio Green
        , radio Blue
        , radio Orange
        , radio Purple
        , radio Yellow
        , radio Red
        , radio Gray
        , radio Cyan
        ]


viewTab : Tab -> Html Msg
viewTab { title, url, icon } =
    div [ Html.Attributes.class "flex alignItems-center marginBottom-s" ]
        [ img
            [ src <| Maybe.withDefault "" icon
            , Html.Attributes.class "width-xs height-xs beforeBackgroundColor-secondary marginRight-s beforeBackgroundColor-secondary"
            ]
            []
        , span [ Html.Attributes.class "flex-1 ellipsis overflowHidden whiteSpace-nowrap color-contrast" ]
            [ Html.text title ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- HELPERS


customOnClick : Msg -> Html.Attribute Msg
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


workspacesInfoDecoder : Decoder (Dict WorkspaceId Workspace)
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


encodeWorkspace : Workspace -> Encode.Value
encodeWorkspace workspace =
    Encode.object
        [ ( "id", Encode.int workspace.id )
        , ( "key", Encode.string workspace.key )
        , ( "name", Encode.string workspace.name )
        , ( "color", Encode.string <| fromColorToString workspace.color )
        , ( "tabs", Encode.list encodeTab workspace.tabs )
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
    Encode.string <| Maybe.withDefault "" maybeIcon
