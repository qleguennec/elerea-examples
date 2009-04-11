Utils module
============

This module contains some functions that might make it into the core library eventually.

> module Common.Utils where
>
> import Control.Applicative
> import Control.Monad
> import FRP.Elerea
>
> import Common.Vector

The `driveNetwork` function simply executes the supersteps while the
`driver` function keeps returning valid delta time values.

> driveNetwork network driver = do
>   dt <- driver
>   case dt of
>     Just dt -> do join $ superstep network dt
>                   driveNetwork network driver
>     Nothing -> return ()

The `delay` transfer function emits the value of a signal from the
previous superstep, starting with the filler value `v0`.

> delay v0 s = snd <$> transfer (v0,undefined) (\_ v' (v,_) -> (v',v)) s

The `edge` transfer function takes a bool signal and emits another
bool signal that turns true only at the moment when there is a rising
edge on the input.

> edge b = (not <$> delay True b) &&@ b

A scalar integral function.  Since it is based on `transfer`, it is
delayed by one superstep, i.e. the value of the input signal in the
n<sup>th</sup> step affects its output only in the (n+1)<sup>th</sup>
step.

> integral v0 s = transfer v0 (\dt v v0 -> v0+v*realToFrac dt) s

An integral function for two-dimensional vectors defined in the
`Vector` module with the same caveat.

> integralVec v0 s = transfer v0 (\dt v v0 -> v0^+^(v^*.realToFrac dt)) s

Logic relations lifted into signals.  Useful to combine event-like
signals.

> (||@) :: Signal Bool -> Signal Bool -> Signal Bool
> (||@) = liftA2 (||)
> 
> (&&@) :: Signal Bool -> Signal Bool -> Signal Bool
> (&&@) = liftA2 (&&)
