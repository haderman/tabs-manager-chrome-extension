module MyColor exposing
    ( Color (..)
    , list
    , default
    , decoder
    , toBackgroundCSS
    , fromColorToString
    , fromStringToColor
    )

import Json.Decode as D


type Color
    = ColorA
    | ColorB
    | ColorC
    | ColorD
    | ColorE
    | ColorF
    | ColorG
    | ColorH
    | ColorI


list : List Color
list =
    [ ColorA
    , ColorB
    , ColorC
    , ColorD
    , ColorE
    , ColorF
    , ColorG
    , ColorH
    , ColorI
    ]


default : Color
default =
    ColorA


toBackgroundCSS : Color -> String
toBackgroundCSS color =
    "background-" ++ toString color



-- HELPERS


toString : Color -> String
toString color =
    case color of
        ColorA ->
            "a"

        ColorB ->
            "b"

        ColorC ->
            "c"

        ColorD ->
            "d"

        ColorE ->
            "e"

        ColorF ->
            "f"

        ColorG ->
            "g"

        ColorH ->
            "h"

        ColorI ->
            "i"




fromColorToString : Color -> String
fromColorToString color =
    case color of
        ColorA ->
            "green"

        ColorB ->
            "blue"

        ColorC ->
            "orange"

        ColorD ->
            "purple"

        ColorE ->
            "yellow"

        ColorF ->
            "red"

        ColorG ->
            "gray"

        ColorH ->
            "cyan"

        ColorI ->
            "cyan"


fromStringToColor : String -> Color
fromStringToColor str =
    case str of
        "green" ->
            ColorA

        "blue" ->
            ColorB

        "orange" ->
            ColorC

        "purple" ->
            ColorD

        "yellow" ->
            ColorE

        "red" ->
            ColorF

        "gray" ->
            ColorG

        "cyan" ->
            ColorH

        _ ->
            ColorI



-- JSON


decoder : D.Decoder Color
decoder =
    D.string
        |> D.andThen (D.succeed << fromStringToColor)
