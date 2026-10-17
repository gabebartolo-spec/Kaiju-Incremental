# UI handoff, 2026-10-18 05:10
## State: running a check (smoke + flow suites local; CI captures next)

## Task
Director (2026-10-18, in chat): "you are User Interface, buttons, menus; make the game UI
thematically rich, beautiful and intuitive; full licence to create our own assets".
Director picked look A "Emergency Broadcast" from three mockups (A broadcast / B concrete /
C monster hide), AskUserQuestion answer 2026-10-18. Needs a D-id from the merge role.

## Look A in one line
The city's civil-defence alarm is screaming about you: hazard yellow (ffcc00) on near-black
(0b0b0d), alert red (ff3b30), square edges, hazard tape, faint scanlines, a red news crawl.

## Branch
claude/ui-broadcast in ../Kaiju-Incremental-wt/ui-broadcast, from origin/claude/look-options
444ed01. PR goes into claude/look-options. Not pushed yet at time of writing.

## What is built
- scenes/hazard_box.gd: StyleBox subclass (fill, edge solid/dashed, tape band left/top,
  focus ring); static tape() and frame() draw helpers. fill setter emits changed.
- scenes/news_ticker.gd: red crawl, black BREAKING tag, frame-delta scroll (presentation).
- scenes/ui_kit.gd: new palette (+ALERT), box radius 0, hazard(), ink() (dark text on bright
  fills), panel() = yellow edge + top tape, button() = left tape, focus lights dark buttons
  yellow with a ring, bar(taped), tape(), backdrop() with Scanlines; inner classes Tape,
  Scanlines.
- upgrade_node.gd: maxed yellow, buy green, locked dashed, evolve alert red, ultimate under
  a tape band (MAX_BORDER ultimate 6 -> 8 to keep text clear of the band).
- title_screen.gd: CIVIL DEFENCE ALERT kicker, tape on top edge, news crawl (NEWS + "<SPECIES>
  STILL AT LARGE" when a save exists).
- rampage_hud.gd: dark plates behind the corner groups, clock in a red block (yellow under
  10 s), destruction bar taped.
- results_screen.gd: crawl with this rampage's news (ResultsScreen.news(result)).
- Mockups: scratchpad only (dir_A/B/C.png); copy A into docs/captures with the PR.

## Next
1. Suites green (smoke, flow; layout checks cover button fit at every UI scale).
2. Push, open PR into claude/look-options, CI capture_flow at 1080p and 4K125 -> 
   docs/captures/2026-10-18-ui-broadcast/; art-qa / screen-critic pass by the lead first.
3. Follow-ups worth proposing: HUD crawl reacting to rampage events; species select cards
   as "threat dossiers"; reveal screen "THREAT LEVEL RAISED".

## Open decisions
None pending; look A chosen.

## Running jobs
Local suites smoke + flow (background shell in this session).
