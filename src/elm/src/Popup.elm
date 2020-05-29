module Popup exposing (main)


import Browser
import Browser.Dom as Dom
import Browser.Events exposing (onKeyDown)
import MyColor
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events as Events exposing (onClick, onFocus, onBlur, onInput, onSubmit)
import Json.Decode as Decode exposing (..)
import Ports
import Size exposing (Size)
import Task
import Theme exposing (Theme)
import View.Icon
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS)
        , onKeyDown keyDecoder
        ]



-- MODEL


type alias Flags =
    Decode.Value


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
    | RadioGroupMyColorsFocused
    | WorkspaceItemFocused
    | GitHubLinkeFocused
    | AddShortcutLinkFocused
    | SettingsLinkFocused
    | DisconnectWorkspaceButtonFocused


type FormStatus
    = Empty
    | TypingValue Workspace.Name
    | SelectingMyColor Workspace.Name MyColor.MyColor
    | TryingToSaveEmptyText


type Status
    = NoInitiated
    | Idle
    | NoData
    | WorkspaceInUse Workspace.Id


type alias Data =
    { workspacesIds : List Workspace.Id
    , status : Status
    , workspacesInfo : Dict Workspace.Id Workspace
    , numTabsInUse : Int
    , theme : Theme
    }


type alias Model =
    { data : Data
    , status : Status
    , focusStatus : FocusStatus
    , colorList : List MyColor.MyColor
    , formStatus : FormStatus
    , error : String
    }


defaultData : Data
defaultData =
    { workspacesIds = []
    , status = NoInitiated
    , workspacesInfo = Dict.empty
    , numTabsInUse = 0
    , theme = Theme.default
    }


