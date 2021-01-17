module Timelines.Timeline.TweetView exposing (tweetView)

import Array
import Generic.Utils exposing (timeDifference, tooltip)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Encode
import List.Extra
import Maybe
import Regex
import Regex.Extra exposing (regex)
import String
import Time exposing (Posix)
import Timelines.Timeline.Types exposing (..)
import Twitter.Types
    exposing
        ( HashtagRecord
        , MediaRecord(..)
        , MultiPhoto
        , QuotedTweet(..)
        , Retweet(..)
        , Tweet
        , UrlRecord
        , User
        , UserMentionsRecord
        , Video
        )


tweetView : Time.Zone -> Posix -> Int -> Tweet -> Html Msg
tweetView zone now index mainTweet =
    let
        tweet =
            getMainContent mainTweet
    in
    div
        [ class "Tweet"

        -- , style [ ( "borderColor", (getColor index) ) ]
        ]
        [ retweetInfo mainTweet
        , tweetContent zone now tweet
        , quotedContent zone now tweet
        , tweetActions tweet
        ]


getMainContent : Tweet -> Tweet
getMainContent tweet =
    tweet
        |> .retweeted_status
        |> Maybe.map (\(Retweet retweet) -> retweet)
        |> Maybe.withDefault tweet


timeInfo : Time.Zone -> Posix -> Tweet -> Html Msg
timeInfo zone now tweet =
    let
        info =
            timeDifference zone now tweet.created_at
    in
    a
        [ class "Tweet-timeInfo"
        , target "blank"
        , href <| "https://twitter.com/" ++ tweet.user.name ++ "/status/" ++ tweet.id
        ]
        [ text info ]


retweetInfo : Tweet -> Html Msg
retweetInfo topTweet =
    case topTweet.retweeted_status of
        Nothing ->
            text ""

        Just _ ->
            div [ class "Tweet-retweet-info" ]
                [ i [ class "zmdi zmdi-repeat Tweet-retweet-info-icons" ] []
                , text "retweeted by "
                , a
                    [ href <| userProfileLink topTweet.user
                    , target "blank"
                    ]
                    [ text ("@" ++ topTweet.user.screen_name) ]
                ]


tweetContent : Time.Zone -> Posix -> Tweet -> Html Msg
tweetContent zone now tweet =
    div [ class "Tweet-body" ]
        [ img
            [ class "Tweet-userImage"
            , src tweet.user.profile_image_url_https
            ]
            []
        , div [ class "Tweet-content" ]
            [ div
                [ class "Tweet-content-header" ]
                [ div
                    [ class "Tweet-userInfoContainer" ]
                    [ a
                        [ class "Tweet-userName"
                        , href <| userProfileLink tweet.user
                        , target "_blank"
                        ]
                        [ text tweet.user.name ]
                    , a
                        [ class "Tweet-userHandler"
                        , href <| userProfileLink tweet.user
                        , target "_blank"
                        ]
                        [ text ("@" ++ tweet.user.screen_name) ]
                    ]
                , timeInfo zone now tweet
                ]
            , p
                [ class "Tweet-text"
                , property "innerHTML" <| Json.Encode.string (tweetTextView tweet)
                ]
                []
            , div
                [ class "Tweet-media" ]
                [ mediaView tweet ]
            ]
        ]


quotedContent : Time.Zone -> Posix -> Tweet -> Html Msg
quotedContent zone now mainTweet =
    case mainTweet.quoted_status of
        Nothing ->
            text ""

        Just (QuotedTweet tweet) ->
            div [ class "Tweet-quoted" ]
                [ tweetContent zone now tweet
                ]


userProfileLink : User -> String
userProfileLink user =
    "https://twitter.com/" ++ user.screen_name


