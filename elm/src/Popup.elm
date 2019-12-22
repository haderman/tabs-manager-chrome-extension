module Popup exposing (..)

import Browser
import Color as C
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (..)
import Ports
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
    = NoInitated
    | Idle
    | NoData
    | WorkspaceInUse W.WorkspaceId
    | CreatingNewWorkspace FormStatus


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
    }


initModel : Model
initModel =
    { data =
        { workspacesIds = []
        , workspacesInfo = Dict.empty
        , status = NoInitated
        }
    , status = NoInitated
    , formData =
        { name = ""
        , color = C.Green
        , status = Empty
        }
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


updateForm : FormMsg -> Model -> ( Model, Cmd Msg )
updateForm formMsg model =
    case formMsg of
        ChangeName value ->
            ( { model
                | formData = setName value model.formData
                , status =
                    if String.isEmpty value then
                        Idle
                    else
                        CreatingNewWorkspace model.formData.status
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receivedDataFromJS (Decode.decodeValue dataDecoder >> ReceivedDataFromJS) ]



-- VIEW


view : Model -> Html Msg
view model =
    case model.status of
        WorkspaceInUse id ->
            div []
                [ vieHeaderWorkspaceInUse id model.data
                , viewCards model.data
                ]

        NoInitated ->
            div [ class "flex justifyContent-center alignItems-center" ]
                [ h2 []
                    [ text "Loading..." ]
                ]

        Idle ->
            viewWorkspaceForm model.formData
            -- div []
            --     [ viewHeaderWithInput model
            --     , viewCards model.data
            --     ]

        CreatingNewWorkspace _ ->
            viewWorkspaceForm model.formData
            -- div []
            --     [ viewWorkspaceForm model.formData
            --     , viewCards model.data
            --     ]

        NoData ->
            viewWorkspaceForm model.formData



-- VIEW HEADER


headerStyle : String
headerStyle =
    String.join " "
        [ "full-width"
        , "height-s"
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


viewHeaderWithInput : Model -> Html Msg
viewHeaderWithInput model =
    div [ class headerStyle ]
        [ input
            [ class inputStyle
            , selected True
            , autofocus True
            , onInput (\_ -> NoOp)
            ]
            []
        ]


viewHeaderCreatingWorkspace : FormStatus -> Model -> Html Msg
viewHeaderCreatingWorkspace status model =
    let
        headerStyle_ =
            "background-secondary"

        content =
            case status of
                Empty ->
                    input
                        [ class inputStyle
                        , selected True
                        , autofocus True
                        , Html.Attributes.value model.formData.name
                        , onInput (\_ -> NoOp)
                        ]
                        []

                _ ->
                    text ""
    in
    div [ class <| headerStyle ++ " " ++ headerStyle_ ]
        [ content ]



-- VIEW HEADER HELPERS


inputStyle : String
inputStyle =
    "fontSize-l background-transparent marginTop-none marginBottom-m fontWeight-200 color-contrast padding-xs textAlign-center"



-- VIEW CONTENT


viewContent : Model -> Html Msg
viewContent { data } =
    case data.workspacesIds of
        [] ->
            viewEmptyWorkspacesListMessage

        _ ->
            viewCards data


viewEmptyWorkspacesListMessage : Html Msg
viewEmptyWorkspacesListMessage =
    div [ class "flex justifyContent-center alignItems-center" ]
        [ h2 [ class "color-contrast" ]
            [ text "NO HAY WORKSPACES" ]
        ]


viewCards : Data -> Html Msg
viewCards data =
    let
        getWorkspace id =
            Dict.get id data.workspacesInfo

        viewCardOrEmptyText maybeWorkspace =
            case maybeWorkspace of
                Just workspace ->
                    viewCard workspace

                Nothing ->
                    text ""
    in
    div [ class "grid gridTemplateCol-3 gridGap-xs padding-l" ]
        (data.workspacesIds
            |> List.map getWorkspace
            |> List.map viewCardOrEmptyText
        )


viewCard : W.Workspace -> Html Msg
viewCard workspace =
    let
        title name color =
            div [ class <| "fontSize-l ellipsis overflowHidden whiteSpace-nowrap textAlign-left color-" ++ C.fromColorToString color ]
                [ text name ]

        tabsCount num =
            div [ class "fontSize-xs color-contrast textAlign-left" ]
                [ text <| String.fromInt num ++ " Tabs" ]
    in
    button
        [ class "background-black padding-m rounded"
        , autofocus True
        , onClick <| OpenWorkspace workspace.id
        ]
        [ title workspace.name workspace.color
        , tabsCount <| List.length workspace.tabs
        ]



viewWorkspaceForm : FormData -> Html Msg
viewWorkspaceForm { name, color, status } =
    let
        containerStyle =
            String.join " "
                [ "flex"
                , "flexDirection-col"
                , "justifyContent-center"
                , "alignItems-center"
                , "ackdrop-filter-blur"
                , "padding-xl"
                ]

        help =
            case status of
                Empty ->
                    "Form empty"

                Filled ->
                    "Form listo para guardar"

                _ ->
                    "Otro estado"





    in
    div [ class containerStyle ]
        [ input
            [ class <| inputStyle ++ " marginBottom-l color-" ++ C.fromColorToString color
            , selected True
            , autofocus True
            , Html.Attributes.value name
            , onInput
                (\value ->
                    UpdateForm <| ChangeName value
                )
            ]
            []
        , viewRadioGroupColors color
        , p [ class "color-contrast marginBottom-l" ]
            [ text help ]
        , button [ class "padding-m rounded background-secondary color-contrast" ]
            [ text "Save" ]
        ]


viewRadioGroupColors : C.Color -> Html Msg
viewRadioGroupColors color =
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

