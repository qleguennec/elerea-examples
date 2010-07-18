Example applications for Elerea. They are factored out into their own
package so as to avoid unnecessary dependencies in the library. Check
out the `doc` directory for the colourful literate sources.

The programs included are the following:

* bounce (current): an example for creating dynamic collections of
  signals with the experimental interface; left click to create
  balls, drag existing balls with left button to propel them and
  drag with right to select balls for deletion (upon release)

* chase (legacy): a minimal example that demonstrates reactivity and
  mutually recursive signals

* breakout (legacy): a not too fancy breakout clone that also
  demonstrates Graphviz output; you can get an SVG rendition of the
  signal structure with the following command if Graphviz is
  installed:

  `elerea-breakout --dump-dot | dot -Tsvg -o breakout.svg`

  You can simply use the mouse to move the paddle.
