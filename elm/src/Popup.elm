module Popup exposing (main)


import Browser
import Browser.Dom as Dom
import Browser.Events exposing (onKeyDown)
import MyColor
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onFocus, onBlur, onInput, onSubmit)
import Json.Decode as Decode exposing (..)
import Ports
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS)
        , onKeyDown keyDecoder
        ]



-- MODEL


type Key
    = Other
    | Enter
    | Up
    | Down
    | Left
    | Right
    | Backspace


type FocusStatus
    = NoneFocus
    | WorkspaceNameInputFocused
    | RadioGroupColorsFocused
    | WorkspaceItemFocused
    | GitHubLinkeFocused
    | AddShortcutLinkFocused
    | SettingsLinkFocused
    | DisconnectWorkspaceButtonFocused


type FormStatus
    = Empty
    | TypingValue W.WorkspaceName
    | SelectingColor W.WorkspaceName MyColor.Color
    | TryingToSaveEmptyText


type Status
    = NoInitiated
    | Idle
    | NoData
    | WorkspaceInUse W.WorkspaceId


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , status : Status
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
    , numTabsInUse : Int
    }


type alias Flags =
    { window : Int }


type alias Model =
    { data : Data
    , status : Status
    , focusStatus : FocusStatus
    , colorList : List MyColor.Color
    , formStatus : FormStatus
    }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , workspacesInfo = Dict.empty
        , status = NoInitiated
        , numTabsInUse = 0
        }
    , status = NoInitiated
    , focusStatus = NoneFocus
    , colorList = MyColor.list
    , formStatus = Empty
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type FormMsg
    = ChangeName W.WorkspaceName
    | ChangeColor MyColor.Color


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace W.WorkspaceId
    | UpdateForm FormMsg
    | KeyPressed Key
    | TryFocusElement (Result Dom.Error ())
    | ElementFocused FocusStatus
    | ElementBlurred
    | OpenChromePage String
    | DisconnectWorkspace


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

        ReceivedDataFromJS (Err _) ->
            ( model, Cmd.none )

        OpenWorkspace id ->
            ( model, Ports.openWorkspace id )

        UpdateForm formMsg ->
            updateForm formMsg model

        KeyPressed key ->
            handleKeyPressed key model

        ElementFocused focusStatus ->
            ( { model | focusStatus = focusStatus }, Cmd.none )

        ElementBlurred ->
            ( { model | focusStatus = NoneFocus }, Cmd.none )

        OpenChromePage url ->
            ( model, Ports.openChromePage url )

        TryFocusElement _ ->
            ( model, Cmd.none )

        DisconnectWorkspace ->
            ( { model | formStatus = Empty }, Ports.disconnectWorkspace () )


updateForm : FormMsg -> Model -> ( Model, Cmd Msg )
updateForm formMsg model =
    case formMsg of
        ChangeName value ->
            ( { model
                | formStatus =
                    if String.isEmpty value then
                        Empty
                    else
                        TypingValue <| String.replace " " "-" value
              }
              , Cmd.none
            )

        ChangeColor color ->
            case model.formStatus of
                SelectingColor name _ ->
                    ( { model | formStatus = SelectingColor name color }, Cmd.none )

                _ ->
                    ( model, Cmd.none )



-- HANDLE KEYBOARD NAVIGATION


handleKeyPressed : Key -> Model -> ( Model, Cmd Msg )
handleKeyPressed key model =
    case key of
        Other ->
            ( model, Cmd.none )

        Enter ->
            enterPressed model

        Down ->
            downPressed model

        Up ->
            upPressed model

        Left ->
            leftPressed model

        Right ->
            rightPressed model

        Backspace ->
            backspacePressed model


backspacePressed : Model -> ( Model, Cmd Msg )
backspacePressed model =
    case model.formStatus of
        SelectingColor value _ ->
            ( { model | formStatus = TypingValue value }, focusElement WorkspaceNameInputFocused )

        _ ->
            ( model, Cmd.none )


enterPressed : Model -> ( Model, Cmd Msg )
enterPressed model =
    case model.formStatus of
        Empty ->
            ( { model | formStatus = TryingToSaveEmptyText }, Cmd.none )

        TypingValue value ->
            ( { model | formStatus = SelectingColor value MyColor.default }, Cmd.none )

        SelectingColor name color ->
            let
                payload =
                    ( name, MyColor.fromColorToString color )
            in
            ( { model | focusStatus = NoneFocus }, Ports.createWorkspace payload )

        TryingToSaveEmptyText ->
            ( model, Cmd.none )


downPressed : Model -> ( Model, Cmd Msg )
downPressed model =
    case model.focusStatus of
        WorkspaceNameInputFocused ->
            ( model, focusElement RadioGroupColorsFocused )

        _ ->
            ( model, Cmd.none )


