module Color exposing (..)

import Json.Decode as D


type Color
    = Green
    | Blue
    | Orange
    | Purple
    | Yellow
    | Red
    | Gray
    | Cyan



-- HELPERS


fromColorToString : Color -> String
fromColorToString color =
    case color of
        Green ->
            "green"

        Blue ->
            "blue"

        Orange ->
            "orange"

        Purple ->
            "purple"

        Yellow ->
            "yellow"

        Red ->
            "red"

        Gray ->
            "gray"

        Cyan ->
            "cyan"


fromStringToColor : String -> Color
fromStringToColor str =
    case str of
        "green" ->
            Green

        "blue" ->
            Blue

        "orange" ->
            Orange

        "purple" ->
            Purple

        "yellow" ->
            Yellow

        "red" ->
            Red

        "gray" ->
            Gray

        "cyan" ->
            Cyan

        _ ->
            Gray



-- JSON


decoder : D.Decoder Color
decoder =
    D.string
        |> D.andThen (D.succeed << fromStringToColor)
