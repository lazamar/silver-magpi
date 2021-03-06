module Twitter.Decoders.TweetDecoder exposing
    ( hashtagDecoder
    , tweetDecoder
    , urlDecoder
    , userMentionsDecoder
    )

import Generic.Utils
import Json.Decode as Decode
    exposing
        ( Decoder
        , andThen
        , at
        , bool
        , dict
        , fail
        , field
        , int
        , list
        , nullable
        , oneOf
        , string
        )
import Json.Decode.Extra
    exposing
        ( custom
        , hardcoded
        , optional
        , required
        , requiredAt
        )
import List.Extra
import Time exposing (Posix)
import Twitter.Decoders.UserDecoder exposing (userDecoder)
import Twitter.Types
    exposing
        ( HashtagRecord
        , MediaRecord(..)
        , MultiPhoto
        , QuotedTweet(..)
        , Retweet(..)
        , Tweet
        , TweetEntitiesRecord
        , UrlRecord
        , User
        , UserMentionsRecord
        , Video
        )



-- Types
-- Raw as in not preprocessed. It is just like the server sent


type alias RawTweet =
    { id : String
    , user : User
    , created_at : Posix
    , text : String
    , retweet_count : Int
    , favorite_count : Int
    , favorited : Bool
    , retweeted : Bool
    , in_reply_to_status_id : Maybe String
    , entities : RawTweetEntitiesRecord
    , extended_entities : ExtendedEntitiesRecord
    , retweeted_status : Maybe Retweet
    , quoted_status : Maybe QuotedTweet
    }


type alias RawTweetEntitiesRecord =
    { hashtags : List HashtagRecord
    , urls : List UrlRecord
    , user_mentions : List UserMentionsRecord
    , media : List RawMediaRecord
    }


type alias RawMediaRecord =
    { url : String
    , display_url : String
    , media_url_https : String
    }



-- EXTENDED RECORDS


type alias ExtendedEntitiesRecord =
    { media : List ExtendedMedia
    }


type ExtendedMedia
    = ExtendedPhotoMedia ExtendedPhoto
    | ExtendedVideoMedia ExtendedVideo


type alias ExtendedPhoto =
    { url :
        String

    -- what is in the tweet
    , display_url :
        String

    -- what should be shown in the tweet
    , media_url_https :
        String

    -- the actuall address of the content
    }


type alias ExtendedVideo =
    { url : String
    , display_url : String
    , variants : List VariantRecord
    }


type alias VariantRecord =
    { content_type : String
    , url : String
    }



-- DECODERS


tweetDecoder : Decoder Tweet
tweetDecoder =
    rawTweetDecoder
        |> Decode.map preprocessTweet


rawTweetDecoder : Decoder RawTweet
rawTweetDecoder =
    rawTweetDecoderFirstPart
        |> optional "retweeted_status" (nullable retweetDecoder) Nothing
        |> optional "quoted_status" (nullable quotedTweetDecoder) Nothing


retweetDecoder : Decoder Retweet
retweetDecoder =
    shallowRawTweetDecoder
        |> Decode.map preprocessTweet
        |> Decode.map Retweet


quotedTweetDecoder : Decoder QuotedTweet
quotedTweetDecoder =
    shallowRawTweetDecoder
        |> Decode.map preprocessTweet
        |> Decode.map QuotedTweet



-- Decodes a Tweet ignoring it's recursive part.


shallowRawTweetDecoder : Decoder RawTweet
shallowRawTweetDecoder =
    rawTweetDecoderFirstPart
        |> hardcoded Nothing
        -- retweeted_status
        |> hardcoded Nothing



-- quoted_status
-- Elm has problems parsing recursive JSON values, so
-- in this function we only parse the first part of
-- RawTweet and leave the recursive part to be implemented
-- according to whether we are parsing the top tweet or the retweet or quoted_status
-- and thus prevent parsing recursion


rawTweetDecoderFirstPart =
    Decode.succeed RawTweet
        |> required "id_str" string
        |> required "user" userDecoder
        |> required "created_at" Generic.Utils.dateDecoder
        |> custom
            (oneOf
                -- TODO: Remove "text". This is only here whilst
                -- we do the server transition from "text" to "full_text" so
                -- that we see the full 280 characters
                [ at [ "full_text" ] string
                , at [ "text" ] string
                ]
            )
        |> required "retweet_count" int
        |> required "favorite_count" int
        |> required "favorited" bool
        |> required "retweeted" bool
        |> optional "in_reply_to_status_id_str" (nullable string) Nothing
        |> required "entities" rawTweetEntitiesDecoder
        |> optional "extended_entities" extendedEntitiesDecoder (ExtendedEntitiesRecord [])


rawTweetEntitiesDecoder : Decoder RawTweetEntitiesRecord
rawTweetEntitiesDecoder =
    Decode.succeed RawTweetEntitiesRecord
        |> required "hashtags" (list hashtagDecoder)
        |> required "urls" (list urlDecoder)
        |> required "user_mentions" (list userMentionsDecoder)
        |> optional "media" (list rawMediaRecordDecoder) []


userMentionsDecoder : Decoder UserMentionsRecord
userMentionsDecoder =
    Decode.succeed UserMentionsRecord
        |> required "screen_name" string


rawMediaRecordDecoder : Decoder RawMediaRecord
rawMediaRecordDecoder =
    Decode.succeed RawMediaRecord
        |> required "url" string
        -- this is the url contained in the tweet
        |> required "display_url" string
        -- this is the url contained in the tweet
        |> required "media_url_https" string


