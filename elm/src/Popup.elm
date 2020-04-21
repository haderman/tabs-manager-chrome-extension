module Popup exposing (..)

import Browser
import Browser.Dom as Dom
import Browser.Events exposing (onKeyDown)
import Color as C
import Dict exposing (Dict)
import FontAwesome exposing (icon, gitHub)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
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
    | SelectingColor W.WorkspaceName C.Color
    | TryingToSaveEmptyText


type Error
    = TrySaveWorkspaceWithEmptyText


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
    , colorList : List C.Color
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
    , colorList = C.list
    , formStatus = Empty
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type FormMsg
    = ChangeName W.WorkspaceName
    | ChangeColor C.Color


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
            ( { model | formStatus = SelectingColor value C.default }, Cmd.none )

        SelectingColor name color ->
            let
                payload =
                    ( name, C.fromColorToString color )
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
    div [ id "root" ] <|
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
                , viewFooter model
                ]

            NoInitiated ->
                [ h2 [ class "color-contrast" ]
                    [ text "Loading..." ]
                ]

            Idle ->
                [ viewHeader
                , viewForm model.formStatus model.data
                , viewListWorkspaces model.data.workspacesIds model.data.workspacesInfo
                , viewFooter model
                ]

            NoData ->
                [ viewHeader
                , viewForm model.formStatus model.data
                , viewInstructions model.formStatus
                , viewFooter model
                ]


viewLogo : Html Msg
viewLogo =
    img
        [ class "height-s"
        , src "/assets/brand/woki_text_blue_purple.svg"
        , alt "Woki logo"
        ]
        []


viewHeader : Html Msg
viewHeader =
    let
        addShorcutLink =
            a
                [ href "#"
                , class "text-interactive gutter-right-m focus-border"
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
                    [ class "height-xs width-xs"
                    , src "/assets/icons/cog.svg"
                    ]
                    []
                ]
    in
    header [ class "inset-m flex align-center justify-space-between" ]
        [ viewLogo
        , span [ class "flex align-center" ]
            [ addShorcutLink
            , settingsLink
            ]
        ]


