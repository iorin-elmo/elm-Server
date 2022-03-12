port module Server exposing (main)

import Platform
import Json.Encode as Json
import Json.Decode as Decode
import Dict exposing (Dict)
import Debug

type alias Model =
  { chatLog : List ( String, String )
  , host : String
  }

main =
  Platform.worker
    { init = init
    , update = update
    , subscriptions = subscriptions
    }

type alias Request =
  { method : String
  , headers : Json.Value
  , url : String
  , body : Maybe String
  }

type alias Response =
  { statusCode : Int
  , statusMessage : String
  , headers : Json.Value
  , body : String
  }



-- MODEL --

init : String -> ( Model, Cmd Msg )
init host =
  ( Model [] host
  , Cmd.none )



-- UPDATE --

type Msg
  = HttpRequest ( Json.Value, Id )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    HttpRequest ( reqJson, id ) ->
      case reqJson |> Decode.decodeValue requestDecoder of
        Ok req ->
          case req.method of
            "GET" ->
              ( model
              , response ( chatResponse model.chatLog, id )
              )

            "POST" ->
              case req.body |> Debug.log "body" of
                Just str ->
                  case String.split "|" str of
                    name::content ->
                      let
                        newModel =
                          { model
                          | chatLog =
                              model.chatLog ++ [(name, String.concat content)]
                          }
                        postResponse =
                          response ( Response 200 "OK" mimeStringUtf8 "", id )
                      in
                        ( newModel
                        , postResponse
                        )

                    _ ->
                      ( model
                      , response ( errorResponse 400 "Bad Request", id )
                      )
                        |> Debug.log "1"
                _ ->
                  ( model
                  , response ( errorResponse 400 "Bad Request", id )
                  )
                  |> Debug.log "2"
            _ ->
              ( model
              , response ( errorResponse 400 "Bad Request", id )
              )
              |> Debug.log "3"

        Err _ ->
          ( model
          , response ( errorResponse 400 "Bad Request", id )
          )

requestDecoder : Decode.Decoder Request
requestDecoder =
  Decode.map4
  Request
  (Decode.field "method" Decode.string)
  (Decode.field "headers" Decode.value)
  (Decode.field "url" Decode.string)
  (Decode.field "body" Decode.string |> Decode.maybe)

errorResponse : Int -> String -> Response
errorResponse statusCode reason =
  Response statusCode reason
  mimeHtmlUtf8
  (String.fromInt statusCode ++ " " ++ reason)

mimeHtmlUtf8 : Json.Value
mimeHtmlUtf8 =
  ( "Content-Type", Json.string "text/html; charset=UTF-8" )
    |> List.singleton
    |> Json.object

mimeStringUtf8 : Json.Value
mimeStringUtf8 =
  [ ("Content-Type", Json.string "text/plane; charset=UTF-8")
  , ("Access-Control-Allow-Origin", Json.string "*")
  , ("Access-Control-Allow-Credentials", Json.bool True)
  ]
    |> Json.object

chatResponse : List (String, String) -> Response
chatResponse logs =
  let
    logStr =
      logs
        |> List.map
          (\(name, content) -> name ++ " : " ++ content )
        |> String.join "\\n"
  in
    Response 200 "OK" mimeStringUtf8 logStr


-- SUBSCRIPTIONS --

subscriptions : Model -> Sub Msg
subscriptions _ =
  request HttpRequest



-- PORTS --

type alias Id = Int

port request : (( Json.Value, Id ) -> msg) -> Sub msg
port response : ( Response, Id ) -> Cmd msg