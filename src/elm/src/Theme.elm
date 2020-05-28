module Theme exposing
    ( Theme (..)
    , default
    , decoder
    , toString
    )


import Json.Decode as Decode exposing (Decoder)


type Theme
    = Dark
    | Light



default : Theme
default =
    Dark


toString : Theme -> String
toString theme =
    case theme of
        Dark ->
            "dark"

        Light ->
            "light"


decoder : Decoder Theme
decoder =
    Decode.field "theme" Decode.string
        |> Decode.andThen
            (\theme ->
                case theme of
                    "light" ->
                        Decode.succeed Light

                    "dark" ->
                        Decode.succeed Dark

                    _ ->
                        Decode.succeed Dark
            )
