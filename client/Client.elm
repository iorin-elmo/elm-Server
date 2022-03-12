port module Client exposing (main)
import Browser
import Html exposing (Html, text, div, button, br)
import Html.Attributes as Attr
import Html.Events exposing (onClick, onInput)
import Http
import Time exposing (Posix)

port changeTitle : String -> Cmd msg

type alias Model =
  { logs : List String
  , editingText : String
  , name : String
  , host : String
  }

init : String -> (Model, Cmd Msg)
init host =
  ( Model [] "" "" host
  , Cmd.batch
      [ Http.get
        { url = "http://" ++ host ++ "/get"
        , expect = Http.expectString GetChatLogs
        }
      , changeTitle "Loading..."
      ]
  )
    |> Debug.log "init"

type Msg
  = GetChatLogs (Result Http.Error String)
  | InputText String
  | InputName String
  | Post
  | Posted (Result Http.Error ())
  | Tick Posix

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetChatLogs result ->
      case result |> Debug.log "status : " of
        Ok str ->
          let
            newLogs =
              String.split "\\n" str
          in
            ( { model
              | logs = newLogs
              }
            , changeTitle "Elm-Twitter"
            )
        Err _ ->
          ( model
          , changeTitle "Error!"
          )
    InputText str ->
      ( { model | editingText = str }
      , Cmd.none
      )
    InputName str ->
      ( { model | name = str }
      , Cmd.none
      )
    Post ->
      ( model
      , Http.post
          { url = "http://" ++ model.host ++ "/post"
          , expect = Http.expectWhatever Posted
          , body =
              model.name ++ "|" ++ model.editingText
                |> Http.stringBody "text/plain"
          }
      )
    Posted result ->
      case result of
        Ok _ ->
          ( { model | editingText = "" }
          , Cmd.none
          )
        Err _ ->
          ( { model | editingText = "" }
          , Cmd.none
          )

    Tick _ ->
      ( model
      , Cmd.batch
          [ Http.get
              { url = "http://" ++ model.host ++ "/get"
              , expect = Http.expectString GetChatLogs
              }
          , changeTitle "Loading..."
          ]
      )


view : Model -> Html Msg
view model =
  div []
    [ Html.textarea [onInput InputName][]
    , br [][]
    , model.logs
        |> List.map (\str -> Html.li [][ text str ])
        |> Html.ul []
    , br [][]
    , Html.textarea
        [ onInput InputText
        , Attr.value model.editingText
        ]
        []
    , button [ onClick Post ][ text "Post"]
    ]


main =
  Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions =
        \_ -> Time.every 1000 Tick
    }
