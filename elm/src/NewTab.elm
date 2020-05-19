module NewTab exposing (main)

import Browser
import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events as Events
import Json.Decode as Decode exposing (..)
import MyColor exposing (MyColor)
import Ports
import Task
import Theme exposing (Theme)
import Workspace exposing (Workspace)



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


type alias Flags =
    ()


type CardStatus
    = Showing
    | Editing Workspace


type Status
    = NoInitiated
    | Idle
    | NoData
    | WorkspaceInUse Workspace.Id
    | OpeningWorkspace Workspace.Id
    | DeletingWorkspace Workspace.Id


type alias Data =
    { workspacesIds : List Workspace.Id
    , state : Status
    , workspacesInfo : Dict Workspace.Id Workspace
    , numTabsInUse : Int
    , theme : Theme
    }


type alias Model =
    { data : Data
    , cards : List ( Workspace.Id, CardStatus )
    , status : Status
    , error : String
    }



initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , state = NoInitiated
        , workspacesInfo = Dict.empty
        , numTabsInUse = 0
        , theme = Theme.default
        }
    , cards = []
    , status = NoInitiated
    , error = ""
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace Workspace.Id
    | PressedCancelButton Workspace.Id
    | PressedSaveButton Workspace
    | PressedEditButton Workspace.Id
    | PressedDeleteButton Workspace.Id
    | PressedDeleteConfirmationButton Workspace.Id
    | PressedCancelDeletionButton
    | ChangeField Workspace.Id (String -> Workspace -> Workspace) String
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
            ( { model | error = Debug.toString error }, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )

        PressedCancelButton _ ->
            let
                cards =
                    resetCardsToShowingStatus model.cards
            in
            ( { model | cards = cards }, Cmd.none )

        PressedSaveButton workspace ->
            ( model, Ports.updateWorkspace <| Workspace.encode workspace )

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


resetCardsToShowingStatus : List ( Workspace.Id, CardStatus ) -> List ( Workspace.Id, CardStatus )
resetCardsToShowingStatus cards =
    let
        toShowing ( id, _ ) =
            ( id, Showing )
    in
    List.map toShowing cards


changeCardStatus : Workspace.Id -> CardStatus -> List ( Workspace.Id, CardStatus ) -> List ( Workspace.Id, CardStatus )
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


setMyColor : String -> Workspace -> Workspace
setMyColor color workspace =
    { workspace | color = MyColor.toMyColor color }



-- VIEW


view : Model -> Html Msg
view model =
    div [ class <| "root " ++ Theme.toString model.data.theme  ] <|
        case model.status of
            DeletingWorkspace workspaceId ->
                [ viewHeader model
                , viewCards model.cards model.data
                , case Dict.get workspaceId model.data.workspacesInfo of
                    Just workspace ->
                        viewDeletingWorkspace workspace

                    Nothing ->
                        text ""
                ]

            NoData ->
                [ viewListWokspaceEmptyState
                ]

            _ ->
                [ viewHeader model
                , case model.cards of
                    [] ->
                        viewListWokspaceEmptyState

                    _ ->
                        viewCards model.cards model.data
                ]


viewListWokspaceEmptyState : Html Msg
viewListWokspaceEmptyState =
    let
        title =
            h3 [ class "text-secondary text-center gutter-bottom-xl" ]
                [ text "You don't have more workspaces created" ]

        thumbnail =
            div [ class "rounded stretch-inset-m border-m border-deep-2" ]
                [ div [ class "flex gutter-bottom-m" ]
                    [ span [ class "background-deep-4 circle-s gutter-right-s" ]
                        []
                    , span [ class "background-deep-2 rounded inset-xs width-m" ]
                        []
                    ]
                , div [ class "flex gutter-bottom-m" ]
                    [ span [ class "background-deep-4 circle-s gutter-right-s" ]
                        []
                    , span [ class "background-deep-2 rounded inset-xs width-m" ]
                        []
                    ]
                , div [ class "flex" ]
                    [ span [ class "background-deep-4 circle-s gutter-right-s" ]
                        []
                    , span [ class "background-deep-2 rounded inset-xs width-m" ]
                        []
                    ]
                , div [ class "absolute" ]
                    []
                ]
    in
    div [ class "flex column flex-1 justify-center align-center" ]
        [ title
        , thumbnail
        ]


