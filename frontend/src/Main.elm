module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (href, placeholder, src, class, id)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, at, int, field, string)
import Json.Decode.Pipeline exposing (required, requiredAt, optional, optionalAt, hardcoded)


{--

Okay, so this is my app. It has all of the functionality for tiltr.

The CSS is handled by the custom-css file and Bootstrap. Most of it is in the
custom-css file, though.

I chose Elm for this because of the type safety and JSON handling. I knew when
I started learning it that it would be a bit steep, but the more I've learned
to use it, the better it's been for this.

Elm compiles to JS, so the compiled JS is linked to the page on tiltr.cc

The page itself has nearly zero HTML -- that's all built from the Elm I've
written below. Part of the reason for this is that the JSON data from Twitter's
API is consistent, but the payload differs on each request, and I want to handle
that robustly, with easy debugging and zero runtime exceptions.

When JSON comes into Elm, it's converted to a list of records. The basic post
structure is a function that's mapped over that list, in the view section.

It's been fun. Stressy, but fun.

Lilith out.

--}


{-- Type annotation for quick reference!
Browser.application :
  { init : flags -> Url -> Browser.Navigation.Key -> ( model, Cmd msg )
  , onUrlChange : Url -> msg
  , onUrlRequest : Browser.UrlRequest -> msg
  , subscriptions : model -> Sub msg
  , update : msg -> model -> ( model, Cmd msg )
  , view : model -> Browser.Document msg
  }
  () -> Program Flags Model Msg
  --}

-- MAIN


main : Program () Model Msg
main =
  Browser.application
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    , onUrlChange = UrlChanged
    , onUrlRequest = LinkClicked
    }



-- MODEL


type alias Model =
  { url : Url.Url
  , key : Nav.Key
  , searchString : String
  , searchResponseList : List TweetPost
  , artistbio : Artist
  }

{-- The model contains the list of JSON results and the main artist bio
information, like name, screen name, and image. --}

type alias TweetPost =
  { postid : String
  , twitterArtistScreenName : String
  , twitterArtistName : String
  , tweetImageUrl : String
  , tweetDescription : String
  , twitterArtist : Artist
  }

{-- Each result is pulled into Elm as a record, typed TweetPost. --}

type alias Artist =
  { screenName : String
  , name : String
  , description : String
  , profileImage : String
  }

{-- We can count on each post to have the above information. It's the only data
that we care about. If we start to need other data, we can update this. --}

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
  ( Model
    url
    key
    "@zweisan57"
    []
    initialbio
    , getTweets "bunny fanart" )

{-- Our intial model shows the results of a search for "bunny fanart" because
that's pretty nonthreatening and nice to see, in general. Who doesn't like
fanart of bunnies? --}

initialbio : Artist
initialbio =
    { name = "Welcome to tiltr!", screenName = "Search by hashtag, artist name, or topic", description = "If there are not results for your search, don't panic. Try a different search, and have fun!", profileImage = "" }

{-- This is the initial message users see when they access the site. --}




-- UPDATE

{-- The below handles the update messages that are generated by user events. --}


type Msg
  = LinkClicked Browser.UrlRequest
  | UrlChanged Url.Url
  | SearchEntered String
  | GotTweets (Result Http.Error (List TweetPost))
  | SearchButtonClicked
  | HashtagClicked String
  | ArtistClicked String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    LinkClicked urlRequest ->
      case urlRequest of
        Browser.Internal url ->
          ( model, Nav.pushUrl model.key (Url.toString url) )

        Browser.External href ->
          ( model, Nav.load href )

    UrlChanged url ->
      ( { model | url = url }
      , Cmd.none
      )

    SearchEntered search ->
          ( { model | searchString = search }
          , Cmd.none
          -- , Cmd.batch
          --   [
          --   -- Nav.pushUrl model.key (Url.toString model.url)
          --   -- ,
          --   -- getTweetsByArtist search
          --   ] We'll use this later.
          )

    SearchButtonClicked ->
      (
      case (String.startsWith "@" model.searchString) of -- model
        True ->
          model
        False ->
          { model | artistbio = initialbio }
      ,
      case (String.startsWith "@" model.searchString) of -- msg
         True ->
          getTweetsByArtist model.searchString
         False ->
          getTweets model.searchString
      )

    HashtagClicked hashtag ->
      (
        { model | searchString = hashtag }
        , getTweets hashtag
      )

    ArtistClicked artistname ->
      (
        { model | searchString = ("@" ++ artistname) } --backend expects an "a"
        , getTweetsByArtist artistname
      )

    GotTweets resultlist ->
      case {- debug.log -} resultlist of
        Ok great ->
          let
            updateModelBio : Model -> Artist
            updateModelBio modela =
              case (String.startsWith "@" modela.searchString) of
                True ->
--------
                  let
                    setArtistBio : List TweetPost -> Artist
                    setArtistBio thething =
                      case (List.take 1 thething) of
                        [] ->
                          model.artistbio
                        [aresult] ->
                          aresult.twitterArtist
                        _ ->
                          model.artistbio
                  in
                    setArtistBio great
--------
                False ->
                  initialbio
          in
            ( { model | searchResponseList = great
              , artistbio = updateModelBio model
              }
            , Cmd.none
            )

        Err _ ->
          ( model, Cmd.none)
          -- , Cmd.batch
          --   [ Nav.replaceUrl model.key "nooo"
          --   ]) Debug stuff; I'll need it later.