initModel : Data -> Model
initModel data =
    { data = data
    , status = data.status
    , focusStatus = NoneFocus
    , colorList = MyColor.list
    , formStatus = Empty
    , error = ""
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    case Decode.decodeValue dataDecoder flags of
        Ok data ->
            ( initModel data, Cmd.none )

        Err err ->
            ( initModel defaultData
                |>
                    (\model ->
                        { model |
                            error = Debug.toString err
                        }
                    )
            , Cmd.none )



-- UPDATE


type FormMsg
    = ChangeName Workspace.Name


type Msg
    = NoOp
    | ReceivedDataFromJS (Result Decode.Error Data)
    | OpenWorkspace Workspace.Id
    | UpdateForm FormMsg
    | KeyPressed Key
    | TryFocusElement (Result Dom.Error ())
    | ElementFocused FocusStatus
    | ElementBlurred
    | OpenChromePage String
    | DisconnectWorkspace
    | ChangeTheme Theme


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

        ChangeTheme theme ->
            ( model, Ports.changeTheme <| Theme.toString theme )


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
        SelectingMyColor value _ ->
            ( { model | formStatus = TypingValue value }, focusElement WorkspaceNameInputFocused )

        _ ->
            ( model, Cmd.none )


enterPressed : Model -> ( Model, Cmd Msg )
enterPressed model =
    case model.formStatus of
        Empty ->
            ( { model | formStatus = TryingToSaveEmptyText }, Cmd.none )

        TypingValue value ->
            ( { model | formStatus = SelectingMyColor value MyColor.default }, Cmd.none )

        SelectingMyColor name color ->
            let
                payload =
                    ( name, MyColor.toString color )
            in
            ( { model | focusStatus = NoneFocus }, Ports.createWorkspace payload )

        TryingToSaveEmptyText ->
            ( model, Cmd.none )


downPressed : Model -> ( Model, Cmd Msg )
downPressed model =
    case model.focusStatus of
        WorkspaceNameInputFocused ->
            ( model, focusElement RadioGroupMyColorsFocused )

        _ ->
            ( model, Cmd.none )


upPressed : Model -> ( Model, Cmd Msg )
upPressed model =
    case model.focusStatus of
        RadioGroupMyColorsFocused ->
            ( model, focusElement WorkspaceNameInputFocused )

        _ ->
            ( model, Cmd.none )


leftPressed : Model -> ( Model, Cmd Msg )
leftPressed model =
    case model.formStatus of
        SelectingMyColor workspaceName currentMyColor ->
            let
                toIndex index_ color_ =
                    if color_ == currentMyColor then
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
                        |> Maybe.withDefault currentMyColor

            in
            ( { model | formStatus = SelectingMyColor workspaceName color }, Cmd.none )

        _ ->
            ( model, Cmd.none )


rightPressed : Model -> ( Model, Cmd Msg )
rightPressed model =
    case model.formStatus of
        SelectingMyColor workspaceName  currentMyColor ->
            let
                toIndex index_ color_ =
                    if color_ == currentMyColor then
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
                        |> Maybe.withDefault currentMyColor
            in
            ( { model | formStatus = SelectingMyColor workspaceName color }, Cmd.none )

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
    div [ class <| "root " ++ Theme.toString model.data.theme  ] <|
        case model.status of
            WorkspaceInUse workspaceId ->
                let
                    idInUse id_ =
                        not (id_ == workspaceId)

                    workspacesIds =
                        List.filter idInUse model.data.workspacesIds
                in
                [ viewHeader model.data.theme
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
                [ viewHeader model.data.theme
                , viewForm model.formStatus model.data
                , viewListWorkspaces model.data.workspacesIds model.data.workspacesInfo
                ]

            NoData ->
                [ viewHeader model.data.theme
                , viewForm model.formStatus model.data
                , viewListWokspaceEmptyState
                , viewFooter
                ]


viewHeader : Theme -> Html Msg
viewHeader theme =
    let
        buttonTheme =
            let
                buttonAttrs onClick =
                    [ Events.onClick onClick
                    , tabindex 1
                    , onFocus <| ElementFocused SettingsLinkFocused
                    , onBlur ElementBlurred
                    , class "circle inline-flex justify-center align-center focus-border gutter-right-m"
                    ]
            in
            case theme of
                Theme.Dark ->
                    button
                        (buttonAttrs <| ChangeTheme Theme.Light)
                        [ View.Icon.moon Size.S ]
                Theme.Light ->
                    button
                        (buttonAttrs <| ChangeTheme Theme.Dark)
                        [ View.Icon.sun Size.S
                        ]

        addShorcutLink =
            a
                [ href "#"
                , class "text-interactive gutter-right-m focus-border rounded"
                , onClick <| OpenChromePage "chrome://extensions/shortcuts"
                , tabindex 1
                , onFocus <| ElementFocused AddShortcutLinkFocused
                , onBlur ElementBlurred
                ]
                [ text "Add shortcut"
                ]

        settingsLink =
            a
                [ target "_blank"
                , href "/src/newtab/newtab.html"
                , tabindex 1
                , onFocus <| ElementFocused SettingsLinkFocused
                , onBlur ElementBlurred
                , class "circle inline-flex justify-center align-center focus-border"
                ]
                [ View.Icon.settings Size.S
                ]
    in
    header [ class "inset-m flex align-center justify-end" ]
        [ buttonTheme
        , settingsLink
        ]


viewWorkspaceInUse : Workspace.Id -> Data -> Html Msg
viewWorkspaceInUse workspaceId data =
    let
        viewNumTabs =
            p [ class "text-secondary-high-contrast gutter-right-m" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs"
                ]

        viewName name =
            p [ class "text-primary-high-contrast text-l" ]
                [ text name
                ]

        viewButton =
            button
                [ onClick DisconnectWorkspace
                , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                , onBlur ElementBlurred
                , class "circle focus-border height-s width-s contrast"
                , tabindex 1
                ]
                [ View.Icon.close Size.S
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



viewListWorkspaces : List Workspace.Id -> Dict Workspace.Id Workspace -> Html Msg
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
                [ View.Icon.arrowRight Size.S
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

        selectingMyColorHelp =
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
                , text "MyColor"
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
                    selectingMyColorHelp
                ]

            SelectingMyColor workspaceName color ->
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
                    selectingMyColorHelp
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
    Events.custom
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
    footer [ class "flex justify-end align-center inset-m text-primary" ]
        [ a
            [ target "_blank"
            , href "https://github.com/haderman/tabs-manager-chrome-extension"
            , tabindex 1
            , onFocus <| ElementFocused GitHubLinkeFocused
            , onBlur ElementBlurred
            , class "hover-opacity circle inline-flex justifyContent-center alignItems-center focus-border"
            ]
            [ View.Icon.github Size.S
            ]
        ]



-- KEYBOARD ICONS


keyBox : List ( Html Msg ) -> Html Msg
keyBox =
    kbd [ class "background-deep-3 squish-inset-xs rounded gutter-right-xs inline-flex align-center" ]


enterKey : Html Msg
enterKey =
    keyBox [ View.Icon.enter Size.XS ]


arrowLeftKey : Html Msg
arrowLeftKey =
    keyBox [ View.Icon.arrowLeft Size.XS ]


arrowRightKey : Html Msg
arrowRightKey =
    keyBox [ View.Icon.arrowRight Size.XS ]


backspaceKey : Html Msg
backspaceKey =
    keyBox [ View.Icon.backspace Size.XS ]



-- DECODERS


dataDecoder : Decoder Data
dataDecoder =
    Decode.field "data" <|
        Decode.map5 Data
            (Decode.field "workspaces" (Decode.list Decode.int))
            (Decode.field "status" stateDecoder)
            (Decode.field "workspacesInfo" workspacesInfoDecoder)
            (Decode.field "numTabs" decodeNumTabs)
            (Decode.field "settings" Theme.decoder)


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

        RadioGroupMyColorsFocused ->
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

