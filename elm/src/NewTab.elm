module NewTab exposing (..)

import Browser
import Browser.Dom as Dom
import Color as C
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Ports
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Task
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


type Status
    = NoInitiated
    | Idle
    | NoData
    | WorkspaceInUse W.WorkspaceId
    | OpeningWorkspace W.WorkspaceId
    | DeletingWorkspace W.WorkspaceId


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , state : Status
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
    , numTabsInUse : Int
    }


type alias Model =
    { data : Data
    , cards : List ( W.WorkspaceId, CardStatus )
    , status : Status
    }


type alias Flags =
    { window : Int }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , state = NoInitiated
        , workspacesInfo = Dict.empty
        , numTabsInUse = 0
        }
    , cards = []
    , status = NoInitiated
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
    | PressedDeleteConfirmationButton W.WorkspaceId
    | PressedCancelDeletionButton
    | ChangeField W.WorkspaceId (String -> W.Workspace -> W.Workspace) String
    | TryFocusElement (Result Dom.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceivedDataFromJS (Ok data) ->
            ( { model
                | data = data
                , cards = List.map (\workspaceId -> ( workspaceId, Showing )) data.workspacesIds
                , status = data.state
              }
            , Cmd.none
            )

        ReceivedDataFromJS (Err error) ->
            ( model, Cmd.none )

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
            ( { model | status = DeletingWorkspace workspaceId }, Cmd.none )

        PressedDeleteConfirmationButton workspaceId ->
            ( model, Ports.deleteWorkspace workspaceId )

        PressedCancelDeletionButton ->
            ( { model | status = model.data.state }, Cmd.none )

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

        TryFocusElement _ ->
            ( model, Cmd.none )


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
    case model.status of
        DeletingWorkspace workspaceId ->
            div [ Html.Attributes.class "relative" ]
                [ viewHeader model
                , viewCards model.cards model.data
                , case Dict.get workspaceId model.data.workspacesInfo of
                    Just workspace ->
                        viewDeletingWorkspace workspace

                    Nothing ->
                        Html.text ""
                ]

        _ ->
            div []
                [ viewHeader model
                , viewCards model.cards model.data
                ]


viewDeletingWorkspace : W.Workspace -> Html Msg
viewDeletingWorkspace {id, name, color} =
    let
        rootContainerStyle =
            String.join " "
                [ "flex"
                , "justifyContent-center"
                , "alignItems-center"
                , "flexDirection-col"
                , "full-height"
                , "full-width"
                , "top-0"
                , "left-0"
                , "zIndex-4"
                , "background-transparent"
                , "backdrop-filter-blur"
                , "fixed"
                ]

        workspaceName =
            span [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
                [ Html.text name ]

        buttonStyle =
            [ "padding-m hover margin-l rounded fontSize-s" ]

        cancelButtonStyle =
            String.join " " <| buttonStyle ++ [ "background-contrast" ]

        deleteButtonStyle =
            String.join " " <| buttonStyle ++ [ "background-red" ]
    in
    div [ Html.Attributes.class rootContainerStyle ]
        [ h2 [ Html.Attributes.class "color-contrast" ]
            [ Html.text "You are deleting "
            , workspaceName
            ]
        , div [ Html.Attributes.class "marginTop-xl" ]
            [ button
                [ onClick PressedCancelDeletionButton
                , Html.Attributes.class cancelButtonStyle
                ]
                [ Html.text "Cancel" ]
            , button
                [ onClick <| PressedDeleteConfirmationButton id
                , Html.Attributes.class deleteButtonStyle
                ]
                [ Html.text "Delete" ]
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        style =
            String.join " "
                [ "full-width"
                , "height-m"
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

        viewName id =
            case Dict.get id model.data.workspacesInfo of
                Just { name, color } ->
                    h2 [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
                        [ Html.text name ]

                Nothing ->
                    Html.text ""
    in
    div [ Html.Attributes.class style ]
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

        removeCardsOfOtherCols ( id, _ ) =
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
                    Html.Attributes.class <|
                        String.join " "
                            [ "width-s"
                            , "height-s"
                            , "background-secondary"
                            , "circle marginLeft-l"
                            , "marginBottom-xs"
                            , "color-contrast show-in-hover"
                            , "inline-flex"
                            , "justifyContent-center"
                            , "alignItems-center"
                            ]

                actions =
                    div []
                        [ button
                            [ buttonStyle
                            , customOnClick <| PressedEditButton id
                            ]
                            [ img
                                [ Html.Attributes.class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/pencil.svg"
                                ]
                                []
                            ]
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
                    Html.Attributes.class <|
                        String.join " "
                            [ "width-s"
                            , "height-s"
                            , "background-secondary"
                            , "circle marginLeft-l"
                            , "marginBottom-xs"
                            , "color-contrast show-in-hover"
                            , "inline-flex"
                            , "justifyContent-center"
                            , "alignItems-center"
                            ]
            in
            div [ Html.Attributes.class "padding-m flex flexDirection-col background-black" ]
                [ div [ Html.Attributes.class "flex alignItems-center justifyContent-space-between" ]
                    [ inputName
                    , div []
                        [ button
                            [ buttonStyle
                            , customOnClick <| PressedDeleteButton workspace.id
                            ]
                            [ img
                                [ Html.Attributes.class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/trash.svg"
                                ]
                                []
                            ]
                        , button
                            [ buttonStyle
                            , customOnClick <| PressedSaveButton workspace
                            ]
                            [ img
                                [ Html.Attributes.class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/save.svg"
                                ]
                                []
                            ]
                        , button
                            [ buttonStyle
                            , customOnClick <| PressedCancelButton workspace.id
                            ]
                            [ img
                                [ Html.Attributes.class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/close.svg"
                                ]
                                []
                            ]
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
        , span [ Html.Attributes.class "flex-1 ellipsis overflow-hidden whiteSpace-nowrap color-contrast" ]
            [ Html.text title ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- TASKS


focusElement : String -> Cmd Msg
focusElement elementId =
    Task.attempt TryFocusElement (Dom.focus elementId)



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
        Decode.map4 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)
            (Decode.field "numTabs" Decode.int)


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
    Decode.field "state" Decode.string
        |> Decode.andThen
            (\state ->
                case state of
                    "workspaceInUse" ->
                        Decode.map WorkspaceInUse <|
                            Decode.field "workspaceInUse" Decode.int

                    "openingWorkspace" ->
                        Decode.map OpeningWorkspace <|
                            Decode.field "workspaceInUse" Decode.int

                    "noData" ->
                        Decode.succeed NoData

                    _ ->
                        Decode.succeed Idle
            )


statusFromString : String -> Decoder Status
statusFromString status =
    case status of
        "noData" ->
            Decode.succeed NoData

        _ ->
            Decode.succeed Idle
