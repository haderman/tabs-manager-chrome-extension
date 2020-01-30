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
    | OpeningWorkspace


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


initColorList : List C.Color
initColorList =
    [ C.Green
    , C.Blue
    , C.Orange
    , C.Purple
    , C.Yellow
    , C.Red
    , C.Gray
    , C.Cyan
    ]


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
        , color = C.Green
        , status = Empty
        }
    , focusStatus = WithoutFocus
    , colorList = initColorList
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
    | ButtonCreatePressed
    | ButtonSavePressed
    | KeyPressed Key
    | TryFocusElement (Result Dom.Error ())
    | ElementFocused FocusStatus
    | ElementBlurred
    | OpenChromePage String


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

        ButtonSavePressed ->
            tryToSaveWorkspace model

        KeyPressed key ->
            handleKeyPressed key model

        ElementFocused focusStatus ->
            ( { model | focusStatus = focusStatus }, Cmd.none )

        ElementBlurred ->
            ( { model | focusStatus = WithoutFocus }, Cmd.none )

        OpenChromePage url ->
            ( model, Ports.openChromePage url )

        _ ->
            ( model, Cmd.none )


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
        WorkspaceInUse workspaceId ->
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

                color_ =
                    model.data.workspacesInfo
                        |> Dict.get workspaceId
                        |> Maybe.map .color
                        |> Maybe.withDefault C.Gray
            in
            div [ id "root" ]
                [ viewHeader
                , div [ class "flex alignItems-center justifyContent-space-between padding-m" ]
                    [ span [ class <| "borderBottom-s borderColor-" ++ C.fromColorToString color_ ]
                        [ span [ class "color-contrast fontSize-xl" ]
                            [ workspaceName ]
                        , text " "
                        , span [ class "color-contrast" ]
                            [ text <| String.fromInt model.data.numTabsInUse ++ " Tabs" ]
                        ]
                    ]
                , viewCards workspacesIds model.data.workspacesInfo
                , viewFooter model
                ]

        NoInitiated ->
            div [ class "flex justifyContent-center alignItems-center" ]
                [ h2 [ class "color-contrast" ]
                    [ text "Loading..." ]
                ]

        Idle ->
            case model.formCardStatus of
                Collapsed ->
                    div [ id "root" ]
                        [ viewHeader
                        , viewFormCollapsed
                        , viewCards model.data.workspacesIds model.data.workspacesInfo
                        , viewFooter model
                        ]

                Expanded ->
                    div [ id "root" ]
                        [ viewHeader
                        , viewFormExpanded model.formData model.colorList
                        , viewFooter model
                        ]

        NoData ->
            let
                wavingHand =
                    "\u{1F44B}"

                greet =
                    div [ class "color-contrast fontSize-m textAlign-center" ]
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
                [ viewHeader
                , div [ class "relative flex flexDirection-col justifyContent-center alignItems-stretch padding-xl alignText-center" ]
                    [ greet
                    , viewFormExpanded model.formData model.colorList
                    , viewFooter model
                    ]
                ]

        OpeningWorkspace ->
            div [ class "flex justifyContent-center alignItems-center" ]
                [ h2 [ class "color-contrast" ]
                    [ text "Opening workspace..." ]
                ]


viewHeader : Html Msg
viewHeader =
    let
        gitHubLink =
            a
                [ target "_blank"
                , href "https://github.com/haderman/tabs-manager-chrome-extension"
                , tabindex 1
                , onFocus <| ElementFocused GitHubLinkeFocused
                , onBlur ElementBlurred
                ]
                [ img
                    [ class "height-xs width-xs hover-opacity"
                    , src "/assets/icons/github-light-32px.png"
                    ]
                    []
                ]

        addShorcutLink =
            a
                [ href "#"
                , class "color-highlighted hover-opacity"
                , onClick <| OpenChromePage "chrome://extensions/shortcuts"
                , tabindex 2
                , onFocus <| ElementFocused AddShortcutLinkFocused
                , onBlur ElementBlurred
                ]
                [ text "Add shortcut" ]

        separator =
            span [ class "marginLeft-xs marginRight-xs" ]
                [ text "|"]

        settingsLink =
            a
                [ target "_blank"
                , href "/newtab/newtab.html"
                , tabindex 3
                , onFocus <| ElementFocused SettingsLinkFocused
                , onBlur ElementBlurred
                ]
                [ img
                    [ class "height-xs width-xs hover-opacity"
                    , src "/assets/icons/cog.svg"
                    ]
                    []
                ]
    in
    div [ class "background-black-2 padding-s flex alignItems-center justifyContent-space-between" ]
        [ gitHubLink
        , span [ class "flex alignItems-center" ]
            [ addShorcutLink
            , separator
            , settingsLink
            ]
        ]


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

    in
    case workspacesIds of
        [] ->
            div [ class "flex justifyContent-center alignItems-center padding-m" ]
                [ h3 [ class "color-contrast textAlign-center" ]
                    [ text "You don't have more workspaces created" ]
                ]

        _ ->
            div [ class "grid gridTemplateCol-3 gridGap-xs padding-m" ]
                (workspacesIds
                    |> List.map getWorkspace
                    |> List.map viewCardOrEmptyText
                )