upPressed : Model -> ( Model, Cmd Msg )
upPressed model =
    case model.focusStatus of
        RadioGroupColorsFocused ->
            ( model, focusElement WorkspaceNameInputFocused )

        _ ->
            ( model, Cmd.none )


leftPressed : Model -> ( Model, Cmd Msg )
leftPressed model =
    case model.formStatus of
        SelectingColor workspaceName currentColor ->
            let
                toIndex index_ color_ =
                    if color_ == currentColor then
                        index_
                    else
                        0

                getIndex =
                    model.colorList
                        |> List.indexedMap toIndex
                        |> List.sum

                color =
                    model.colorList
                        |> List.take getIndex
                        |> List.reverse
                        |> List.head
                        |> Maybe.withDefault currentColor

            in
            ( { model | formStatus = SelectingColor workspaceName color }, Cmd.none )

        _ ->
            ( model, Cmd.none )


rightPressed : Model -> ( Model, Cmd Msg )
rightPressed model =
    case model.formStatus of
        SelectingColor workspaceName  currentColor ->
            let
                toIndex index_ color_ =
                    if color_ == currentColor then
                        index_
                    else
                        0

                getIndex =
                    model.colorList
                        |> List.indexedMap toIndex
                        |> List.sum

                color =
                    model.colorList
                        |> List.drop (getIndex + 1)
                        |> List.head
                        |> Maybe.withDefault currentColor
            in
            ( { model | formStatus = SelectingColor workspaceName color }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- TASKS


focusElement : FocusStatus -> Cmd Msg
focusElement newFocusStatus =
    let
        elementId =
            fromFocusStatusToElementId newFocusStatus
    in
    Task.attempt TryFocusElement (Dom.focus elementId)



-- VIEW


view : Model -> Html Msg
view model =
    div [ id "root"
        , class "light"
        ] <|
        case model.status of
            WorkspaceInUse workspaceId ->
                let
                    idInUse id_ =
                        not (id_ == workspaceId)

                    workspacesIds =
                        List.filter idInUse model.data.workspacesIds
                in
                [ viewHeader
                , div [ class "flex sticky-top" ]
                    [ viewWorkspaceInUse workspaceId model.data
                    ]
                , viewListWorkspaces workspacesIds model.data.workspacesInfo
                ]

            NoInitiated ->
                [ h2 [ class "color-contrast" ]
                    [ text "Loading..." ]
                ]

            Idle ->
                [ viewHeader
                , viewForm model.formStatus model.data
                , viewListWorkspaces model.data.workspacesIds model.data.workspacesInfo
                ]

            NoData ->
                [ viewHeader
                , viewForm model.formStatus model.data
                , viewListWokspaceEmptyState
                , viewFooter
                ]


viewHeader : Html Msg
viewHeader =
    let
        addShorcutLink =
            a
                [ href "#"
                , class "text-interactive gutter-right-m focus-border rounded"
                , onClick <| OpenChromePage "chrome://extensions/shortcuts"
                , tabindex 1
                , onFocus <| ElementFocused AddShortcutLinkFocused
                , onBlur ElementBlurred
                ]
                [ text "Add shortcut" ]

        settingsLink =
            a
                [ target "_blank"
                , href "/newtab/newtab.html"
                , tabindex 1
                , onFocus <| ElementFocused SettingsLinkFocused
                , onBlur ElementBlurred
                , class "circle inline-flex justify-center align-center focus-border"
                ]
                [ img
                    [ class "height-s width-s dynamic"
                    , src "/assets/icons/cog.svg"
                    ]
                    []
                ]
    in
    header [ class "inset-m flex align-center justify-end" ]
        [ settingsLink ]


viewWorkspaceInUse : W.WorkspaceId -> Data -> Html Msg
viewWorkspaceInUse workspaceId data =
    let
        viewNumTabs =
            p [ class "text-secondary-high-contrast gutter-right-m" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]

        viewName name =
            p [ class "text-primary-high-contrast text-l" ]
                [ text name ]

        viewButton =
            button
                [ onClick DisconnectWorkspace
                , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                , onBlur ElementBlurred
                , class "circle focus-border height-s width-s contrast"
                , tabindex 1
                ]
                [ img
                    [ class "height-s width-s"
                    , src "/assets/icons/close.svg"
                    ]
                    []
                ]
    in
    case Dict.get workspaceId data.workspacesInfo of
        Just { name, color } ->
            div [ class <| "flex flex-1 justify-space-between squish-inset-m " ++ MyColor.toBackgroundCSS color ]
                [ span [ class "circle-m gutter-right-s transparent" ]
                    []
                , div [ class "flex flex-1 column justify-space-between squish-inset-s" ]
                    [ viewName name
                    , viewNumTabs
                    ]
                , div [ class "flex align-center justify-center"]
                    [ viewButton ]
                ]

        Nothing ->
            Html.text ""



viewListWorkspaces : List W.WorkspaceId -> Dict W.WorkspaceId W.Workspace -> Html Msg
viewListWorkspaces workspacesIds workspacesInfo =
    let
        getWorkspace id =
            Dict.get id workspacesInfo

        tabsCountLabel numTabs =
            if numTabs == 1 then
                "1 Tab"
            else
                String.fromInt numTabs ++ " Tabs"

        viewWorkspace { id, name, color, tabs } =
            li [ class "text-m flex align-center" ]
                [ span [ class <| "circle-m gutter-right-s " ++ MyColor.toBackgroundCSS color ]
                    []
                , button
                    [ class "text-left squish-inset-s flex-1 rounded focus-background"
                    , tabindex 1
                    , onClick <| OpenWorkspace id
                    , onFocus <| ElementFocused WorkspaceItemFocused
                    , onBlur ElementBlurred
                    ]
                    [ p [ class "text-primary text-l" ]
                        [ Html.text name ]
                    , p [ class "text-secondary" ]
                        [ Html.text <| tabsCountLabel <| List.length tabs ]
                    ]
                ]
    in
    case workspacesIds of
        [] ->
            viewListWokspaceEmptyState

        _ ->
            ul [ class "squish-inset-m flex-1" ]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.filterMap identity
                    |> List.map viewWorkspace
                )


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
    div [ class <| "flex column flex-1 justify-center align-center" ]
        [ title
        , thumbnail
        ]



