module Popup exposing (..)

import Browser
import Browser.Dom as Dom
import Browser.Events exposing (onKeyDown)
import Color as C
import Dict exposing (Dict)
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
    | CreatingNewWorkspace


type alias Data =
    { workspacesIds : List W.WorkspaceId
    , status : Status
    , workspacesInfo : Dict W.WorkspaceId W.Workspace
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

        ButtonCreatePressed ->
            ( { model | status = CreatingNewWorkspace }, Cmd.none )

        ButtonSavePressed ->
            tryToSaveWorkspace model

        KeyPressed key ->
            handleKeyPressed key model

        ElementFocused focusStatus ->
            ( { model | focusStatus = focusStatus }, Cmd.none )

        ElementBlurred ->
            ( { model | focusStatus = WithoutFocus }, Cmd.none )

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

        CreatingNewWorkspace ->
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
            ( model, Ports.createWorkspace payload )

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
        WorkspaceInUse id ->
            viewWorkspaceInUse id model.data

        NoInitiated ->
            viewNoInitiated

        Idle ->
            viewIdle model

        CreatingNewWorkspace ->
            viewFormExpanded model.formData model.colorList

        NoData ->
            viewNoData model.formData model.colorList


viewWorkspaceInUse : W.WorkspaceId -> Data -> Html Msg
viewWorkspaceInUse id data =
    let
        idInUse id_ =
            not (id_ == id)

        workspacesIds =
            List.filter idInUse data.workspacesIds
    in
    div []
        [ vieHeaderWorkspaceInUse id data
        , viewCards workspacesIds data.workspacesInfo
        ]


viewNoInitiated : Html Msg
viewNoInitiated =
    div [ class "flex justifyContent-center alignItems-center" ]
        [ h2 [ class "color-contrast" ]
            [ text "Loading..." ]
        ]


viewIdle : Model -> Html Msg
viewIdle { data, formData, formCardStatus, colorList } =
    case formCardStatus of
        Collapsed ->
            div []
                [ viewFormCollapsed formData
                , viewCards data.workspacesIds data.workspacesInfo
                ]

        Expanded ->
            div []
                [ viewFormExpanded formData colorList
                , viewCards data.workspacesIds data.workspacesInfo
                ]



viewNoData : FormData -> List C.Color -> Html Msg
viewNoData formData colorList =
    let
        greet =
            "Welcome!"

        help =
            "Aun no tienes Workspaces creados, pressiona Enter o Click en el boton Crear"
    in
    div [ class "flex flexDirection-col justifyContent-center alignItems-center padding-xl alignText-center" ]
        [ h3 [ class "color-alternate" ]
            [ text greet ]
        , p [ class "color-contrast marginBottom-l" ]
            [ text help ]
        , viewFormExpanded formData colorList
        ]



-- VIEW HEADER


headerStyle : String
headerStyle =
    String.join " "
        [ "height-s"
        , "background-transparent"
        , "sticky"
        , "backdrop-filter-blur"
        , "boxShadow-black"
        , "zIndex-4"
        , "marginBottom-xl"
        , "flex"
        , "alignItems-center"
        , "justifyContent-center"
        , "padding-xl"
        ]


vieHeaderWorkspaceInUse : W.WorkspaceId -> Data -> Html Msg
vieHeaderWorkspaceInUse id data =
    let
        title =
            case Dict.get id data.workspacesInfo of
                Just { name, color } ->
                    h2 [ Html.Attributes.class <| "color-" ++ C.fromColorToString color ]
                        [ Html.text name ]

                Nothing ->
                    Html.text ""
    in
    div [ class headerStyle ]
        [ title ]



-- VIEW HEADER HELPERS


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
            div [ class "flex justifyContent-center alignItems-center padding-l" ]
                [ h3 [ class "color-contrast textAlign-center" ]
                    [ text "No hay mas workspaces creados"]
                ]

        _ ->
            div [ class "grid gridTemplateCol-3 gridGap-xs padding-l" ]
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
        , tabindex 2
        , onClick <| OpenWorkspace workspace.id
        ]
        [ title workspace.name workspace.color
        , tabsCount <| List.length workspace.tabs
        ]



-- FORM


viewFormCollapsed : FormData -> Html Msg
viewFormCollapsed { name, color, status } =
    div [ class formContainerStyle ]
        [ input
            [ class <| inputStyle ++ " marginBottom-l color-" ++ C.fromColorToString color
            , type_ "text"
            , id "input-workspace-name"
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
        , p [ class "color-contrast marginBottom-l" ]
            [ text <| formHelpText status ]
        ]


viewFormExpanded : FormData -> List C.Color -> Html Msg
viewFormExpanded { name, color, status } colorList =
    div [ class formContainerStyle ]
        [ input
            [ class <| inputStyle ++ " marginBottom-l color-" ++ C.fromColorToString color
            , type_ "text"
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
        , p [ class "color-contrast marginBottom-l" ]
            [ text <| formHelpText status ]
        , viewRadioGroupColors color colorList
        , button
            [ class "padding-m rounded background-secondary color-contrast"
            , onClick ButtonSavePressed
            ]
            [ text "Save" ]
        ]


formHelpText : FormStatus -> String
formHelpText status =
    case status of
        Empty ->
            "Form empty"

        Filled ->
            "Form listo para guardar"

        WithErrors ->
            "Ingresa un nombre primero"


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
        [ Html.Attributes.class "flex opacity-70"
        , id <| fromFocusStatusToElementId RadioGroupColorsFocused
        , tabindex 1
        , onBlur ElementBlurred
        , onFocus <| ElementFocused RadioGroupColorsFocused
        ]
        <| List.map radio colorList



-- VIEW FOOTER


viewFooter : Model -> Html Msg
viewFooter model =
    div [] []


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

