{-# LANGUAGE RecursiveDo, NoMonomorphismRestriction #-}

module Main where

import Control.Applicative
import Control.Monad
import Data.IORef
import Data.List
import Data.Maybe
import FRP.Elerea.Experimental
import Graphics.UI.GLFW as GLFW
import Graphics.Rendering.OpenGL

import Event
import Math
import Util
import Vector

frameThickness = 0.05

ballSize = 0.05

ballFade = 2

data Ball = Ball { ballPos :: Vec
                 , ballCol :: Maybe GLfloat
                 , ballDrag :: Bool
                 }

bounceDemo mousePos mousePress = mdo
  leftPress <- memo $ fst <$> mousePress
  rightPress <- memo $ snd <$> mousePress

  (killDrag,killNow) <- dragRectangle mousePos rightPress
  killRect <- (vnull,vnull) --> killDrag
  let within (V tlx tly,V brx bry) (V x y) = x > min tlx brx && x < max tlx brx &&
                                             y > min tly bry && y < max tly bry

  ballList <- collectE newBallE $ \bs -> killNow &&@ (within <$> killRect <*> (ballPos <$> bs))
  ballData <- memo $ sequence =<< ballList
  newBallCond <- edge $ leftPress &&@ (all (not.ballDrag) <$> ballData)
  newBallE <- generator $ newBall <$> mousePos <*> newBallCond
  let newBall pos cond = if cond
                         then Just <$> ball pos mousePos leftPress
                         else return Nothing

  return $ render <$> ballData <*> killDrag

flipflop te fe = False --> leftE (ifE te (pure True)) (ifE fe (pure False))

dragRectangle mousePos mousePress = do
  dragBegin <- edge mousePress
  dragEnd <- edge (not <$> mousePress)
  drag <- flipflop dragBegin dragEnd
  topLeft <- vnull --> ifE dragBegin mousePos
  return (ifE drag ((,) <$> topLeft <*> mousePos), dragEnd)

ball initPos mousePos mousePress = mdo
  mouseDown <- edge mousePress
  let dragBegin = mouseDown &&@ (vlen (pos^-^mousePos) <@ ballSize/2)
  dragEnd <- edge (not <$> mousePress)
  drag <- flipflop dragBegin dragEnd
  dragVel <- derivTV 0.05 mousePos
  
  let collHorz (V vx _) (V px _) = collFrame vx px
      collVert (V _ vy) (V _ py) = collFrame vy py
      collFrame v p = abs (p-0.5) > 0.5-(frameThickness+ballSize/2) && (p-0.5)*v > 0
  pos <- integralV initPos vel
  vel <- vnull --> velE
  velE <- memo $ mergeE [ifE drag dragVel,
                         ifE (collHorz <$> vel <*> pos) (mul (V (-1) 1) <$> vel),
                         ifE (collVert <$> vel <*> pos) (mul (V 1 (-1)) <$> vel)]

  colour <- ballColour (isJust <$> velE)

  return $ Ball <$> pos <*> colour <*> drag

ballColour hit = transfer Nothing update hit
  where update dt True  _    = Just 1
        update dt False prev = do t <- prev
                                  guard (t > 0)
                                  return (t-dt*ballFade)

driveNetwork network driver = do
  dt <- driver
  case dt of
    Just dt -> do join $ network dt
                  driveNetwork network driver
    Nothing -> return ()

main = do
  initialize
  openWindow (Size 640 480) [DisplayRGBBits 8 8 8, DisplayAlphaBits 8, DisplayDepthBits 24] Window
  windowTitle $= "Elerea Bounce"

  (mousePosition,mousePositionSink) <- external vnull
  (mousePress,mousePressSink) <- external (False,False)

  closed <- newIORef False
  windowSizeCallback $= resizeGLScene
  windowCloseCallback $= writeIORef closed True
  initGL 640 480

  demo <- start $ bounceDemo mousePosition mousePress
  time $= 0
  driveNetwork demo (readInput mousePositionSink mousePressSink closed)

  closeWindow

initGL width height = do
  clearColor $= Color4 0 0 0 1
  blend $= Enabled
  blendFunc $= (SrcAlpha,OneMinusSrcAlpha)

resizeGLScene size@(Size w h) = do
  let r = 2*fromIntegral w/fromIntegral h
      r' = 2*fromIntegral h/fromIntegral w

  viewport $= (Position 0 0,size)

  matrixMode $= Projection
  loadIdentity
  scale (min 2 r') (min 2 r) (1 :: GLfloat)
  translate $ Vector3 (-0.5) (-0.5) (0 :: GLfloat)
	
  matrixMode $= Modelview 0

render bs rect = do
  let drawRectangle x y sx sy = do
        renderPrimitive Quads $ do
          vertex $ Vertex3 (x)    (y)    (0 :: GLfloat)
          vertex $ Vertex3 (x+sx) (y)    (0 :: GLfloat)
          vertex $ Vertex3 (x+sx) (y+sy) (0 :: GLfloat)
          vertex $ Vertex3 (x)    (y+sy) (0 :: GLfloat)
      drawEllipse xc yc xs ys n = do
        renderPrimitive TriangleStrip $ forM_ [0..n] $ \i -> do
          let a = 2*pi*fromIntegral i/fromIntegral n
          vertex $ Vertex3 (xc+xs/2*sin a) (yc+ys/2*cos a) (0 :: GLfloat)
          vertex $ Vertex3 xc yc (0 :: GLfloat)

  clear [ColorBuffer]
  loadIdentity
  
  color $ Color4 0.7 0.7 0.7 (1 :: GLfloat)
  drawRectangle 0 0 1 frameThickness
  drawRectangle 0 (1-frameThickness) 1 frameThickness
  drawRectangle 0 0 frameThickness 1
  drawRectangle (1-frameThickness) 0 frameThickness 1
  
  forM_ bs $ \b -> do
    case ballCol b of
      Nothing -> color $ Color4 0 0 0.7 (1 :: GLfloat)
      Just t -> color $ Color4 (0.9*t) (0.9*t) (0.7*(1-t)) (1 :: GLfloat)

    let V x y = ballPos b
    drawEllipse x y ballSize ballSize 20

  case rect of
    Nothing -> return ()
    Just (V tlx tly,V brx bry) -> do
      color $ Color4 1 0 0 (0.4 :: GLfloat)
      drawRectangle tlx tly (brx-tlx) (bry-tly)

  flush
  swapBuffers

readInput mousePos mouseBut closed = do
  t <- get time
  time $= 0
  
  Position x y <- get GLFW.mousePos
  Size w h <- get windowSize
  let x' = fromIntegral x
      y' = fromIntegral y
      w' = fromIntegral w
      h' = fromIntegral h
      mx = (x'-max 0 (w'-h')/2)/min w' h'
      my = (y'-max 0 (h'-w')/2)/min w' h'
  mousePos (V mx (1-my))
  
  bl <- getMouseButton ButtonLeft
  br <- getMouseButton ButtonRight
  mouseBut (bl == Press, br == Press)
  k <- getKey ESC
  c <- readIORef closed

  return (if c || k == Press then Nothing else Just (realToFrac t))