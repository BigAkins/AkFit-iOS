# AkFit Agent Instructions

## Project priorities
- Preserve current UI and visual design
- Prefer minimal, high-confidence changes
- Do not refactor unrelated code
- Do not change app structure unless necessary for the fix
- Optimize for App Store safety, crash prevention, and review compliance

## Current focus
Fix App Store rejection issues:
1. Sign in with Apple must not require name/email collection after Apple auth
2. Apple Health connect flow must never crash, especially on iPad / unsupported or unavailable HealthKit environments

## Coding rules
- Keep existing architecture and naming style
- Avoid broad cleanup
- Avoid moving files unless necessary
- Prefer narrow edits in existing files
- Add brief comments only where they prevent future mistakes
- Preserve behavior outside the target fix scope

## Risk rules
- Remove force unwrap risks in touched areas
- Guard unsupported-device APIs before use
- Fail gracefully instead of crashing
- Be careful with async UI updates and repeated button taps

## Output expectations
When making changes:
1. Explain root cause
2. List files changed
3. Make code edits
4. Summarize the change
5. Provide manual test steps