module Routes.Timelines.Timeline.State exposing ( init, update, refreshTweets )

import Routes.Timelines.Timeline.Rest exposing ( getTweets, favoriteTweet, doRetweet )
import Routes.Timelines.Timeline.Types exposing (..)
import Twitter.Types exposing ( Tweet, Retweet, Credentials )
import Generic.Types exposing (never)
import Generic.Utils exposing (toCmd)
import Main.Types
import RemoteData exposing (..)
import Task
import Http
import Process


-- MAIN FUNCTIONS



initialModel : Credentials -> Model
initialModel credentials =
    { credentials = credentials
    , tab = HomeRoute
    , tweets = []
    , newTweets = Loading
    }



init : Credentials -> ( Model, Cmd Msg, Cmd Broadcast )
init credentials =
    ( initialModel credentials
    , toCmd (FetchTweets Refresh)
    , Cmd.none
    )



-- UPDATE



update : Msg -> Model -> ( Model, Cmd Msg, Cmd Broadcast )
update msg model =
    case msg of
        DoNothing ->
            ( model, Cmd.none, Cmd.none )

        FetchTweets tweetsPosition ->
            ( { model | newTweets = Loading }
            , getTweets model.credentials tweetsPosition model.tab
            , Cmd.none
            )

        TweetFetch tweetsPosition request ->
            case request of
                Success newTweets ->
                    ( { model
                        | tweets = combineTweets tweetsPosition newTweets model.tweets
                        , newTweets = NotAsked
                        }
                    , Cmd.none
                    , Cmd.none
                    )

                Failure error ->
                    ( { model | newTweets = request }
                    , Cmd.none
                    , Cmd.none
                    -- , resetTweetFetch tweetsPosition 3000
                    )

                _ ->
                    ( { model | newTweets = request }
                    , Cmd.none
                    , Cmd.none
                    )

        ChangeRoute route ->
            ( { model | tab = route }
            , Cmd.none
            , Cmd.none
            )

        Favorite shouldFavorite tweetId ->
            ( { model
              | tweets = registerFavorite shouldFavorite tweetId model.tweets
              }
            , favoriteTweet model.credentials shouldFavorite tweetId
            , Cmd.none
            )

        DoRetweet shouldRetweet tweetId ->
            ( { model
              | tweets = registerRetweet shouldRetweet tweetId model.tweets
              }
            , doRetweet model.credentials shouldRetweet tweetId
            , Cmd.none
            )


registerFavorite : Bool -> String -> List Tweet -> List Tweet
registerFavorite toFavorite tweetId tweetList =
    let
        tweetUpdate tweet =
            if tweet.id == tweetId && xor tweet.favorited toFavorite then
                { tweet
                | favorite_count = tweet.favorite_count + if toFavorite then 1 else -1
                , favorited = toFavorite
                }
            else
                tweet
    in
        List.map (applyToRelevantTweet tweetUpdate) tweetList



registerRetweet : Bool -> String -> List Tweet -> List Tweet
registerRetweet shouldRetweet tweetId tweetList =
    let
        tweetUpdate tweet =
            if tweet.id == tweetId && xor tweet.retweeted shouldRetweet then
                { tweet
                | retweet_count = tweet.retweet_count + if shouldRetweet then 1 else -1
                , retweeted = shouldRetweet
                }
            else
                tweet
    in
        List.map (applyToRelevantTweet tweetUpdate) tweetList



-- Applies a function on a tweet or, if it has a retweet in its retweet
applyToRelevantTweet : ( Tweet -> Tweet ) -> Tweet -> Tweet
applyToRelevantTweet func tweet =
    case tweet.retweeted_status of
        Nothing ->
            func tweet

        Just (Twitter.Types.Retweet rt) ->
            { tweet
            | retweeted_status =
                func rt
                    |> Twitter.Types.Retweet
                    |> Just
            }



combineTweets : FetchType -> (List Tweet) -> (List Tweet) -> (List Tweet)
combineTweets tweetsPosition newTweets oldTweets =
      case tweetsPosition of
          Refresh ->
              newTweets

          BottomTweets ->
              List.concat [ oldTweets, newTweets ]



resetTweetFetch : FetchType -> Float -> Cmd Msg
resetTweetFetch tweetsPosition time =
    Process.sleep time
        |> Task.perform never (\_ -> TweetFetch tweetsPosition NotAsked)



-- Public
refreshTweets : Model -> ( Model, Cmd Msg, Cmd Broadcast )
refreshTweets =
    update ( FetchTweets Refresh )