hashtagDecoder : Decoder HashtagRecord
hashtagDecoder =
    Decode.succeed HashtagRecord
        |> required "text" string


urlDecoder : Decoder UrlRecord
urlDecoder =
    Decode.succeed UrlRecord
        |> required "display_url" string
        |> required "url" string


extendedEntitiesDecoder : Decoder ExtendedEntitiesRecord
extendedEntitiesDecoder =
    Decode.succeed ExtendedEntitiesRecord
        |> optional "media" (list extendedMediaDecoder) []


extendedMediaDecoder : Decoder ExtendedMedia
extendedMediaDecoder =
    field "type" string
        |> andThen
            (\mtype ->
                if mtype == "video" || mtype == "animated_gif" then
                    extendedVideoRecordDecoder
                        |> andThen (\x -> Decode.succeed (ExtendedVideoMedia x))

                else if mtype == "photo" then
                    extendedPhotoRecordDecoder
                        |> andThen (\x -> Decode.succeed (ExtendedPhotoMedia x))
                    -- TODO: Multi-photo parse

                else
                    -- FIXME: This mustbe an appropriate
                    -- parser for an undefined option
                    fail (mtype ++ " is not a recognised type.")
            )


extendedPhotoRecordDecoder : Decoder ExtendedPhoto
extendedPhotoRecordDecoder =
    Decode.succeed ExtendedPhoto
        |> required "url" string
        |> required "display_url" string
        |> required "media_url_https" string


extendedVideoRecordDecoder : Decoder ExtendedVideo
extendedVideoRecordDecoder =
    Decode.succeed ExtendedVideo
        |> required "url" string
        |> required "display_url" string
        |> requiredAt [ "video_info", "variants" ] (list variantRecordDecoder)


variantRecordDecoder : Decoder VariantRecord
variantRecordDecoder =
    Decode.succeed VariantRecord
        |> required "content_type" string
        |> required "url" string



-- PROCESSING


preprocessTweet : RawTweet -> Tweet
preprocessTweet raw =
    Tweet
        raw.id
        raw.user
        raw.created_at
        raw.text
        raw.retweet_count
        raw.favorite_count
        raw.favorited
        raw.retweeted
        raw.in_reply_to_status_id
        (TweetEntitiesRecord
            raw.entities.hashtags
            (mergeMediaLists raw.extended_entities.media raw.entities.media)
            raw.entities.urls
            raw.entities.user_mentions
        )
        raw.retweeted_status
        raw.quoted_status



-- FIXME: It is currently ignoring the raw media


mergeMediaLists : List ExtendedMedia -> List RawMediaRecord -> List MediaRecord
mergeMediaLists extendedMedia media =
    let
        photos =
            getPhotos extendedMedia

        videos =
            getVideos extendedMedia
    in
    List.concat [ photos, videos ]


getPhotos : List ExtendedMedia -> List MediaRecord
getPhotos extendedMedia =
    extendedMedia
        |> List.filterMap toExtendedPhoto
        |> groupByUrl
        |> List.filterMap
            (\group ->
                List.foldr
                    (\extendedPhoto maybeMediaType ->
                        Just <|
                            case maybeMediaType of
                                Nothing ->
                                    MultiPhoto
                                        extendedPhoto.url
                                        extendedPhoto.display_url
                                        [ extendedPhoto.media_url_https ]

                                Just mediaType ->
                                    { mediaType
                                        | media_url_list =
                                            extendedPhoto.media_url_https :: mediaType.media_url_list
                                    }
                    )
                    Nothing
                    group
            )
        |> List.map MultiPhotoMedia


toExtendedPhoto : ExtendedMedia -> Maybe ExtendedPhoto
toExtendedPhoto extendedMedia =
    case extendedMedia of
        ExtendedPhotoMedia extendedPhoto ->
            Just extendedPhoto

        otherwise ->
            Nothing


groupByUrl : List ExtendedPhoto -> List (List ExtendedPhoto)
groupByUrl mediaList =
    mediaList
        |> (\b a -> List.foldr a b) []
            (\m uniqueUrls ->
                if List.member m.url uniqueUrls then
                    uniqueUrls

                else
                    m.url :: uniqueUrls
            )
        |> List.map
            (\url ->
                List.filter (\mediaItem -> mediaItem.url == url) mediaList
            )


getVideos : List ExtendedMedia -> List MediaRecord
getVideos extendedMedia =
    extendedMedia
        |> List.filterMap toExtendedVideo
        |> List.map extendedVideoToVideo
        |> List.map VideoMedia


toExtendedVideo : ExtendedMedia -> Maybe ExtendedVideo
toExtendedVideo extendedMedia =
    case extendedMedia of
        ExtendedVideoMedia extendedPhoto ->
            Just extendedPhoto

        otherwise ->
            Nothing


extendedVideoToVideo : ExtendedVideo -> Video
extendedVideoToVideo extendedVideo =
    let
        mp4Variant =
            List.Extra.find (\v -> v.content_type == "video/mp4") extendedVideo.variants

        videoVariant =
            case mp4Variant of
                Nothing ->
                    List.head extendedVideo.variants
                        |> Maybe.withDefault (VariantRecord "nothingHere" "nothingHere")

                Just variant ->
                    variant
    in
    Video
        extendedVideo.url
        extendedVideo.display_url
        videoVariant.url
        videoVariant.content_type