viewCard : W.Workspace -> Html Msg
viewCard workspace =
    let
        title name color =
            div [ class <| "fontSize-l ellipsis overflow-hidden whiteSpace-nowrap textAlign-left color-" ++ C.fromColorToString color ]
                [ text name ]

        tabsCount num =
            div [ class "fontSize-xs color-contrast textAlign-left" ]
                [ text <| String.fromInt num ++ " Tabs" ]
    in
    button
        [ class "background-black padding-m rounded"
        , autofocus False
        , tabindex 0
        , onClick <| OpenWorkspace workspace.id
        , onFocus <| ElementFocused WorkspaceCardFocused
        , onBlur ElementBlurred
        ]
        [ title workspace.name workspace.color
        , tabsCount <| List.length workspace.tabs
        ]



-- FORM


viewFormCollapsed : Html Msg
viewFormCollapsed =
    div [ class formContainerStyle ]
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
        ]


viewFormExpanded : FormData -> List C.Color -> Html Msg
viewFormExpanded { name, color } colorList =
    div [ class formContainerStyle ]
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
        , "justifyContent-center"
        , "alignItems-center"
        , "ackdrop-filter-blur"
        , "padding-xl"
        ]



inputStyle : String
inputStyle =
    String.join " "
        [ "fontSize-l"
        , "background-transparent"
        , "marginTop-none"
        , "marginBottom-m"
        , "fontWeight-200"
        , "color-contrast"
        , "padding-xs"
        , "textAlign-center"
        , "background-black"
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
        [ class "flex opacity-70 padding-m"
        , id <| fromFocusStatusToElementId RadioGroupColorsFocused
        , tabindex 1
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
                , "justfyContet-space-between"
                , "alignContent-flexEnd"
                , "padding-m"
                , "backdrop-filter-blur"
                , "sticky"
                , "bottom-0"
                , "background-transparent"
                , "height-s"
                , "marginTop-s"
                ]

        helpContainerStyle =
            String.join " "
                [ "full-width"
                , "flex"
                , "justifyContent-flexStart"
                , "alignItems-flexStart"
                , "flexDirection-colReverse"
                , "color-contrast"
                , "full-height"
                ]

        highlighted =
            class "color-highlighted"

        arrowLeft =
            span [ highlighted ]
                [ text "\u{2190}" ]

        arrowRight =
            span [ highlighted ]
                [ text "\u{2192}" ]

        arrowDown =
            span [ highlighted ]
                [ text "\u{2193}" ]

        arrowUp =
            span [ highlighted ]
                [ text "\u{2191}" ]

        enter =
            span [ highlighted ]
                [ text "\u{21B2}" ]

        robot =
            span [ class "fontSize-s" ]
                [ text "\u{1F47E}" ]

        formHelp =
            case model.formCardStatus of
                Collapsed ->
                    case model.formData.status of
                        WithErrors ->
                            p []
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
                            p []
                                [ enter
                                , text " To save the current tabs"
                                ]

                        WithErrors ->
                            p []
                                [ robot
                                , text "You must to type a name to save the current tabs"
                                ]

        navigationHelp =
            case model.focusStatus of
                WithoutFocus ->
                    p []
                        [ span [ highlighted ]
                            [ text "Tab" ]
                        , text " To navigate between UI elements"
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
                                            p []
                                                [ span [ highlighted ]
                                                    [ text "Tab" ]
                                                , text " To navigate between workspaces created"
                                                ]

                                _ ->
                                    case model.data.workspacesIds of
                                        [] ->
                                            text ""

                                        _ ->
                                            p []
                                                [ span [ highlighted ]
                                                    [ text "Tab" ]
                                                , text " To navigate between workspaces created"
                                                ]

                        Expanded ->
                            p []
                                [ arrowDown
                                , text " To focus the colors group"
                                ]

                RadioGroupColorsFocused ->
                    p []
                        [ arrowUp
                        , text " To focus the input text and "
                        , arrowLeft
                        , arrowRight
                        , text " To chan ge the color"
                        ]

                WorkspaceCardFocused ->
                    p []
                        [ span [ highlighted ]
                            [ text "Space" ]
                        , text " or "
                        , enter
                        , text " To open the workspace tabs"
                        ]

                GitHubLinkeFocused ->
                    p []
                        [ enter
                        , text " To go to repository on github"
                        ]

                AddShortcutLinkFocused ->
                    p []
                        [ enter
                        , text " If you want to add shortcut to open this popup whit the keyboard"
                        ]

                SettingsLinkFocused ->
                    p []
                        [ enter
                        , text " To go to the advanced view"
                        ]


    in
    div [ class rootStyle ]
        [ div [ class helpContainerStyle ]
            [ navigationHelp
            , formHelp
            ]
        ]



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
    Decode.oneOf [ workspaceInUseDecoder, otherStateDecoder ]


workspaceInUseDecoder : Decoder Status
workspaceInUseDecoder =
    Decode.map WorkspaceInUse <|
        Decode.field "workspaceInUse" Decode.int


otherStateDecoder : Decoder Status
otherStateDecoder =
    Decode.field "state" Decode.string |> Decode.andThen statusFromString


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

