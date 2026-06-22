# Ricochet Accessibility Ideas

The current dome ricochet is expressive but very hard to use because the reflection angle changes across the curved surface. These options are ways to make banked shots easier without removing the satisfaction of lining one up.

## Arena Shape Options

### Cylinder With Cone Top

Replace the dome with a vertical cylinder and a cone roof. The cylinder walls give predictable horizontal bank shots, while the cone top gives a constant reflection angle for upward shots. This keeps the ceiling-bank fantasy but makes it learnable because every shot into the cone follows a more consistent rule.

Pros:
- Easier to read and practice than a curved dome.
- The cone naturally guides shots downward toward the play space.
- Cylinder walls preserve side-bank shots.
- The arena silhouette still feels enclosed and iconic.

Risks:
- Less organic than a dome.
- The cone apex may become a dominant target unless the spring trap occupies or blocks it.
- Needs clear visual seams/materials so players understand wall vs cone behavior.

### Cylinder With Sloped Ring Ceiling

Use a cylinder wall and a truncated cone/frustum ceiling instead of a sharp cone. This avoids awkward apex behavior while keeping constant-angle reflection.

Pros:
- Cleaner collision and fewer extreme reflections near the top.
- Easier to place the spring trap in the flat center opening or cap.
- More readable for players.

### Bowl Or Rounded Cylinder Hybrid

Keep a mostly cylindrical arena, but round the transition between wall and ceiling. This gives simple side banks while softening the top boundary.

Pros:
- More natural than a hard cone.
- Avoids the full difficulty of a true dome.
- Still gives a premium arena feel.

## Shot Forgiveness Options

### Larger Ball Hit Collision

Give balls a larger invisible shot-hit shape than their visible mesh. The visual ball can stay skill-readable, while shots that are close still connect.

Recommended first pass:
- Visible radius: current ball size.
- Shot hit radius: 1.4x to 1.8x visible radius.
- Physics collision can remain smaller than shot collision.

### Ricochet Hit Assist Cone

After a ricochet, test a short cone or sphere sweep around the reflected ray instead of a single ray. This makes bank shots forgiving while direct shots can stay precise.

Tunable values:
- Post-ricochet assist radius.
- Assist distance.
- Whether assist only applies to balls.
- Whether final shot gets extra assist.

### Ceiling Bank Target Bias

When a shot ricochets off the ceiling and passes near a ball, gently bend the reflected direction toward the ball. Keep the effect subtle so it feels like skill, not auto-aim.

### Top-Hit Magnet For Balls

If a ricochet passes above a ball within a forgiving volume, count it as a top hit and apply a downward or angled impulse. This directly supports the desired gameplay of hitting balls from above.

### Bigger Spring Trap Or Bank Panel

Add explicit bank panels or glowing ceiling lanes around the spring trap. These can teach ricochet behavior and give players obvious practice targets.

## Feedback Options

### Persistent Ricochet Preview In Practice Mode

Show a faint projected bounce line while aiming, only in practice or debug mode. This is excellent for tuning and learning, but probably too much for competitive play unless stylized carefully.

### Stronger Shot Path Visuals

Make ricochet shot trails brighter and slightly longer-lived than direct shots. Banked shots are harder to parse, so they deserve extra readability.

### Impact Glyphs

Draw a quick ring or spark at the ricochet point, with a different color for bank shots that continue toward a ball. This helps players learn which surfaces are useful.

## Rule Options

### One Ricochet Only, But Generous

Keep the current one-bounce rule, but make the post-bounce hit detection forgiving. This preserves clarity and avoids chaotic multi-bounce trick shots.

### Bank Shot Bonus

Reward successful ricochet hits with slightly increased impulse or charge. This makes bank shots worth learning, but only after they become usable.

### Team-Ball Assist Only

Apply extra ricochet forgiveness only when shooting your own ball upward. Attacking the enemy ball can remain more precise.

## Predictable Ball Behavior Options

The ball still feels hard to reason about if gravity and impulse combine into fast, chaotic arcs. These options make the ball easier to track and make bank shots more repeatable.

### No Gravity, Impulse Decay

Set ball gravity to zero and rely on shot impulses plus strong damping. The ball becomes a floating target that only changes motion when players act on it.

Pros:
- Most predictable option.
- Bank shots are easier to practice because the target is not constantly accelerating downward.
- The red keeper bot becomes a useful aim demo rather than a panic save system.

Risks:
- The core keep-it-up pressure is weaker unless scoring uses a lower kill plane, drift zones, or timed possession pressure.
- Balls may hover in boring states without a small attractor or decay rule.

### Very Low Gravity, High Damping

Keep gravity, but make it much weaker and increase linear damping. The ball still slowly trends downward, but it does not build large fall speeds.

Implemented first pass:
- Gravity scale: 0.10.
- Linear damping: 0.28.

Suggested first pass:
- Gravity scale: 0.05 to 0.15.
- Linear damping: 0.18 to 0.35.
- Lower normal shot impulse if the ball still accelerates too quickly.

Pros:
- Preserves the keep-it-up premise.
- Easier to read than the current falling arcs.
- Less likely to stall than true zero gravity.

### Speed Clamp

Clamp ball linear speed after physics integration. This keeps big shots exciting without letting the ball become unreadable.

Suggested first pass:
- Maximum speed: 10 to 14 units/second.
- Separate max downward speed: 6 to 9 units/second.
- Preserve direction, scale magnitude only.

Pros:
- Prevents runaway chaos.
- Keeps existing gravity and shot rules mostly intact.
- Easy to tune and test.

### Soft Ceiling/Floor Bands

Apply gentle corrective acceleration when balls enter extreme vertical bands. This keeps balls in a playable height range without feeling like hard rails.

Pros:
- Keeps action in the readable middle of the arena.
- Reduces long waits and impossible high/low states.

Risks:
- Can feel artificial if the correction is too strong.

### Recommended Ball Tuning Prototype

Try very low gravity plus speed clamps first. It preserves the game identity better than no gravity, but should make the ball vastly more predictable. If it still feels too frantic, test zero gravity with impulse decay as a separate mode.

Implemented first: very low gravity plus high damping. Speed clamps remain the next option if shots still create unreadable ball speeds.

## Recommended Next Prototype

1. Replace the dome with a cylinder plus truncated cone top. // yes - implemented with cylinder walls and a constant-slope truncated cone ricochet surface.
2. Add an invisible enlarged shot-hit area around balls. // yes - implemented with a larger ball-only shot target area while preserving the visible/physics radius.
3. Make ricochet shots use a sphere sweep or cone assist after the bounce. // no (unintuitive behavior) - intentionally skipped.
4. Strengthen ricochet shot path visuals and impact markers. // yes - implemented with brighter, larger, longer-lived bank-shot feedback.
5. Add tests that compare direct ray difficulty against assisted ricochet success. // yes - implemented with geometry, enlarged-hit-area, and bank-feedback scenario checks.

This keeps the core idea while making the bank-shot skill curve much less punishing.

Follow-up revised: the spring trap is now the flat top cap rather than the whole frustum. The sloped frustum remains a predictable ricochet surface, while shots into the cap charge the trap and balls touching the cap receive the downward spring impulse.

Follow-up tuning note: the frustum should use a smaller 30-degree incline and avoid overlapping coplanar visual surfaces to prevent clipping.