viewDeletingWorkspace : Workspace -> Html Msg
viewDeletingWorkspace {id, name} =
    let
        rootContainerStyle =
            String.join " "
                [ "flex"
                , "justify-center"
                , "align-center"
                , "column"
                , "full-height"
                , "full-width"
                , "top-0"
                , "left-0"
                , "z-index-4"
                , "background-transparent"
                , "backdrop-filter-blur"
                , "fixed"
                ]

        workspaceName =
            span [ class "text-primary" ]
                [ text name ]

        buttonStyle =
            [ "squish-inset-m hover outer-l rounded text-m bold text-primary-high-contrast" ]

        cancelButtonStyle =
            String.join " " <| buttonStyle ++ [ "background-deep-3" ]

        deleteButtonStyle =
            String.join " " <| buttonStyle ++ [ "background-warning gutter-right-m" ]
    in
    div [ class rootContainerStyle ]
        [ div [ class "inset-l background-deep-0 rounded flex column align-end" ]
            [ h2 [ class "text-primary gutter-bottom-m" ]
                [ text "You are deleting "
                , workspaceName
                ]
            , div []
                [ button
                    [ Events.onClick <| PressedDeleteConfirmationButton id
                    , class deleteButtonStyle
                    ]
                    [ text "Delete" ]
                , button
                    [ Events.onClick PressedCancelDeletionButton
                    , class cancelButtonStyle
                    ]
                    [ text "Cancel" ]
                ]
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        style =
            String.join " "
                [ "full-width"
                , "squish-inset-m"
                , "sticky"
                , "flex"
                , "align-center"
                , "justify-center"
                , "gutter-bottom-xl"
                ]
    in
    case model.data.state of
        WorkspaceInUse id ->
            case Dict.get id model.data.workspacesInfo of
                Just {name, color} ->
                    div [ class <| style ++ " " ++ MyColor.toBackgroundCSS color ]
                        [ h2 [ class "text-primary-high-contrast" ]
                            [ text name ]
                        ]

                Nothing ->
                    text ""

        _ ->
            div [ class style ]
                [ text "" ]



viewCards : List ( Workspace.Id, CardStatus ) -> Data -> Html Msg
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
    div [ class "grid gridTemplateCol-repeat-xl gridGap-m inset-m justify-center" ]
        [ div [] col0
        , div [] col1
        , div [] col2
        ]


viewCard : Dict Workspace.Id Workspace -> ( Workspace.Id, CardStatus ) -> Html Msg
viewCard workspacesInfo ( workspaceId, cardStatus ) =
    case cardStatus of
        Showing ->
            case Dict.get workspaceId workspacesInfo of
                Just workspace ->
                    viewShowingCard workspace

                Nothing ->
                    text ""

        Editing workspace ->
            viewEditingCard workspace


viewShowingCard : Workspace -> Html Msg
viewShowingCard workspace =
    let
        header =
            let
                viewName =
                    h3 [ class "font-weight-200 text-primary-high-contrast" ]
                        [ text workspace.name ]

                buttonStyle =
                    String.join " "
                        [ "width-s"
                        , "height-s"
                        , "circle"
                        , "gutter-bottom-xs"
                        , "color-contrast"
                        , "inline-flex"
                        , "justify-center"
                        , "align-center"
                        ]

                actions =
                    div [ class "show-in-hover" ]
                        [ button
                            [ class <| buttonStyle ++ " gutter-right-s"
                            , customOnClick <| OpenWorkspace workspace.id
                            ]
                            [ img
                                [ class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/globe.svg"
                                ]
                                []
                            ]
                        , button
                            [ class <| buttonStyle
                            , customOnClick <| PressedEditButton workspace.id
                            ]
                            [ img
                                [ class "height-xs width-xs hover-opacity"
                                , src "/assets/icons/pencil.svg"
                                ]
                                []
                            ]
                        ]
            in
            div [ class <| "squish-inset-m flex align-center justify-space-between " ++ MyColor.toBackgroundCSS workspace.color ]
                [ viewName
                , actions
                ]
    in
    div [ class "rounded overflow-hidden height-fit-content gutter-bottom-xl background-deep-1 show-in-hover-parent" ]
        [ header
        , viewTabList workspace.tabs
        ]


viewEditingCard : Workspace -> Html Msg
viewEditingCard workspace =
    let
        header =
            let
                inputName =
                    input
                        [ type_ "text"
                        , class "text-l rounded text-primary"
                        , selected True
                        , autofocus True
                        , Html.Attributes.value workspace.name
                        , Events.onInput <| ChangeField workspace.id setName
                        ]
                        []

                buttonStyle =
                    String.join " "
                        [ "width-s"
                        , "height-s"
                        , "circle"
                        , "color-contrast"
                        , "inline-flex"
                        , "justify-center"
                        , "align-center"
                        ]
            in
            div [ class "squish-inset-m flex column overflow-hidden" ]
                [ div [ class "flex align-center justify-space-between gutter-bottom-s" ]
                    [ inputName
                    , div []
                        [ button
                            [ class <| buttonStyle ++ " gutter-right-s"
                            , customOnClick <| PressedDeleteButton workspace.id
                            ]
                            [ img
                                [ class "height-s width-s dynamic hover-opacity"
                                , src "/assets/icons/trash.svg"
                                ]
                                []
                            ]
                        , button
                            [ class <| buttonStyle ++ " gutter-right-s"
                            , customOnClick <| PressedSaveButton workspace
                            ]
                            [ img
                                [ class "height-s width-s dynamic hover-opacity"
                                , src "/assets/icons/save.svg"
                                ]
                                []
                            ]
                        , button
                            [ class buttonStyle
                            , customOnClick <| PressedCancelButton workspace.id
                            ]
                            [ img
                                [ class "height-s width-s dynamic hover-opacity"
                                , src "/assets/icons/close.svg"
                                ]
                                []
                            ]
                        ]
                    ]
                , viewRadioGroupMyColors workspace.id workspace.color
                ]
    in
    div
        [ class "rounded height-fit-content background-deep-1 gutter-bottom-xl"
        , Events.onClick NoOp
        ]
        [ header
        , viewTabList workspace.tabs
        ]


viewRadioGroupMyColors : Workspace.Id -> MyColor -> Html Msg
viewRadioGroupMyColors workspaceId colorSelected =
    let
        radio selectableColor =
            let
                isChecked =
                    selectableColor == colorSelected

                backgroundMyColor =
                    MyColor.toBackgroundCSS selectableColor

                handleOnInput value =
                    ChangeField workspaceId setMyColor value
            in
            label [ class "radioLabel" ]
                [ input
                    [ type_ "radio"
                    , name <| "w-" ++ String.fromInt workspaceId
                    , class "absolute width-0 height-0"
                    , checked isChecked
                    , Html.Attributes.value <| MyColor.toString selectableColor
                    , Events.onInput handleOnInput
                    ]
                    []
                , span [ class <| "checkmark " ++ backgroundMyColor ] []
                ]
    in
    div [ class "flex opacity-70" ] <|
        List.map radio MyColor.list


viewTabList : List Workspace.Tab -> Html Msg
viewTabList tabs =
    ul [ class "inset-s" ] <|
        List.map viewTab tabs


viewTab : Workspace.Tab -> Html Msg
viewTab tab =
    let
        buttonStyle =
            String.join " "
                [ "width-xs"
                , "height-xs"
                , "circle"
                , "color-contrast"
                , "inline-flex"
                , "justify-center"
                , "align-center"
                ]
    in
    li [ class "flex rounded align-center inset-s show-in-hover-inner-parent hover-background-deep-2" ]
        [ img
            [ src <| Maybe.withDefault "" tab.icon
            , class "width-xs height-xs gutter-right-s"
            ]
            []
        , span [ class "flex-1 truncate text-primary gutter-right-s" ]
            [ text tab.title ]
        , a
            [ class <| buttonStyle ++ " show-in-hover-inner"
            , href tab.url
            ]
            [ img
                [ class "height-xs width-xs hover-opacity"
                , src "/assets/icons/globe.svg"
                ]
                []
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- TASKS


focusElement : String -> Cmd Msg
focusElement elementId =
    Task.attempt TryFocusElement (Dom.focus elementId)



-- HELPERS


onClickStopPropagation : msg -> Attribute msg
onClickStopPropagation msg =
    Events.stopPropagationOn "click"
        (Decode.succeed ( msg, True ))


customOnClick : Msg -> Html.Attribute Msg
customOnClick msg =
    Events.custom
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
        Decode.map5 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)
            (Decode.field "numTabs" Decode.int)
            (Decode.field "settings" Theme.decoder) -- This will be decode settings in the future


workspacesInfoDecoder : Decoder (Dict Workspace.Id Workspace)
workspacesInfoDecoder =
    Decode.dict Workspace.decode
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
