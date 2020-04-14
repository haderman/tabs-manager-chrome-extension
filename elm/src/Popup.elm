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
    = WithoutFocus
    | WorkspaceNameInputFocused
    | RadioGroupColorsFocused
    | WorkspaceCardFocused
    | GitHubLinkeFocused
    | AddShortcutLinkFocused
    | SettingsLinkFocused
    | DisconnectWorkspaceButtonFocused


type FormCardStatus
    = Collapsed
    | Expanded


type alias FormData =
    { name : String
    , color : C.Color
    , status : FormStatus
    }


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
    | OpeningWorkspace W.WorkspaceId


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
    , focusStatus = WithoutFocus
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
            ( { model | focusStatus = WithoutFocus }, Cmd.none )

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
                        TypingValue value
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
        TypingValue value ->
            ( { model | formStatus = SelectingColor value C.default }, Cmd.none )

        SelectingColor name color ->
            let
                payload =
                    ( name, C.fromColorToString color )
            in
            ( { model | focusStatus = WithoutFocus }, Ports.createWorkspace payload )

        _ ->
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
    case model.status of
        OpeningWorkspace workspaceId ->
            let
                idInUse id_ =
                    not (id_ == workspaceId)

                workspacesIds =
                    List.filter idInUse model.data.workspacesIds

                workspaceName =
                    case Dict.get workspaceId model.data.workspacesInfo of
                        Just { name, color } ->
                            span [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
                                [ Html.text name ]

                        Nothing ->
                            Html.text ""
            in
            div [ id "root" ]
                [ viewHeader
                , div [ class "flex flexDirection-col alignItems-center height-m justifyContent-space-between padding-m background-black" ]
                    [ div [ class "color-contrast fontSize-xl marginBottom-m" ]
                        [ workspaceName ]
                    , div [ class "color-contrast marginBottom-m" ]
                        [ text "Openning tabs..."
                        , button
                            [ class "padding-xs marginLeft-l rounded background-white hover-opacity color-black fontWeight-400"
                            , onClick DisconnectWorkspace
                            , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                            , onBlur ElementBlurred
                            ]
                            [ text "Disconnect" ]
                        ]
                    ]
                , viewListWorkspaces workspacesIds model.data.workspacesInfo
                , viewFooter model
                ]

        WorkspaceInUse workspaceId ->
            let
                idInUse id_ =
                    not (id_ == workspaceId)

                workspacesIds =
                    List.filter idInUse model.data.workspacesIds

                viewWorkspace =
                    case Dict.get workspaceId model.data.workspacesInfo of
                        Just { name, color } ->
                            div [ class <| "flex flex-1 column justify-space-between squish-inset-m " ++ C.toBackgroundCSS color ]
                                [ div [ class "text-primary text-l gutter-bottom-xs" ]
                                    [ span []
                                        [ text name ]
                                    ]
                                , div []
                                    [ span [ class "text-primary gutter-right-m" ]
                                        [ text <| String.fromInt model.data.numTabsInUse ++ " Tabs" ]
                                    , button
                                        [ class "squish-inset-s rounded background-white color-black fontWeight-400"
                                        , onClick DisconnectWorkspace
                                        , onFocus <| ElementFocused DisconnectWorkspaceButtonFocused
                                        , onBlur ElementBlurred
                                        ]
                                        [ text "Disconnect" ]
                                    ]
                                ]

                        Nothing ->
                            Html.text ""
            in
            div [ id "root" ]
                [ viewHeader
                , div [ class "flex" ]
                    [ viewWorkspace
                    ]
                , viewListWorkspaces workspacesIds model.data.workspacesInfo
                , viewFooter model
                ]

        NoInitiated ->
            div [ class "flex justifyContent-center alignItems-center" ]
                [ h2 [ class "color-contrast" ]
                    [ text "Loading..." ]
                ]

        Idle ->
            let
                backdrop =
                    div [ class "absolute top-0 left-0 full-width full-height background-black opacity-0" ]
                        []
            in
            div [ id "root" ]
                [ div [ class "relative" ]
                    [ viewHeader
                    , backdrop
                    ]
                , viewForm model.formStatus model.data
                , div [ class "relative" ]
                    [ viewListWorkspaces model.data.workspacesIds model.data.workspacesInfo
                    , backdrop
                    ]
                , viewFooter model
                ]

        NoData ->
            let
                wavingHand =
                    "\u{1F44B}"

                greet =
                    div [ class "color-contrast fontSize-m textAlign-center padding-l" ]
                        [ p []
                            [ text <| wavingHand ++ " You are using "
                            , span [ class "color-alternate" ]
                                [ text <| String.fromInt model.data.numTabsInUse ++ " Tabs" ]
                            ]
                        , p []
                            [ text "To save it just type a "
                            , span [ class "color-alternate" ]
                                [ text "Name " ]
                            , text "and press "
                            , span [ class "color-alternate" ]
                                [ text "Enter" ]
                            ]
                        ]
            in
            div [ id "root" ]
                [ div [ class "padding-m flex alignItems-center justifyContent-center" ]
                    [ viewLogo ]
                , div [ class "relative flex flexDirection-col justifyContent-center alignItems-stretch alignText-center" ]
                    [ greet
                    , viewForm model.formStatus model.data
                    , viewFooter model
                    ]
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
                , class "text-interactive gutter-right-m"
                , onClick <| OpenChromePage "chrome://extensions/shortcuts"
                , tabindex 2
                , onFocus <| ElementFocused AddShortcutLinkFocused
                , onBlur ElementBlurred
                ]
                [ text "Add shortcut" ]

        settingsLink =
            a
                [ target "_blank"
                , href "/newtab/newtab.html"
                , tabindex 3
                , onFocus <| ElementFocused SettingsLinkFocused
                , onBlur ElementBlurred
                , class "hover-opacity circle inline-flex justify-center align-center"
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


viewListWorkspaces : List W.WorkspaceId -> Dict W.WorkspaceId W.Workspace -> Html Msg
viewListWorkspaces workspacesIds workspacesInfo =
    let
        emptyMessage =
            div [ class <| "flex padding-xl justifyContent-center alignItems-center paddingTop-xl paddingBottom-xl" ]
                [ h3 [ class "color-contrast textAlign-center" ]
                    [ text "You don't have more workspaces created" ]
                ]

        getWorkspace id =
            Dict.get id workspacesInfo

        tabsCountLabel numTabs =
            if numTabs == 1 then
                "1 Tab"
            else
                String.fromInt numTabs ++ " Tabs"

        viewWorkspace { id, name, color, tabs } =
            li [ class "gutter-bottom-s text-m" ]
                [ button
                    [ class "text-left"
                    , tabindex 3
                    , onClick <| OpenWorkspace id
                    , onFocus <| ElementFocused WorkspaceCardFocused
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
            emptyMessage

        _ ->
            ul [ class "squish-inset-m" ]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.filterMap identity
                    |> List.map viewWorkspace
                )



-- FORM


viewForm : FormStatus -> Data -> Html Msg
viewForm formStatus data =
    let
        tabsCount =
            p [ class "text-secondary" ]
                [ text <| String.fromInt data.numTabsInUse ++ " Tabs" ]

        inputName currentValue =
            input
                [ class "text-primary text-l rounded"
                , type_ "text"
                , placeholder "Type a Name"
                , autocomplete False
                , id <| fromFocusStatusToElementId WorkspaceNameInputFocused
                , tabindex 0
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
    in
    case formStatus of
        Empty ->
            div [ class "squish-inset-m" ]
                [ div [ class "flex justify-space-between gutter-bottom-xs" ]
                    [ inputName ""
                    , button
                        [ class "background-interactive squish-inset-s rounded text-m"
                        , disabled True
                        ]
                        [ text "Next" ]
                    ]
                , tabsCount
                ]

        TypingValue value ->
            div [ class "squish-inset-m" ]
                [ div [ class "flex justify-space-between gutter-bottom-xs" ]
                    [ inputName value
                    , button
                        [ class "background-interactive squish-inset-s rounded text-m"
                        , disabled False
                        ]
                        [ text "Next" ]
                    ]
                , tabsCount
                ]

        SelectingColor value color ->
            div [ class <| "flex flex-1 column justify-space-between squish-inset-m " ++ C.toBackgroundCSS color ]
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
            Html.form [ class "squish-inset-m" ]
                [ div [ class "flex justify-space-between gutter-bottom-xs" ]
                    [ inputName "value"
                    , button
                        [ class "background-interactive squish-inset-m rounded text-m"
                        , disabled False
                        ]
                        [ text "Save" ]
                    ]
                , tabsCount
                ]


viewRadioGroupColors : C.Color -> List C.Color -> Html Msg
viewRadioGroupColors color colorList =
    let
        radio color_ =
            let
                isChecked =
                    color_ == color

                stringColor =
                    C.fromColorToString color_

                handleOnInput value =
                    UpdateForm <| ChangeColor <| C.fromStringToColor value
            in
            label [ Html.Attributes.class "radioLabel" ]
                [ input
                    [ Html.Attributes.type_ "radio"
                    , Html.Attributes.name stringColor
                    , Html.Attributes.class "absolute width-0 height-0"
                    , checked isChecked
                    , Html.Attributes.value stringColor
                    , onInput handleOnInput
                    ]
                    []
                , span [ Html.Attributes.class <| "checkmark background-" ++ stringColor ] []
                ]
    in
    div
        [ class "flex opacity-70 padding-m height-xs"
        , id <| fromFocusStatusToElementId RadioGroupColorsFocused
        , tabindex 0
        , onBlur ElementBlurred
        , onFocus <| ElementFocused RadioGroupColorsFocused
        ]
        <| List.map radio colorList


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
    let
        rootStyle =
            String.join " "
                [ "flex"
                , "justfy-space-between"
                , "align-center"
                , "inset-m"
                , "backdrop-filter-blur"
                , "sticky-bottom"
                , "background-deep-1"
                , "text-primary"
                ]

        helpContainerStyle =
            String.join " "
                [ "full-width"
                , "inline-flex"
                , "justifyContent-flexStart"
                , "alignItems-center"
                , "full-height"
                , "rounded"
                , "letterSpacing-05"
                ]

        gitHubLink =
            a
                [ target "_blank"
                , href "https://github.com/haderman/tabs-manager-chrome-extension"
                , tabindex 1
                , onFocus <| ElementFocused GitHubLinkeFocused
                , onBlur ElementBlurred
                , class "hover-opacity circle inline-flex justifyContent-center alignItems-center background-deep-2"
                ]
                [ img
                    [ class "height-xs width-xs"
                    , src "/assets/icons/github-light-32px.png"
                    ]
                    []
                ]

        keyIconContainer =
            span [ class "background-deep-3 squish-inset-xs rounded gutter-right-xs" ]

        textHelpContainer =
            span [ class "marginRight-s" ]

        arrowLeft =
            keyIconContainer
                [ text "\u{2190}" ]

        arrowRight =
            keyIconContainer
                [ text "\u{2192}" ]

        arrowDown =
            keyIconContainer
                [ text "\u{2193}" ]

        arrowUp =
            keyIconContainer
                [ text "\u{2191}" ]

        enter =
            keyIconContainer
                [ text "Enter" ]

        space =
            keyIconContainer
                [ text "Space" ]

        tab =
            keyIconContainer
                [ text "Tab" ]

        robot =
            span [ class "texr-s" ]
                [ text "\u{1F47E}" ]

        navigationHelp =
            case model.focusStatus of
                WithoutFocus ->
                    textHelpContainer
                        [ tab
                        , text "Move"
                        ]

                WorkspaceNameInputFocused ->
                    textHelpContainer
                        [ arrowDown
                        , text "Change Field"
                        ]

                RadioGroupColorsFocused ->
                    textHelpContainer
                        [ textHelpContainer
                            [ arrowUp
                            , text "Change Field"
                            ]
                        , textHelpContainer
                            [ arrowLeft
                            , arrowRight
                            , text "Change Color"
                            ]
                        ]

                WorkspaceCardFocused ->
                    textHelpContainer
                        [ space
                        , text " or "
                        , enter
                        , text "Open"
                        ]

                GitHubLinkeFocused ->
                    textHelpContainer
                        [ enter
                        , text "Open Github Project"
                        ]

                AddShortcutLinkFocused ->
                    textHelpContainer
                        [ enter
                        , text "Add Shortcut Keyboard"
                        ]

                SettingsLinkFocused ->
                    textHelpContainer
                        [ enter
                        , text "Advanced View"
                        ]

                DisconnectWorkspaceButtonFocused ->
                    textHelpContainer
                        [ enter
                        , text "Disconnect Workspace"
                        ]


    in
    div [ class rootStyle ]
        [ div [ class helpContainerStyle ]
            [ navigationHelp ]
        , gitHubLink
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
        WithoutFocus ->
            ""

        WorkspaceNameInputFocused ->
            "input-workspace-name"

        RadioGroupColorsFocused ->
            "radio-group-colors"

        WorkspaceCardFocused ->
            ""

        GitHubLinkeFocused ->
            ""

        AddShortcutLinkFocused ->
            ""

        SettingsLinkFocused ->
            ""

        DisconnectWorkspaceButtonFocused ->
            ""

