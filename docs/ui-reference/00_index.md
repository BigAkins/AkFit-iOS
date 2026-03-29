# AkFit UI Reference Index

## Purpose

This folder contains the visual reference system for **AkFit**, an iOS app focused on:

- calorie tracking
- macro tracking
- portion accuracy
- practical food logging
- body composition goals
- fast, low-friction daily use

These references exist to guide **Claude Code** and keep the AkFit UI visually consistent, clean, and product-focused.

AkFit should feel:

- clean
- premium
- modern
- mobile-first
- fast
- uncluttered
- macro-first rather than generic wellness-first

---

## Source of truth priority

When building UI for AkFit, use this priority order:

1. **AkFit product and iOS UI artifacts**
2. **Primary references in `02_primary/`**
3. **Supporting references in `03_secondary/`**
4. **Flow examples in `01_flows/`**
5. **Component ideas in `04_components/`**
6. **Notes in `05_notes/`**

If references conflict:

- follow the **AkFit product direction** first
- then follow the **primary references**
- then use secondary references only as support

If two references look similar but one is more aligned with AkFit’s core experience, prefer the one that is more:

- macro-focused
- food-logging-focused
- simple
- legible
- practical for repeated daily use

---

## AkFit product direction

AkFit is **not** trying to be a broad wellness app.

AkFit should prioritize:

- calories
- protein
- carbs
- fat
- serving size selection
- fast food logging
- realistic portion entry
- clear daily targets
- clear remaining macros
- confidence in what the user should eat next

AkFit should **not** let lower-priority surfaces dominate the UI, such as:

- generic health scores
- too many motivational slides
- too much emphasis on water, steps, or exercise
- cluttered feature menus
- overly “AI gimmick” interfaces

---

## MVP flows

The core MVP flows are:

1. onboarding
2. dashboard
3. food search
4. food detail / portion selection
5. meal logging
6. barcode / scan
7. progress
8. settings

Exercise references may be used later, but they are not the main focus of the first AkFit MVP.

---

## Most important screens

These are the most important AkFit screens to get right first:

1. **Dashboard / Home**
2. **Food search and search results**
3. **Food detail / portion selection**
4. **Onboarding results / target setup**
5. **Barcode / live scan**

These should receive the most attention when implementing UI.

---

## Visual rules

### 1. Overall style
Use:

- very clean layouts
- large bold headings
- white or very light backgrounds
- soft card surfaces
- dark primary actions
- minimal visual noise
- strong spacing rhythm
- rounded corners
- simple icon use

Avoid:

- overly crowded screens
- dense text walls
- too many accent colors
- unnecessary decoration
- excessive gradients or flashy UI

### 2. Typography
Prefer:

- large bold screen titles
- short, clear labels
- strong hierarchy
- readable stat cards
- minimal copy

### 3. Cards
Cards should feel:

- clean
- spacious
- touch-friendly
- easy to scan quickly

Macro cards and food cards should prioritize readability over novelty.

### 4. Buttons
Primary CTAs should be:

- large
- obvious
- bottom-anchored when appropriate
- dark filled buttons with strong contrast

### 5. Navigation
Preferred navigation pattern:

- bottom navigation
- floating add button for quick logging
- simple back navigation
- minimal deep nesting where possible

### 6. Inputs
Prefer:

- large tap targets
- clear wheel pickers for body metrics
- simple segmented selections
- quick search entry
- portion and serving controls that are easy to scan

---

## What to copy most closely

The following design patterns are strong and should be followed closely where they match AkFit’s needs:

- onboarding question screens with large titles
- wheel picker body metrics screens
- goal selection cards
- dashboard card layout
- floating add button
- quick action add menu
- food search list styling
- search result rows with calorie + serving info
- live scan camera framing
- clean recent food cards

---

## What to adapt, not copy blindly

These patterns may be useful, but should be adapted carefully:

- health score surfaces
- fiber / sugar / sodium dashboard emphasis
- water and step tracking
- exercise-first screens
- long motivational onboarding sequences
- referral / acquisition questions
- too many “proof” screens

AkFit should remain centered on:

- macro adherence
- calorie targets
- portion clarity
- meal logging speed

---

## Primary reference summary

The `02_primary/` folder contains the strongest references for AkFit.

These references should guide the first implementation pass.

### Onboarding primary references
Use these patterns for onboarding structure and visual hierarchy:

- onboarding welcome
- height and weight
- goal selection
- desired weight
- birthdate
- goal speed
- onboarding results / transition

### Core app primary references
Use these patterns for the core AkFit product loop:

- dashboard home
- dashboard add menu
- food search
- food search results
- live scan camera

---

## Secondary reference summary

The `03_secondary/` folder contains:

- alternate states
- support screens
- empty states
- success states
- motivational examples
- guidance screens
- optional patterns

These should help clarify behavior and UI states, but they are not the main design source of truth.

---

## Flow folder intent

### `01_flows/onboarding/`
Use for:

- step-by-step setup screens
- wheel picker references
- selection card references
- target-setting flow
- onboarding persuasion/result patterns

### `01_flows/dashboard/`
Use for:

- home screen layout
- macro cards
- quick add interactions
- recent food cards
- loading / processing dashboard states

### `01_flows/food-search/`
Use for:

- search input styling
- results list layout
- quick-add food rows
- typed query behavior

### `01_flows/food-detail/`
Use for:

- serving-size selection
- quantity editing
- food detail presentation
- add-to-meal confirmation

### `01_flows/barcode/`
Use for:

- scan guidance
- live camera framing
- scan mode references
- barcode/label/library entry patterns

### `01_flows/meal-log/`
Use for:

- food logged states
- voice log states
- confirmation banners
- undo/view patterns

### `01_flows/progress/`
Use for:

- macro history
- progress card ideas
- secondary scoring concepts
- dashboard-like trend patterns

### `01_flows/settings/`
Use for:

- account and preferences screens
- profile editing
- goals/settings organization

### `01_flows/exercise/`
Use for later inspiration only.
Exercise is not the visual priority of the first AkFit MVP.

---

## Component guidance

The `04_components/` folder should eventually include reference examples for:

- bottom navigation
- floating add button
- stat cards
- macro rings
- food result rows
- search bars
- wheel pickers
- section headers
- CTA buttons
- toasts / success banners

When implementing components, keep them reusable and visually consistent with the primary references.

---

## Notes for Claude Code

When implementing UI:

1. inspect the files in this folder before making UI changes
2. identify the relevant flow first
3. follow `02_primary/` whenever possible
4. use `03_secondary/` only to support edge cases or alternate states
5. do not invent a new design language if a reference already fits
6. if a reference conflicts with AkFit’s product goals, prioritize AkFit’s product goals
7. optimize every important screen for:
   - clarity
   - speed
   - easy scanning
   - repeated daily use

---

## AkFit-specific adaptation rules

AkFit should differ from Cal AI in these ways:

- more macro-first
- more practical for portion tracking
- more useful for protein/carb/fat targeting
- less wellness-cluttered
- less persuasion-heavy
- less dependent on AI novelty
- more focused on accurate logging and daily adherence

If a Cal AI pattern is visually strong but product-wise off-target, keep the style and adjust the product behavior.

---

## Default implementation priorities

If unsure what to build first, prioritize in this order:

1. dashboard
2. food search
3. food detail / serving selection
4. onboarding targets/results
5. barcode scan
6. recent foods / meal log states
7. progress
8. settings
9. exercise

---

## Final rule

Every UI decision should support this outcome:

**AkFit should help users log food quickly, understand their macros clearly, and stay on target without friction.**