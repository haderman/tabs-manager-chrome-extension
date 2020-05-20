module View.Icon exposing
    (openTab
    , edit
    , delete
    , save
    , close
    , moon
    , sun
    , settings
    , github
    , arrowRight
    , arrowLeft
    , backspace
    , enter
    )


import Html exposing (Html)
import Html.Attributes as Attributes
import Size exposing (Size)



openTab : Size -> Html msg
openTab =
    icon "globe"


edit : Size -> Html msg
edit =
    icon "pencil"


delete : Size -> Html msg
delete =
    icon "trash"


save : Size -> Html msg
save =
    icon "save"


close : Size -> Html msg
close =
    icon "close"


moon : Size -> Html msg
moon =
    icon "moon"


sun : Size -> Html msg
sun =
    icon "sun"


settings : Size -> Html msg
settings =
    icon "cog"


arrowRight : Size -> Html msg
arrowRight =
    icon "arrow-right"


github : Size -> Html msg
github =
    icon "github"


arrowLeft : Size -> Html msg
arrowLeft =
    icon "arrow-left"


backspace : Size -> Html msg
backspace =
    icon "backspace"


enter : Size -> Html msg
enter =
    icon "enter"



-- INTERNALS


icon : String -> Size -> Html msg
icon name size =
    let
        src =
            "/assets/icons/" ++ name ++ ".svg"

        sufix =
            Size.toString size

        height =
            "height-" ++ sufix

        width =
            "width-" ++ sufix
    in
    Html.i [ Attributes.class "inline-flex justify-center align-center" ]
        [ Html.img
            [ Attributes.class <| width ++ " " ++ height
            , Attributes.src src
            , Attributes.alt <| composeAltText name
            ]
            []
        ]


composeAltText : String -> String
composeAltText name =
    String.replace "-" " " name ++ " icon"
