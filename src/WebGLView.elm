module WebGLView exposing (render)

import Html exposing (Html)
import Html.Attributes exposing (width, height, style)
import WebGL as GL
import Math.Vector2 exposing (Vec2, vec2, fromTuple)
import Box
import Textures exposing (Textures)
import AllDict exposing (AllDict)
import Actions exposing (Action)


type alias Vertex =
  { position : Vec2 }


type alias Uniform =
  { frameSize : Vec2
  , screenSize : Vec2
  , offset : Vec2
  , texture : GL.Texture
  , textureSize : Vec2
  , frame : Int
  , layer : Float
  }


type alias Varying =
  { texturePos : Vec2 }


mesh : GL.Drawable Vertex
mesh =
  GL.Triangle
    [ ( Vertex (vec2 0 0)
      , Vertex (vec2 1 1)
      , Vertex (vec2 1 0)
      )
    , ( Vertex (vec2 0 0)
      , Vertex (vec2 0 1)
      , Vertex (vec2 1 1)
      )
    ]


render : Float -> (Int, Int) -> Int -> Textures -> List Box.TexturedBoxData -> Html Action
render devicePixelRatio ((w, h) as dimensions) tileSize textures boxes =
  GL.toHtmlWith
    [ GL.Enable GL.DepthTest
    ]
    [ width (toFloat w * toFloat tileSize * devicePixelRatio |> round)
    , height (toFloat h * toFloat tileSize * devicePixelRatio |> round)
    , style
        [ ("position", "absolute")
        , ("-webkit-transform-origin", "0 0")
        , ("-webkit-transform", "scale(" ++ toString (1 / devicePixelRatio) ++ ")")
        , ("transform-origin", "0 0")
        , ("transform", "scale(" ++ toString (1 / devicePixelRatio) ++ ")")
        ]
    ]
    (List.filterMap (renderTextured dimensions textures) (List.reverse boxes))


renderTextured : (Int, Int) -> Textures -> Box.TexturedBoxData -> Maybe GL.Renderable
renderTextured (w, h) textures {textureId, position, frame, offset, layer} =
  AllDict.get textureId textures
  `Maybe.andThen`
  (\{size, texture} ->
    Maybe.map
      (\textureValue ->
        GL.render
          vertexShader
          fragmentShader
          mesh
          { screenSize = vec2 (toFloat w) (toFloat h)
          , offset = vec2 (fst offset + fst position) (snd offset + snd position)
          , layer = layer
          , texture = textureValue.texture
          , frame = frame
          , textureSize = fromTuple textureValue.size
          , frameSize = fromTuple size
          }
      )
    texture
  )


vertexShader : GL.Shader Vertex Uniform Varying
vertexShader = [glsl|

  precision mediump float;
  attribute vec2 position;
  uniform vec2 offset;
  uniform float layer;
  uniform vec2 frameSize;
  uniform vec2 screenSize;
  varying vec2 texturePos;

  void main () {
    vec2 clipSpace = (position * frameSize + offset) / screenSize * 2.0 - 1.0;
    gl_Position = vec4(clipSpace.x, -clipSpace.y, -layer / 10000.0, 1);
    texturePos = position;
  }

|]


fragmentShader : GL.Shader {} Uniform Varying
fragmentShader = [glsl|

  precision mediump float;
  uniform sampler2D texture;
  uniform vec2 textureSize;
  uniform vec2 frameSize;
  uniform int frame;
  varying vec2 texturePos;

  void main () {
    vec2 size = frameSize / textureSize * 80.0;
    int cols = int(1.0 / size.x);
    vec2 frameOffset = size * vec2(float(frame - frame / cols * cols), -float(frame / cols));
    vec2 textureClipSpace = size * texturePos - 1.0;
    gl_FragColor = texture2D(texture, vec2(textureClipSpace.x, -textureClipSpace.y) + frameOffset);
    if (gl_FragColor.a == 0.0) discard;
  }

|]
