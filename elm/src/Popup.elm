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
    | Filled
    | WithErrors


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
    , formData : FormData
    , formCardStatus : FormCardStatus
    , focusStatus : FocusStatus
    , colorList : List C.Color
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
    , formCardStatus = Collapsed
    , formData =
        { name = ""
        , color = C.default
        , status = Empty
        }
    , focusStatus = WithoutFocus
    , colorList = C.list
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel, Cmd.none )



-- UPDATE


type FormMsg
    = ChangeName String
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
                , formCardStatus =
                    if data.status == NoData then
                        Expanded
                    else
                        Collapsed
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
            ( model, Ports.disconnectWorkspace () )


updateForm : FormMsg -> Model -> ( Model, Cmd Msg )
updateForm formMsg model =
    case formMsg of
        ChangeName value ->
            let
                formStatus =
                    if String.isEmpty value then
                        Empty
                    else
                        Filled

                newFormData =
                    model.formData
                        |> setName value
                        |> setStatus formStatus

                newFormCardStatus =
                    case formStatus of
                        Empty ->
                            Collapsed

                        _ ->
                            Expanded
            in
            case model.status of
                NoData ->
                    ( { model | formData = newFormData }, Cmd.none )

                _ ->
                    ( { model
                        | formData = newFormData
                        , formCardStatus = newFormCardStatus
                      }
                    , Cmd.none
                    )

        ChangeColor color ->
            ( { model | formData = setColor color model.formData }, Cmd.none )



-- UPDATE FORM HELPERS


setName : String -> FormData -> FormData
setName name_ formData =
    { formData | name = name_ }


setColor : C.Color -> FormData -> FormData
setColor color_ formData =
    { formData | color = color_ }


setStatus : FormStatus -> FormData -> FormData
setStatus status_ formData =
    { formData | status = status_ }



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


enterPressed : Model -> ( Model, Cmd Msg )
enterPressed model =
    case model.status of
        NoData ->
            tryToSaveWorkspace model

        Idle ->
            tryToSaveWorkspace model

        _ ->
            ( model, Cmd.none )


downPressed : Model -> ( Model, Cmd Msg )
downPressed model =
    case model.focusStatus of
        WorkspaceNameInputFocused ->
            ( model, focusElement <| fromFocusStatusToElementId RadioGroupColorsFocused )

        _ ->
            ( model, Cmd.none )


upPressed : Model -> ( Model, Cmd Msg )
upPressed model =
    case model.focusStatus of
        RadioGroupColorsFocused ->
            ( model, focusElement <| fromFocusStatusToElementId WorkspaceNameInputFocused )

        _ ->
            ( model, Cmd.none )


leftPressed : Model -> ( Model, Cmd Msg )
leftPressed model =
    case model.focusStatus of
        RadioGroupColorsFocused ->
            let
                currentColor =
                    model.formData.color

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
            ( { model | formData = setColor color model.formData }, Cmd.none )

        _ ->
            ( model, Cmd.none )


rightPressed : Model -> ( Model, Cmd Msg )
rightPressed model =
    case model.focusStatus of
        RadioGroupColorsFocused ->
            let
                currentColor =
                    model.formData.color

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
            ( { model | formData = setColor color model.formData }, Cmd.none )

        _ ->
            ( model, Cmd.none )


tryToSaveWorkspace : Model -> ( Model, Cmd Msg )
tryToSaveWorkspace model =
    case model.formData.status of
        Empty ->
            ( { model | formData = setStatus WithErrors model.formData }, Cmd.none )

        Filled ->
            let
                payload =
                    ( model.formData.name, C.fromColorToString model.formData.color )
            in
            ( { model | focusStatus = WithoutFocus }, Ports.createWorkspace payload )

        _ ->
            ( model, Cmd.none )



-- TASKS


focusElement : String -> Cmd Msg
focusElement elementId =
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
                , viewCards workspacesIds model.data.workspacesInfo
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
                                [ div [ class "text-primary text-l" ]
                                    [ span []
                                        [ Html.text name ]
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
                divisor =
                    div [ class "full-width neo-divisor" ]
                        []
            in
            case model.formCardStatus of
                Collapsed ->
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
                        , viewFormCollapsed model
                        , divisor
                        , div [ class "relative" ]
                            [ viewCards model.data.workspacesIds model.data.workspacesInfo
                            , backdrop
                            ]
                        , viewFooter model
                        ]

                Expanded ->
                    let
                        backdrop =
                            div [ class "absolute top-0 left-0 full-width full-height backdrop-filter-blur background-black opacity-70" ]
                                []
                    in
                    div [ id "root" ]
                        [ div [ class "relative" ]
                            [ viewHeader
                            , backdrop
                            ]
                        , viewFormExpanded model.formData model.colorList
                        , divisor
                        , div [ class "relative" ]
                            [ viewCards model.data.workspacesIds model.data.workspacesInfo
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
                    , viewFormExpanded model.formData model.colorList
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
    header [ class "stretch-inset-m flex align-center justify-space-between" ]
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
            ul [ class "inset-m" ]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.filterMap identity
                    |> List.map viewWorkspace
                )



viewCards : List W.WorkspaceId -> Dict W.WorkspaceId W.Workspace -> Html Msg
viewCards workspacesIds workspacesInfo =
    let
        getWorkspace id =
            Dict.get id workspacesInfo

        viewCardOrEmptyText maybeWorkspace =
            case maybeWorkspace of
                Just workspace ->
                    viewCard workspace

                Nothing ->
                    text ""

        viewGrid =
            div [ class <| "grid gridTemplateCol-3 gridGap-xs"]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.map viewCardOrEmptyText
                )

        viewList =
            div [ class <| "grid gridTemplateCol-3 gridGap-xs"]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.map viewCardOrEmptyText
                )
    in
    case workspacesIds of
        [] ->
            div [ class <| "flex padding-xl justifyContent-center alignItems-center paddingTop-xl paddingBottom-xl" ]
                [ h3 [ class "text-primary textAlign-center" ]
                    [ text "You don't have more workspaces created" ]
                ]

        _ ->
            div [ class "padding-m paddingTop-xl" ]
                [ viewGrid ]