tweetActions : Tweet -> Html Msg
tweetActions tweet =
    div [ class "Tweet-actions" ]
        [ button
            [ class "Tweet-actions-reply zmdi zmdi-mail-reply"
            , onClick (SetReplyTweet tweet)
            , tooltip "Reply"
            ]
            []
        , button
            (if tweet.favorited then
                [ class "Tweet-actions-favourite--favorited"
                , onClick <| Favorite (not tweet.favorited) tweet.id
                , tooltip "Undo like"
                ]

             else
                [ class "Tweet-actions-favourite"
                , onClick <| Favorite (not tweet.favorited) tweet.id
                , tooltip "Like"
                ]
            )
            [ i [ class "zmdi zmdi-favorite" ] []
            , text (toStringNotZero tweet.favorite_count)
            ]
        , button
            (if tweet.retweeted then
                [ class "Tweet-actions-retweet--retweeted"
                , onClick <| DoRetweet (not tweet.retweeted) tweet.id
                , tooltip "Undo retweet"
                ]

             else
                [ class "Tweet-actions-retweet"
                , onClick <| DoRetweet (not tweet.retweeted) tweet.id
                , tooltip "Retweet"
                ]
            )
            [ i [ class "zmdi zmdi-repeat" ] []
            , text (toStringNotZero tweet.retweet_count)
            ]
        ]


getColor : Int -> String
getColor index =
    let
        colorNum =
            modBy (Array.length colors) index

        defaultColor =
            "#F44336"
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
        , "#e61865"
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


toStringNotZero : Int -> String
toStringNotZero num =
    if num > 0 then
        String.fromInt num

    else
        ""


tweetTextView : Tweet -> String
tweetTextView { text, entities, quoted_status } =
    text
        |> ((\f b a -> f a b) <| List.foldl linkUrl) entities.urls
        |> ((\f b a -> f a b) <| List.foldl removeMediaUrl) entities.media
        |> removeQuotedTweetUrl quoted_status entities.urls
        |> ((\f b a -> f a b) <| List.foldl linkHashtags) entities.hashtags
        |> ((\f b a -> f a b) <| List.foldl linkUserMentions) entities.user_mentions
        |> Regex.replace (regex "\\n") (\_ -> "<br/>")


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
    String.replace url.url linkText tweetText


linkUserMentions : UserMentionsRecord -> String -> String
linkUserMentions { screen_name } tweetText =
    let
        handler =
            "@" ++ screen_name

        linkText =
            "<a target=\"_blank\" href=\"https://twitter.com/"
                ++ screen_name
                ++ "\">"
                ++ handler
                ++ "</a>"
    in
    String.replace handler linkText tweetText


linkHashtags : HashtagRecord -> String -> String
linkHashtags { text } tweetText =
    let
        hash =
            "#" ++ text

        hashLink =
            "<a target=\"_blank\" href=\"https://twitter.com/hashtag/"
                ++ text
                ++ "?src=hash\">"
                ++ hash
                ++ "</a>"
    in
    String.replace hash hashLink tweetText


removeMediaUrl : MediaRecord -> String -> String
removeMediaUrl record tweetText =
    case record of
        VideoMedia video ->
            String.replace video.url "" tweetText

        MultiPhotoMedia photo ->
            String.replace photo.url "" tweetText


removeQuotedTweetUrl : Maybe QuotedTweet -> List UrlRecord -> String -> String
removeQuotedTweetUrl maybeQuoted urls tweetText =
    case maybeQuoted of
        Nothing ->
            tweetText

        Just _ ->
            let
                lastUrl =
                    List.Extra.last urls
                        |> Maybe.map .display_url
                        |> Maybe.withDefault ""
            in
            String.replace lastUrl "" tweetText


mediaView : Tweet -> Html Msg
mediaView tweet =
    tweet.entities.media
        |> List.map
            (\media ->
                case media of
                    VideoMedia videoMedia ->
                        videoView videoMedia

                    MultiPhotoMedia multiPhoto ->
                        multiPhotoView multiPhoto
            )
        |> div []


videoView : Video -> Html Msg
videoView videoMedia =
    a
        [ href <| "https://" ++ videoMedia.display_url
        , target "_blank"
        ]
        [ video
            [ src videoMedia.media_url
            , autoplay True
            , loop True
            , muted True
            , class "Tweet-media-video"
            ]
            []
        ]


muted : Bool -> Html.Attribute Msg
muted v =
    property "muted" <| Json.Encode.bool v


multiPhotoView : MultiPhoto -> Html Msg
multiPhotoView multiPhoto =
    multiPhoto.media_url_list
        |> List.map
            (\imgUrl ->
                a
                    [ href <| "https://" ++ multiPhoto.display_url
                    , target "_blank"
                    ]
                    [ img
                        [ src imgUrl
                        , class "Tweet-media-photo"
                        ]
                        []
                    ]
            )
        |> div []