viewWorkspaceInUse : W.WorkspaceId -> Data -> Html Msg
viewWorkspaceInUse workspaceId data =
    let
        viewNumTabs =
            p [ class "text-primary gutter-right-m" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]

        viewName name =
            p [ class "text-primary text-l gutter-bottom-xs" ]
                [ text name ]

        viewButton =
            button
                [ onClick DisconnectWorkspace
                , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                , onBlur ElementBlurred
                , class "circle focus-border"
                , tabindex 1
                ]
                [ img
                    [ class "height-xs width-xs"
                    , src "/assets/icons/eject.svg"
                    ]
                    []
                ]
    in
    case Dict.get workspaceId data.workspacesInfo of
        Just { name, color } ->
            div [ class <| "flex flex-1 justify-space-between squish-inset-m " ++ C.toBackgroundCSS color ]
                [ div [ class <| "flex flex-1 column justify-space-between" ]
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
                [ span [ class <| "circle-m gutter-right-s " ++ C.toBackgroundCSS color ]
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
    div [ class <| "flex flex-1 padding-xl justifyContent-center alignItems-center paddingTop-xl paddingBottom-xl" ]
        [ h3 [ class "color-contrast textAlign-center" ]
            [ text "You don't have more workspaces created" ]
        ]



-- FORM


viewForm : FormStatus -> Data -> Html Msg
viewForm formStatus data =
    let
        tabsCount =
            p [ class "text-secondary" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]

        input_ currentValue =
            input
                [ class "text-primary text-l rounded gutter-bottom-xs full-width"
                , type_ "text"
                , placeholder "Type a Name"
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
                [ span []
                    [ text "" ]
                ]
    in
    case formStatus of
        Empty ->
            div [ class "squish-inset-m" ]
                [ input_ ""
                , tabsCount
                ]

        TypingValue value ->
            div [ class "squish-inset-m" ]
                [ input_ value
                , tabsCount
                ]

        SelectingColor value color ->
            div [ class <| "flex column justify-space-between squish-inset-m " ++ C.toBackgroundCSS color ]
                [ div [ class "text-primary text-l gutter-bottom-xs" ]
                    [ span []
                        [ text value ]
                    ]
                , div []
                    [ span [ class "text-primary gutter-right-m" ]
                        [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]
                    ]
                ]

        TryingToSaveEmptyText ->
            div [ class "squish-inset-m" ]
                [ input_ ""
                , div [ class "flex justify-space-between" ]
                    [ tabsCount
                    , span [ class "text-highlight" ]
                        [ text "Type a label e.g 'news' or 'social'" ]
                    ]
                ]


viewInstructions : FormStatus -> Html Msg
viewInstructions formStatus =
    let
        bubbleTop =
            p [ class "speech-bubble-top background-deep-3 border-deep-3 inset-s letter-spacing anim-fade-in" ]

        bubbleBottom =
            p [ class "speech-bubble-bottom background-deep-3 border-deep-3 inset-s letter-spacing anim-fade-in" ]

        nameSamples =
            [ span [ class "squish-inset-xs gutter-right-xs rounded background-a" ]
                [ text "news" ]
            , span [ class "squish-inset-xs gutter-right-xs rounded background-b" ]
                [ text "social" ]
            , span [ class "squish-inset-xs gutter-right-xs rounded background-c" ]
                [ text "project-a" ]
            , span [ class "squish-inset-xs gutter-right-xs rounded background-d" ]
                [ text "task-b" ]
            ]

        inputNameHelp =
            bubbleTop <|
                p [ class "gutter-bottom-s" ]
                    [ text "How would you like to save the opened tabs? Samples: " ]
                    :: nameSamples

        footerHelp value =
            if not <| String.isEmpty value then
                bubbleBottom
                    [ text "Here you can see how you can interact with the keyboard" ]
            else
                text ""
    in
    div [ class "squish-inset-m text-primary flex-1 flex column justify-space-between" ] <|
        case formStatus of
            Empty ->
                [ inputNameHelp ]

            TypingValue value ->
                [ inputNameHelp
                , footerHelp value
                ]

            SelectingColor _ _ ->
                [ bubbleTop
                    [ text "You are almost done! Just use the arrows to change the color and press the Enter key to save!" ]
                ]

            TryingToSaveEmptyText ->
                [ inputNameHelp ]


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


viewFooter : Model -> Html Msg
viewFooter model =
    footer [ class "flex justfy-space-between align-center inset-m sticky-bottom background-deep-1 text-primary" ]
        [ viewHelp model.status model.formStatus model.focusStatus
        , viewAction
        ]


viewAction : Html Msg
viewAction =
    a
        [ target "_blank"
        , href "https://github.com/haderman/tabs-manager-chrome-extension"
        , tabindex 1
        , onFocus <| ElementFocused GitHubLinkeFocused
        , onBlur ElementBlurred
        , class "hover-opacity circle inline-flex justifyContent-center alignItems-center background-deep-2 focus-border"
        ]
        [ img
            [ class "height-xs width-xs"
            , src "/assets/icons/github-light-32px.png"
            ]
            []
        ]


viewHelp : Status -> FormStatus -> FocusStatus -> Html Msg
viewHelp status formStatus focusStatus =
    let
        formHelp =
            viewFormHelp formStatus

        focusHelp =
            viewFocusHelp focusStatus
                |> Maybe.withDefault []
    in
    div [ class "flex-1" ] <|
        case formHelp of
            Just help ->
                help

            Nothing ->
                navigationHelp status :: focusHelp


navigationHelp : Status -> Html Msg
navigationHelp status =
    let
        tab =
            keyBox [ text "Tab" ]
    in
    if status == NoData then
        text ""
    else
        helpInfo [ tab ] "Navigate"


viewFormHelp : FormStatus -> Maybe ( List ( Html Msg ) )
viewFormHelp formStatus =
    let
        enter =
            keyBox [ text "Enter" ]

        backSpace =
            keyBox [ text "\u{232B}" ]

        arrowLeft =
            keyBox [ text "\u{2190}" ]

        arrowRight =
            keyBox [ text "\u{2192}" ]
    in
    case formStatus of
        TypingValue _ ->
            Just
                [ helpInfo [ enter ] "Next" ]

        SelectingColor _ _ ->
            Just
                [ helpInfo [ enter ] "Save"
                , helpInfo [ arrowLeft, arrowRight ] "Color"
                , helpInfo [ backSpace ] "Undo"
                ]

        _ ->
            Nothing


viewFocusHelp : FocusStatus -> Maybe ( List ( Html Msg ) )
viewFocusHelp focusStatus =
    let
        enter =
            keyBox [ text "Enter" ]
    in
    case focusStatus of
        WorkspaceItemFocused ->
            Just [ helpInfo [ enter ] "Open tabs" ]

        GitHubLinkeFocused ->
            Just [ helpInfo [ enter ] "Source code" ]

        AddShortcutLinkFocused ->
            Just [ helpInfo [ enter ] "Shortcuts page" ]

        SettingsLinkFocused ->
            Just [ helpInfo [ enter ] "Advanced view page" ]

        DisconnectWorkspaceButtonFocused ->
            Just [ helpInfo [ enter ] "Unmount workspace" ]

        _ ->
            Nothing


helpInfo : List ( Html Msg ) -> String -> Html Msg
helpInfo keys txt =
    span [ class "gutter-right-m" ] <|
        List.concat [ keys, [ text txt] ]


keyBox : List ( Html Msg ) -> Html Msg
keyBox =
    kbd [ class "background-deep-2 border-s border-deep-3 squish-inset-xs rounded gutter-right-xs anim-pulsar-border" ]



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


statusFromString : String -> Decoder Status
statusFromString status =
    case status of
        "noData" ->
            Decode.succeed NoData

        _ ->
            Decode.succeed Idle


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

