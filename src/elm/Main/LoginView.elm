module Main.LoginView exposing (root)

import Generic.Animations
import Generic.Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Main.Types exposing (..)
import RemoteData exposing (RemoteData)


root : Model -> Html Msg
root model =
    div [ class "Login" ]
        [ div
            [ class "Login-title" ]
            [ img
                [ class "Login-title-letters"
                , src "../images/silver.svg"
                ]
                []
            , img
                [ class "Login-title-letters"
                , src "../images/magpie.svg"
                ]
                []
            , img
                [ class "Login-title-letters"
                , src "../images/silver.svg"
                ]
                []
            , img
                [ class "Login-title-letters"
                , src "../images/magpie.svg"
                ]
                []
            ]
        , div
            [ class "Login-content" ]
            [ img
                [ src "../images/logo.png"
                , class "Login-logo"
                ]
                []
            , loginContent model
            ]
        , div
            [ class "Login-footer" ]
            [ p []
                [ text "Created with "
                , i [ class "zmdi zmdi-favorite Login-footer-heartIcon" ] []
                , text " by "
                , a
                    [ href "http://lazamar.github.io"
                    , target "blank"
                    ]
                    [ text "Marcelo Lazaroni" ]
                ]
            , p []
                [ text "Poetically written in "
                , a
                    [ href "http://elm-lang.org"
                    , target "blank"
                    ]
                    [ text "Elm" ]
                ]
            ]
        ]


loginContent : Model -> Html Msg
loginContent model =
    let
        stuck =
            p [ class "Loading-content-info" ]
                [ text "Uh, I'm stuck. Something went wrong." ]
    in
    case Debug.log "Current session id:" model.sessionID of
        Nothing ->
            stuck

        Just session ->
            case session of
                AuthenticationFailed sessionID error ->
                    case error of
                        Http.BadStatus { status } ->
                            if status.code == 401 then
                                a
                                    [ onClick SignIn
                                    , class "Login-signinBtn"
                                    ]
                                    [ text "Sign in with Twitter "
                                    ]

                            else
                                p [ class "Loading-content-info" ]
                                    [ text "There was an error loading your credential. Please retry." ]

                        -- TODO: Handle other HTTP errors properly
                        _ ->
                            p [ class "Loading-content-info" ]
                                [ text "There was an error loading your credential. Please retry." ]

                Authenticating _ ->
                    Generic.Animations.twistingCircle

                Authenticated _ _ ->
                    p [ class "Loading-content-info" ]
                        [ text "You are logged in." ]

                NotAttempted _ ->
                    stuck
