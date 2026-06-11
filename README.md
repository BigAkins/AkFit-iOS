# AkFit

AkFit is a native iOS nutrition app focused on **macro-first food tracking**, **portion accuracy**, and helping users hit daily **calorie, protein, carb, and fat goals** with less friction.

The goal is simple:

**help users log food quickly, understand their macros clearly, and stay aligned with their body-composition goals without unnecessary friction.**

---

## Why AkFit?

Most nutrition apps try to do everything.

AkFit is being built to do a few important things really well:

- track **calories, protein, carbs, and fat**
- make **food logging fast**
- support **practical serving sizes**
- help users understand **what they have left for the day**
- feel clean, modern, and easy to use on iPhone

AkFit is designed for users who care about:

- fat loss
- maintenance
- lean bulk / weight gain
- protein intake
- body composition
- performance
- practical meal decisions

---

## Product direction

AkFit is **macro-first**, not generic wellness-first.

The product should prioritize:

- calorie target clarity
- protein, carb, and fat tracking
- serving-size selection
- fast food search
- recent / repeated food logging
- barcode and scan workflows where useful
- clear daily targets and remaining macros

The product should avoid becoming bloated with:

- generic wellness clutter
- overbuilt AI gimmicks
- too many secondary metrics
- excessive motivational fluff
- exercise-heavy MVP complexity

---

## MVP goals

The first version of AkFit is focused on the core loop:

1. onboard the user and collect body/goal information
2. calculate daily calorie and macro targets
3. let the user search and log foods quickly
4. support realistic serving sizes and portion tracking
5. show what has been eaten and what remains for the day

---

## Core features planned

- onboarding for body stats and goal setup
- calorie and macro target calculation
- dashboard with daily totals and remaining macros
- food search with realistic food variants
- portion and serving-size selection
- meal logging
- barcode / scan support
- recent foods / repeated logging
- progress summaries

---

## UI direction

AkFit is being designed as a clean, premium-feeling iOS app.

Design priorities:

- clean white/light surfaces
- bold typography
- strong spacing
- rounded cards
- dark primary actions
- minimal clutter
- fast scanning and quick input
- iOS-native feel

The UI references for this project live in:

```text
docs/ui-reference/
```

Important files include:

```text
docs/ui-reference/00_index.md
docs/ui-reference/02_primary/
docs/ui-reference/03_secondary/
docs/ui-reference/05_notes/
CLAUDE.md
```

---

## Tech stack

- **iOS app:** SwiftUI
- **Language:** Swift
- **IDE:** Xcode / Cursor
- **Backend / auth / database / storage:** Supabase
- **Version control:** GitHub

Optional later surfaces may include:

- a marketing site
- internal admin tools
- helper services

---

## Repository structure

```text
AkFit-iOS/
├── AkFit/
├── AkFit.xcodeproj
├── docs/
│   └── ui-reference/
├── CLAUDE.md
└── README.md
```

---

## Design reference system

This repo includes a design reference system to help implementation stay visually consistent.

### Folder overview

```text
docs/ui-reference/
├── 00_index.md
├── 01_flows/
├── 02_primary/
├── 03_secondary/
├── 04_components/
├── 05_notes/
├── 06_future-features/
└── 99_archive/
```

### What it means

- `00_index.md` → main UI reference guide
- `01_flows/` → grouped screenshots by product flow
- `02_primary/` → strongest references for current AkFit implementation
- `03_secondary/` → supporting references for current AkFit implementation
- `04_components/` → reusable UI pattern inspiration
- `05_notes/` → product and UI notes
- `06_future-features/` → references for later concepts such as gamification, pet companion ideas, streak systems, motivation loops, and experimental premium features
- `99_archive/` → low-priority references intentionally kept out of active decision-making

---

## Claude Code workflow

This repo is structured so Claude Code can work cleanly inside it.

Before making implementation changes, Claude Code should inspect:

1. `CLAUDE.md`
2. `docs/ui-reference/00_index.md`
3. `docs/ui-reference/02_primary/`
4. `docs/ui-reference/03_secondary/`
5. relevant notes in `docs/ui-reference/05_notes/`

Persistent project rules live in:

```text
CLAUDE.md
```

---

## UI reference usage rules

The UI reference system exists to support implementation without destabilizing the current app.

Rules:

1. The current AkFit codebase and shipped UI are the source of truth.
2. Screenshot references are for visual guidance, not automatic feature requirements.
3. Current implementation work should primarily use:
   - `01_flows/`
   - `02_primary/`
   - `03_secondary/`
   - `04_components/`
4. `06_future-features/` should be used only for later-feature planning or explicitly requested future work.
5. Reference image source folders may live outside the AkFit repo before being organized into `docs/ui-reference/`.
6. External reference apps should influence layout and interaction quality, not product drift or feature bloat.

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/BigAkins/AkFit-iOS.git
cd AkFit-iOS
```

### 2. Open the iOS project

Open the Xcode project in Xcode or Cursor.

### 3. Configure local secrets

Copy the template and fill in the values from the Supabase dashboard
(**Project Settings → API**):

```bash
cp AkFit/Config/Secrets.xcconfig.template AkFit/Config/Secrets.xcconfig
```

Required keys (see the template's comments):

- `SUPABASE_URL` — note the `https:/$()/` escape, xcconfig treats `//` as a comment
- `SUPABASE_ANON_KEY`
- `SENTRY_DSN` — optional; the app runs without it

`Debug.xcconfig` / `Release.xcconfig` include this file with `#include?`
(optional include), so a **missing file builds fine but crashes at first
launch** with an intentional, self-describing `fatalError` from
`AkFit/Config/AppConfig.swift`. If you hit that crash, the file or a key is
missing/malformed.

Do **not** commit `Secrets.xcconfig` — it is gitignored; only the template is
tracked. The `supabase-swift` package dependency is already part of the
project.

### 4. Set up the database

Migrations, seed data, RLS tests, and the schema-drift verification procedure
live in [`supabase/README.md`](supabase/README.md):

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

---

## Security notes

This project should never commit:

- service role keys
- admin credentials
- local secret config files
- environment files with private values
- build artifacts
- user-specific Xcode data

Use Row Level Security and proper backend policies for user-owned data.

---

## Status

AkFit is **shipped on the App Store** (current version: see `MARKETING_VERSION`
in the Xcode project — 1.0.5 at the time of writing).

Live feature set:

- onboarding → personalized calorie/macro targets (Mifflin-St Jeor)
- dashboard with daily calorie/macro tracking and previous-day backfill
- food search (Supabase catalog + Open Food Facts), barcode scanning
- food logging with favorites, recents, and swipe quick-log
- water, bodyweight, daily notes, grocery list
- Sign in with Apple / Google / email, guest mode, account deletion
- Apple Health export, reminders, Sentry monitoring

Current bias (see `CLAUDE.md` for the authoritative rules): crash prevention,
App Store compliance, auth/Health stability, and minimal-risk improvements —
not new feature work. Operational docs: `docs/release-checklist.md`,
`docs/onboarding-save-flow.md`, `docs/debugging-supabase-errors.md`.

---

## Long-term vision

AkFit should become a practical daily nutrition app that helps users:

- know what to eat
- know how much they ate
- know where their macros stand
- stay consistent without friction

The long-term goal is not just tracking.

It is **daily adherence through clarity, speed, and accuracy**.

---

## License

Private / proprietary for now.

# AkFit-iOS
