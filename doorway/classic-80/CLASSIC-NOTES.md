# Classic four-room doorways — issue #80

## BEFORE
Builtin/palette styles without pets selected the hand-drawn `house-cutaway-*` PNGs
and `house-cutaway.json`: solid adjoining walls and a painted closed door into generic.

## AFTER
Classic four uses the flat composed module scene and the #59 doorway planner,
including its wall clipping, jambs and sill. The four open adjoining pairs are:
- bedroom–study
- bedroom–living
- living–generic
- study–living

Flat classic has no stairs. Classic-shaped layouts with explicit non-zero levels
continue through the existing composer with its three-step treatment for 48 px
differences. Hand-drawn assets remain an asset-missing fallback and tooling input.

No app launch or screenshots were performed in the sandbox. The operator must
capture before/after views and check small-scale readability outside the sandbox.

## Verification
Build passed. Full Swift tests: 343/344 passed; only the known sandbox
`storeMergesConflictCopies` Cocoa 512 failure remains. Scene-selection tests cover
builtin/palette styles, day/night, implicit/saved/explicit-flat classic cells,
all four planner openings and preservation of explicit split levels. The existing
pixel-detail test now also covers the auto-level `classic-composer` fixture.

An exploratory pixel probe requiring every jamb/sill sample to remain visible in
flat classic did not find the far bedroom–study jamb and sill at the sampled
positions. This stronger assertion is not used for flat classic: the unchanged
composer paints foreground rooms over rear detail. Operator visual acceptance
must specifically check that rear passage's readability; planner coverage and
wall-opening masks alone do not establish it.