viewCard : W.Workspace -> Html Msg
viewCard { id, name, color, tabs } =
    let
        title =
            p [ class <| "fontSize-m marginBottom-xs ellipsis overflow-hidden whiteSpace-nowrap textAlign-left color-contrast _color-" ++ C.fromColorToString color ]
                [ text name ]

        tabsCount num =
            div [ class "textAlign-left color-contrast" ]
                [ text <| String.fromInt num ++ " Tabs" ]

        style1 =
            "padding-xs paddingLeft-m paddingRight-m neo-card-style-1 border-s _borderColor-" ++ C.fromColorToString color

        style2 =
            "rounded padding-xs paddingLeft-m paddingRight-m gradient-" ++ C.fromColorToString color
    in
    button
        [ class style1
        , autofocus False
        , tabindex 0
        , onClick <| OpenWorkspace id
        , onFocus <| ElementFocused WorkspaceCardFocused
        , onBlur ElementBlurred
        ]
        [ title
        , tabsCount <| List.length tabs
        ]



-- FORM


viewFormCollapsed : Model -> Html Msg
viewFormCollapsed model =
    Html.form [ class formContainerStyle ]
        [ input
            [ class <| inputStyle ++ " marginBottom-l"
            , type_ "text"
            , placeholder "Type a Name"
            , id "input-workspace-name"
            , selected True
            , autofocus True
            , onBlur ElementBlurred
            , onFocus <| ElementFocused WorkspaceNameInputFocused
            , onInput
                (\value ->
                    UpdateForm <| ChangeName value
                )
            ]
            []
        , p [ class "color-contrast marginBottom-m letterSpacing-05" ]
            [ text "You have "
            , span [ class "color-highlighted" ]
                [ text <| String.fromInt model.data.numTabsInUse
                , text " tabs"
                ]
            , text " opened. Type a name to save it."
            ]
        ]


viewFormExpanded : FormData -> List C.Color -> Html Msg
viewFormExpanded { name, color } colorList =
    Html.form [ class formContainerStyle ]
        [ input
            [ class <| inputStyle ++ " marginBottom-l color-" ++ C.fromColorToString color
            , type_ "text"
            , placeholder "Type a Name"
            , id <| fromFocusStatusToElementId WorkspaceNameInputFocused
            , tabindex 0
            , selected True
            , autofocus True
            , Html.Attributes.value name
            , onBlur ElementBlurred
            , onFocus <| ElementFocused WorkspaceNameInputFocused
            , onInput
                (\value ->
                    UpdateForm <| ChangeName value
                )
            ]
            []
        , viewRadioGroupColors color colorList
        ]


formContainerStyle : String
formContainerStyle =
    String.join " "
        [ "flex"
        , "flexDirection-col"
        , "justifyContent-space-between"
        , "alignItems-center"
        , "backdrop-filter-blur"
        , "padding-l"
        , "height-m"
        ]



inputStyle : String
inputStyle =
    String.join " "
        [ "fontSize-l"
        , "marginTop-none"
        , "marginBottom-m"
        , "fontWeight-200"
        , "color-contrast"
        , "padding-xs"
        , "textAlign-center"
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
                , "stretch-inset-m"
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

        formHelp =
            case model.formCardStatus of
                Collapsed ->
                    case model.formData.status of
                        WithErrors ->
                            textHelpContainer
                                [ robot
                                , text "You must to type a name to save the current tabs"
                                ]

                        _ ->
                            text ""

                Expanded ->
                    case model.formData.status of
                        Empty ->
                            text ""

                        Filled ->
                            textHelpContainer
                                [ enter
                                , text "Save"
                                ]

                        WithErrors ->
                            textHelpContainer
                                [ robot
                                , text "You must to type a name to save the current tabs"
                                ]

        navigationHelp =
            case model.focusStatus of
                WithoutFocus ->
                    textHelpContainer
                        [ tab
                        , text "Move"
                        ]

                WorkspaceNameInputFocused ->
                    case model.formCardStatus of
                        Collapsed ->
                            case model.status of
                                WorkspaceInUse _ ->
                                    case model.data.workspacesIds of
                                        [] ->
                                            text ""

                                        [_] ->
                                            text ""

                                        _ ->
                                            textHelpContainer
                                                [ tab
                                                , text "Move"
                                                ]

                                _ ->
                                    case model.data.workspacesIds of
                                        [] ->
                                            text ""

                                        _ ->
                                            textHelpContainer
                                                [ tab
                                                , text "Move"
                                                ]

                        Expanded ->
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
            [ formHelp
            , navigationHelp
            ]
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