-- FORM


viewForm : FormStatus -> Data -> Html Msg
viewForm formStatus data =
    let
        tabsCount =
            p [ class "text-secondary gutter-right-s" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]

        input_ currentValue =
            input
                [ class "text-primary text-l rounded full-width gutter-right-m"
                , type_ "text"
                , autocomplete False
                , id <| fromFocusStatusToElementId WorkspaceNameInputFocused
                , tabindex 1
                , selected True
                , autofocus True
                , Html.Attributes.value currentValue
                , onBlur ElementBlurred
                , onFocus <| ElementFocused WorkspaceNameInputFocused
                , onInput
                    (\newValue ->
                        UpdateForm <| ChangeName newValue
                    )
                ]
                []

        nextStepButton animate =
            button
                [ onClick <| KeyPressed Enter
                , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                , onBlur ElementBlurred
                , class <|
                    if animate == True then
                        "circle focus-border height-s width-s vibrate delay"
                    else
                        "circle focus-border height-s width-s"
                , tabindex 1
                , type_ "button"
                ]
                [ img
                    [ class "height-s width-s dynamic"
                    , src "/assets/icons/arrow-right.svg"
                    ]
                    []
                ]

        helpContainerStyle =
            String.join " "
                [ "flex"
                , "justify-space-between"
                , "full-width"
                , "squish-inset-m"
                , "z-index-1"
                , "background-deep-2"
                , "slide-from-top"
                ]

        selectingColorHelp =
            [ span [ class "inline-flex align-center text-primary" ]
                [ button
                    [ type_ "button"
                    , onClick <| KeyPressed Backspace
                    ]
                    [ backspaceKey ]
                , text "Cancel"
                ]
            , span [ class "inline-flex align-center text-primary" ]
                [ button
                    [ type_ "button"
                    , onClick <| KeyPressed Left
                    ]
                    [ arrowLeftKey ]
                , button
                    [ type_ "button"
                    , onClick <| KeyPressed Right
                    ]
                    [ arrowRightKey ]
                , text "Color"
                ]
            , span [ class "inline-flex align-center text-primary" ]
                [ button
                    [ type_ "button"
                    , onClick <| KeyPressed Enter
                    ]
                    [ enterKey ]
                , text "Save"
                ]
            ]
    in
    Html.form
        [ class "relative text-primary background-inherit"
        , onSubmit NoOp
        ] <|
        case formStatus of
            Empty ->
                [ div [ class "relative squish-inset-m z-index-2 background-inherit" ]
                    [ div [ class "flex justify-space-between align-center" ]
                        [ input_ ""
                        , nextStepButton False
                        ]
                    , tabsCount
                    ]
                ]

            TypingValue value ->
                [ div [ class "relative squish-inset-m background-transition delay z-index-2 background-inherit" ]
                    [ div [ class "flex justify-space-between align-center" ]
                        [ input_ value
                        , nextStepButton <| String.length value > 2
                        ]
                    , tabsCount
                    ]
                , div [ class helpContainerStyle ]
                    selectingColorHelp
                ]

            SelectingColor workspaceName color ->
                [ div [ class <| "relative flex column squish-inset-m z-index-2 background-transition " ++ MyColor.toBackgroundCSS color ]
                    [ div [ class "text-primary-high-contrast text-l" ]
                        [ span []
                            [ text workspaceName ]
                        ]
                    , div []
                        [ span [ class "text-secondary-high-contrast gutter-right-m" ]
                            [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]
                        ]
                    ]
                , div [ class <| helpContainerStyle ++ " show delay" ]
                    selectingColorHelp
                ]

            TryingToSaveEmptyText ->
                [ div [ class "relative squish-inset-m z-index-2 background-inherit" ]
                    [ div [ class "flex justify-space-between align-center" ]
                        [ input_ ""
                        , nextStepButton False
                        ]
                    , div [ class "flex flex-start" ]
                        [ tabsCount
                        , span [ class "text-error font-400" ]
                            [ text "Type a label e.g 'news' or 'social'" ]
                        ]
                    ]
                ]


