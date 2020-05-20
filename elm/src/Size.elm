module Size exposing
    ( Size (..)
    , toString
    )



type Size
    = XS
    | S
    | M
    | L
    | XL


toString : Size -> String
toString size =
    case size of
        XS -> "xs"
        S  -> "s"
        M  -> "m"
        L  -> "l"
        XL -> "xl"

