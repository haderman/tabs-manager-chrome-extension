module MyColor exposing
    ( MyColor (..)
    , list
    , default
    , decoder
    , toMyColorCSS
    , toBackgroundCSS
    , toMyColor
    , toString
    )

import Json.Decode as D


type MyColor
    = MyColorA
    | MyColorB
    | MyColorC
    | MyColorD
    | MyColorE
    | MyColorF
    | MyColorG
    | MyColorH
    | MyColorI


list : List MyColor
list =
    [ MyColorA
    , MyColorB
    , MyColorC
    , MyColorD
    , MyColorE
    , MyColorF
    , MyColorG
    , MyColorH
    , MyColorI
    ]


default : MyColor
default =
    List.head list
        |> Maybe.withDefault MyColorA


toBackgroundCSS : MyColor -> String
toBackgroundCSS color =
    "background-" ++ toString color


toMyColorCSS : MyColor -> String
toMyColorCSS color =
    "color-" ++ toString color


toString : MyColor -> String
toString color =
    case color of
        MyColorA ->
            "a"

        MyColorB ->
            "b"

        MyColorC ->
            "c"

        MyColorD ->
            "d"

        MyColorE ->
            "e"

        MyColorF ->
            "f"

        MyColorG ->
            "g"

        MyColorH ->
            "h"

        MyColorI ->
            "i"


toMyColor : String -> MyColor
toMyColor str =
    case str of
        "a" ->
            MyColorA

        "b" ->
            MyColorB

        "c" ->
            MyColorC

        "d" ->
            MyColorD

        "e" ->
            MyColorE

        "f" ->
            MyColorF

        "g" ->
            MyColorG

        "h" ->
            MyColorH

        _ ->
            MyColorI



-- JSON


decoder : D.Decoder MyColor
decoder =
    D.string
        |> D.andThen (D.succeed << toMyColor)
