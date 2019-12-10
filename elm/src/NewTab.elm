module NewTab exposing (..)

import Browser
import Color as C
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Json.Encode as Encode exposing (..)
import Ports
import Svg exposing (..)
import Svg.Attributes exposing (..)
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


type CardStatus
    = Showing
    | Editing W.Workspace


type State
    = NoInitated
    | Started
    | WorkspaceInUse W.WorkspaceId


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , state : State
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
    }


type alias Model =
    { data : Data
    , test : String
    , cards : List ( W.WorkspaceId, CardStatus )
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
    | OpenWorkspace W.WorkspaceId
    | PressedCancelButton W.WorkspaceId
    | PressedSaveButton W.Workspace
    | PressedEditButton W.WorkspaceId
    | PressedDeleteButton W.WorkspaceId
    | ChangeField W.WorkspaceId (String -> W.Workspace -> W.Workspace) String


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
            ( model, Ports.updateWorkspace <| W.encode workspace )

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


resetCardsToShowingStatus : List ( W.WorkspaceId, CardStatus ) -> List ( W.WorkspaceId, CardStatus )
resetCardsToShowingStatus cards =
    let
        toShowing ( id, _ ) =
            ( id, Showing )
    in
    List.map toShowing cards


changeCardStatus : W.WorkspaceId -> CardStatus -> List ( W.WorkspaceId, CardStatus ) -> List ( W.WorkspaceId, CardStatus )
changeCardStatus workspaceId newStatus cards =
    let
        changeStatus ( id, status ) =
            if id == workspaceId then
                ( id, newStatus )

            else
                ( id, status )
    in
    List.map changeStatus cards


setName : String -> W.Workspace -> W.Workspace
setName newName workspace =
    { workspace | name = newName }


setColor : String -> W.Workspace -> W.Workspace
setColor color workspace =
    { workspace | color = C.fromStringToColor color }



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
                    h2 [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
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


viewCards : List ( W.WorkspaceId, CardStatus ) -> Data -> Html Msg
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


viewCard : Dict W.WorkspaceId W.Workspace -> ( W.WorkspaceId, CardStatus ) -> Html Msg
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


viewShowingCard : W.Workspace -> Html Msg
viewShowingCard { id, name, color, tabs } =
    let
        header =
            let
                viewName =
                    h3
                        [ Html.Attributes.class <| "marginTop-none fontWeight-200 color-" ++ C.fromColorToString color ]
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


viewEditingCard : W.Workspace -> Html Msg
viewEditingCard workspace =
    let
        body =
            div [ Html.Attributes.class "padding-m opacity-70" ] <| List.map viewTab workspace.tabs

        header =
            let
                inputName =
                    input
                        [ Html.Attributes.class <| "fontSize-l background-transparent marginTop-none marginBottom-m fontWeight-200 color-" ++ C.fromColorToString workspace.color
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


viewRadioGroupColors : W.WorkspaceId -> C.Color -> Html Msg
viewRadioGroupColors workspaceId color =
    let
        radio color_ =
            let
                isChecked =
                    color_ == color

                stringColor =
                    C.fromColorToString color_

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
        [ radio C.Green
        , radio C.Blue
        , radio C.Orange
        , radio C.Purple
        , radio C.Yellow
        , radio C.Red
        , radio C.Gray
        , radio C.Cyan
        ]


viewTab : W.Tab -> Html Msg
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
