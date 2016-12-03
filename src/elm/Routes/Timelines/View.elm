module Routes.Timelines.View exposing ( root )

import Routes.Timelines.Types exposing (..)
import Routes.Timelines.TweetBar.View
import Routes.Timelines.Timeline.View
import Generic.Utils exposing ( tooltip )
import Html exposing ( Html, div, button )
import Html.Attributes exposing ( class )
import Html.Events exposing ( onClick )
import Html.App



root : Model -> Html Msg
root model =
    div [ class "Timelines" ]
        [ Routes.Timelines.Timeline.View.root model.timelineModel
            |> Html.App.map TimelineMsg

        , Routes.Timelines.TweetBar.View.root model.tweetBarModel
            |> Html.App.map TweetBarMsg
        , footer
        ]


footer : Html Msg
footer =
    div [ class "Timelines-footer" ]
        [ button
            [ class "zmdi zmdi-collection-item btn btn-default btn-icon"
            , tooltip "Detach window"
            , onClick Detach
            ] []
        , button
            [ class "zmdi zmdi-power btn btn-default btn-icon"
            , tooltip "Logout"
            , onClick MsgLogout
            ] []
        ]
