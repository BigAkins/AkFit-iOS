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
└── 99_archive/
```

### What it means

- `00_index.md` → main UI reference guide
- `01_flows/` → grouped screenshots by flow
- `02_primary/` → strongest references
- `03_secondary/` → supporting references
- `04_components/` → reusable UI pattern inspiration
- `05_notes/` → product and UI notes
- `99_archive/` → low-priority references

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

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/BigAkins/AkFit-iOS.git
cd AkFit-iOS
```

### 2. Open the iOS project

Open the Xcode project in Xcode or Cursor.

### 3. Create a Supabase project

Create a Supabase project and keep track of:

- project URL
- publishable / anon key
- database credentials

### 4. Add Supabase to the app

Add the Swift package dependency:

```text
https://github.com/supabase/supabase-swift.git
```

### 5. Configure local secrets

Create a local config file for secrets and environment-specific values.

Example:

```text
Secrets.xcconfig
```

Do **not** commit real secrets to the repository.

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

AkFit is currently in the **planning and foundation setup** phase.

Current focus:

- repo setup
- UI reference organization
- Claude Code instruction system
- iOS project structure
- backend foundation planning

Next major steps:

- initialize the Xcode app
- connect Supabase
- define the first MVP schema
- implement onboarding
- implement dashboard
- implement food search and logging flow

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