getTweetsByArtist : String -> Cmd Msg
getTweetsByArtist string =
  Http.get
    { url = (nodeserver ++ "tiltrartist/" ++ Url.percentEncode string)
    , expect = Http.expectJson GotTweets tweetJSONDecoderListByArtist
    }

getTweets : String -> Cmd Msg
getTweets string =
  Http.get
    { url = (nodeserver ++ "tiltrterm/" ++ Url.percentEncode string)
    , expect = Http.expectJson GotTweets tweetJSONDecoderList
    }

nodeserver : String
nodeserver =
  "https://tiltr.cc" --site/backend URL

tweetJSONDecoderListByArtist : Decoder (List TweetPost)
tweetJSONDecoderListByArtist =
  decodeTweetList -- I'll explain below!

tweetJSONDecoderList : Decoder (List TweetPost)
tweetJSONDecoderList =
  Decode.at ["statuses"] decodeTweetList

decodeTweetList : Decoder (List TweetPost) -- Return only good JSON
decodeTweetList =
    Decode.list (
      Decode.succeed TweetPost
        |> required "id_str" string
        |> requiredAt [ "user", "screen_name" ] string
        |> requiredAt [ "user", "name" ] string
        |> optionalAt [ "entities", "media" ] tweetEntitiesDecoder "NoMedia"
        |> required "text" string
        |> required "user" twitterArtistDecoder
        )

tweetEntitiesDecoder : Decoder String
tweetEntitiesDecoder =
  Decode.index 0 ( -- The medias object is always top-level, or, at index 0
    field "media_url" string
  )

twitterArtistDecoder : Decoder Artist
twitterArtistDecoder =
  Decode.succeed Artist
    |> required "screen_name" string
    |> required "name" string
    |> required "description" string
    |> required "profile_image_url" string




-- VIEW


view : Model -> Browser.Document Msg
view model =
  { title = "tiltr"
  , body =
      [ div [ id "app", class "container"]
         {-- text "The current URL is: "
        , b [] [ text (Url.toString model.url) ]

        I'm leaving this in for future development. --}
        [ nav [ id "topbar"]
          [ h1 [][text "tiltr"]
          , button
            [ id "top-search-button"
            , onClick SearchButtonClicked ]
              [ input
                [ onInput SearchEntered
                , id "top-search"
                , placeholder ("Type in a twitter search (like @artist, #hashtag) and hit enter!") ] []
              ]
          ]
        , article [ id "artist" ]
          (viewArtistSidebar model)
        , aside [ id "tagbar"]
          [ ul []
            [ li [] [ h4 [] [ text "Curated" ] ]
            , (viewLink "#crowley")
            , (viewLink "#watercolor")
            , (viewLink "#sunset")
            , (viewLink "#fanart")
            , (viewLink "#aggretsuko")
            ]
          ]
        , div [ id "center" ]
          [
          -- text model.searchString
          {- Debug.log "" -} viewTweetList model.searchResponseList
          ]
      ]
    ]
  }


viewArtistSidebar : Model -> List (Html Msg)
viewArtistSidebar model =
  case (String.startsWith "@" model.searchString) of
    True ->
      [ section [ class "artist-image" ]
          [ img [src (String.replace "normal" "400x400" model.artistbio.profileImage) ][] ]
        , section [ class "artist-description" ]
          [ h2 [] [ text model.artistbio.name ]
          , text "a.k.a"
          , h4 [] [ text ("@" ++ model.artistbio.screenName) ]
          , p [] [ text model.artistbio.description ]
          ]
      ]
    False ->
      [ section [ class "artist-image" ]
          [ img [src "" ][] ]
          , section [ class "artist-description" ]
            [ h3 [] [ text "Results Page" ]
            , h4 [] [ text "Many artists made these!" ]
            , p [] [ text "If you include the @ symbol in your search, you can show art by a specific artist. Otherwise, you'll see art by everyone. Enjoy!" ]
            ]
      ]

viewTweetList : List TweetPost -> (Html Msg)
viewTweetList tweetlist =
  div[]
  (List.map viewTweetPost tweetlist)


viewTweetPost : TweetPost -> (Html Msg)
viewTweetPost tweetpost =
    case tweetpost.tweetImageUrl of
      "NoMedia" ->
        div[][]
      _ ->
        section [ class "result-post col-sm" ]
        -- [ div [] [ text tweetpost.postid ]
        [ div [ class "splash" ]
          [ img [ src tweetpost.tweetImageUrl ][]]
        , div [ class "tweet-text" ]
          [ text tweetpost.tweetDescription ]
        , div [ class "username" ]
          [ ( text "artist: ")
          , a
            [ onClick ( ArtistClicked tweetpost.twitterArtistScreenName )
            , href tweetpost.twitterArtistScreenName ]
            [ text tweetpost.twitterArtistName ]
          ]
        ]


viewLink : String -> Html Msg
viewLink hashtag =
  li []
    [ a
      [ href hashtag
      , onClick
        ( Url.percentEncode hashtag -- A hash (#) isn't sendable to the backend
         |> HashtagClicked
         )
      ]
      [ text hashtag ]
    ]














-- SUBSCRIPTIONS
-- We don't use these

subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none
