# Remotion video project

Remotion compositions for HabitForge marketing/UI video assets.
Dependencies are installed automatically in Claude Code on the web
sessions by `.claude/hooks/session-start.sh`.

## Compositions

- `PremiumMotionBackground` — 10 s, 1920x1080 (16:9), 30 fps seamless-loop
  motion background built from `public/reference.jpg` (rotated 90°, slow
  zoom drift, animated film grain).

## Commands

```bash
cd remotion
npm install                 # done automatically by the session-start hook
npm run still               # sanity-check a single frame -> preview.jpg
npm run render              # render mp4 -> ../assets/motion_backgrounds/
npm run studio              # interactive editor (local machines)
```