customOnClick : Msg -> Html.Attribute Msg
customOnClick msg =
    Html.Events.custom
        "onInput"
        (Decode.succeed
            { stopPropagation = True
            , preventDefault = True
            , message = msg
            }
        )



-- VIEW FOOTER


viewFooter : Html Msg
viewFooter =
    footer [ class "flex justify-end align-center inset-m background-deep-0 text-primary" ]
        [ a
            [ target "_blank"
            , href "https://github.com/haderman/tabs-manager-chrome-extension"
            , tabindex 1
            , onFocus <| ElementFocused GitHubLinkeFocused
            , onBlur ElementBlurred
            , class "hover-opacity circle inline-flex justifyContent-center alignItems-center focus-border"
            ]
            [ img
                [ class "height-s width-s dynamic"
                , src "/assets/icons/github.svg"
                ]
                []
            ]
        ]



-- KEYBOARD ICONS


keyBox : List ( Html Msg ) -> Html Msg
keyBox =
    kbd [ class "background-deep-3 border-s border-deep-3 squish-inset-xs rounded gutter-right-xs inline-flex align-center" ]


enterKey : Html Msg
enterKey =
    keyBox [
        img [ class "height-xs width-xs dynamic"
            , src "/assets/icons/enter.svg"
            , alt "enter key"
            ]
            []
    ]


arrowLeftKey : Html Msg
arrowLeftKey =
    keyBox [
        img [ class "height-xs width-xs dynamic"
            , src "/assets/icons/arrow-left.svg"
            , alt "arrow left key"
            ]
            []
    ]


arrowRightKey : Html Msg
arrowRightKey =
    keyBox [
        img [ class "height-xs width-xs dynamic"
            , src "/assets/icons/arrow-right.svg"
            , alt "arrow right key"
            ]
            []
    ]


backspaceKey : Html Msg
backspaceKey =
    keyBox [
        img [ class "height-xs width-xs dynamic"
            , src "/assets/icons/backspace.svg"
            , alt "arrow left key"
            ]
            []
    ]



-- DECODERS


dataDecoder : Decoder Data
dataDecoder =
    Decode.field "data" <|
        Decode.map4 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)
            (Decode.field "numTabs" decodeNumTabs)


decodeNumTabs : Decoder Int
decodeNumTabs =
    Decode.maybe Decode.int
        |> Decode.andThen
            (\maybeNumTabs ->
                case maybeNumTabs of
                    Just numTabs ->
                        Decode.succeed numTabs

                    Nothing ->
                        Decode.succeed 0
            )


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

                    "noData" ->
                        Decode.succeed NoData

                    _ ->
                        Decode.succeed Idle
            )


keyDecoder : Decoder Msg
keyDecoder =
    Decode.map (toKey >> KeyPressed) <|
        Decode.field "key" Decode.string


toKey : String -> Key
toKey str =
    case str of
        "Enter" ->
            Enter

        "ArrowUp" ->
            Up

        "ArrowDown" ->
            Down

        "ArrowLeft" ->
            Left

        "ArrowRight" ->
            Right

        "Backspace" ->
            Backspace

        _ ->
            Other



-- HELPERS


fromFocusStatusToElementId : FocusStatus -> String
fromFocusStatusToElementId focusStatus =
    case focusStatus of
        NoneFocus ->
            ""

        WorkspaceNameInputFocused ->
            "input-workspace-name"

        RadioGroupColorsFocused ->
            "radio-group-colors"

        WorkspaceItemFocused ->
            ""

        GitHubLinkeFocused ->
            ""

        AddShortcutLinkFocused ->
            ""

        SettingsLinkFocused ->
            ""

        DisconnectWorkspaceButtonFocused ->
            ""

