module Tweets.View exposing (..)


import Tweets.Types exposing (..)
import Generic.Utils exposing ( errorMessage )
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Array
import Regex
import RemoteData exposing (..)
import Json.Encode



root : Model -> Html Msg
root model =
  div [ class "Tweets"]
    [ loadingBar model.newTweets
    , div [] ( List.indexedMap tweetView model.tweets )
    ]



loadingBar : WebData (List Tweet) -> Html Msg
loadingBar request =
    case request of
            Loading ->
                section [ class "Tweets-loading" ]
                    [ div [ class "load-bar" ]
                        [ div [ class "bar" ] []
                        , div [ class "bar" ] []
                        , div [ class "bar" ] []
                        ]
                    ]

            Failure err ->
                div [] [ errorView err ]

            otherwise ->
                div [] []



tweetView : Int -> Tweet -> Html Msg
tweetView index tweet =
  div
    [ class "Tweet"
    , style [ ("borderColor", ( getColor index ) )]
    ]
    [ img
        [ class "Tweet-userImage"
        , src tweet.user.profile_image_url_https
        ] []
    , div []
        [ div
            [ class "Tweet-userInfoContainer"]
            [ a
                [ class "Tweet-userName"
                , href ( "https://twitter.com/" ++ tweet.user.screen_name )
                , target "_blank"
                ]
                [ text tweet.user.name ]
            , a
                [ class "Tweet-userHandler"
                , href ( "https://twitter.com/" ++ tweet.user.screen_name )
                , target "_blank"
                ]
                [ text ( "@" ++ tweet.user.screen_name ) ]
            ]
        , p
            [ class "Tweet-text"
            , property "innerHTML" <| Json.Encode.string ( tweetTextView tweet )
            ]
            []
        ]
    ]


getColor : Int -> String
getColor index =
  let
    colorNum = index % Array.length colors
    defaultColor = "#F44336"
  in
    case Array.get colorNum colors of
      Just color ->
        color

      Nothing ->
        defaultColor


colors : Array.Array String
colors =
  Array.fromList
    [ "#F44336"
    , "#009688"
    , "#E91E63"
    , "#9E9E9E"
    , "#FF9800"
    , "#03A9F4"
    , "#8BC34A"
    , "#FF5722"
    , "#607D8B"
    , "#3F51B5"
    , "#CDDC39"
    , "#2196F3"
    , "#F44336"
    , "#000000"
    , "#E91E63"
    , "#FFEB3B"
    , "#9C27B0"
    , "#673AB7"
    , "#795548"
    , "#4CAF50"
    , "#FFC107"
    ]



errorView : Http.Error -> Html Msg
errorView error =
    div [ class "Tweets-error animated fadeInDown" ]
        [ text ( errorMessage error)
        ]



tweetTextView : Tweet -> String
tweetTextView { text, entities } =
    text
     |> (flip23 List.foldl) linkUrl entities.urls
     |> (flip23 List.foldl) linkUserMentions entities.user_mentions



flip23 : (a -> b -> c -> d) -> a -> c -> b -> d
flip23 f =
    (\a c b -> f a b c)



linkUrl : UrlRecord -> String -> String
linkUrl url tweetText =
    let
        linkText =
            "<a target=\"_blank\" href=\""
            ++ url.url
            ++ "\">"
            ++ url.display_url
            ++ "</a>"
    in
        Regex.replace Regex.All (Regex.regex (Regex.escape url.url)) (\_ -> linkText) tweetText



linkUserMentions : UserMentionsRecord -> String -> String
linkUserMentions { screen_name } tweetText =
    let
        handler = "@" ++ screen_name
        linkText =
            "<a target=\"_blank\" href=\"https://twitter.com/"
            ++ screen_name
            ++ "\">"
            ++ handler
            ++ "</a>"
    in
        Regex.replace Regex.All (Regex.regex (Regex.escape handler)) (\_ -> linkText) tweetText