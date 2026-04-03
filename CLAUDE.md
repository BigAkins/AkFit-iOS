# AkFit — Claude Code Project Instructions

use skills avalible to your advantage 

## gstack

Use the /browse skill from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.

Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex, /cso, /autoplan, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn.

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.

## Project overview

AkFit is a native **iOS app** built for fast, accurate nutrition tracking.

This product is focused on:

- calorie tracking
- macro tracking
- portion accuracy
- practical food logging
- body composition goals
- helping users hit protein, carb, and fat targets
- making daily nutrition adherence easier

AkFit is not a broad generic wellness app.
AkFit should feel more useful for users who care about:

- fat loss
- maintenance
- lean bulk / weight gain
- protein intake
- performance
- food precision
- practical meal decisions

## Platform and stack

Assume the product is being built as:

- **iOS app:** SwiftUI
- **IDE:** Cursor / Xcode workflow
- **Backend / auth / database / storage:** Supabase
- **Optional later surfaces:** Vercel for a marketing site, admin tools, or helper services if needed
- **Version control:** GitHub

Do not treat AkFit as a web-first Next.js app unless explicitly asked.

## Core product priorities

Always optimize for:

- clarity
- speed
- maintainability
- realistic MVP scope
- practical UX
- low-friction food logging
- accurate macro visibility
- clean architecture
- cost-effective implementation
- security and privacy by default

The most important user outcome is:

**AkFit should help users log food quickly, understand their macros clearly, and stay on target without friction.**

## Security and data protection rules

Security is a first-class requirement, not a later enhancement.

Always prefer the more secure option when tradeoffs are reasonable.

### Security priorities
- protect user account data
- protect nutrition and profile data
- minimize unnecessary data collection
- avoid exposing secrets
- enforce least-privilege access
- design for breach prevention, not just convenience

### Secrets rules
- never put Supabase secret keys or service-role keys in the iOS app
- never commit secrets to git
- never hardcode secrets into Swift files
- only client-safe values such as the Supabase anon/publishable key may exist in the client configuration
- use backend-only secrets only in secured backend components if they are ever added later

### Supabase security rules
- enable Row Level Security on all user-owned tables
- assume every table in `public` needs intentional access rules
- do not query user-owned data without RLS-backed protection
- do not bypass RLS for convenience
- keep policies explicit and easy to reason about
- prefer user-scoped access via authenticated user id

### Sensitive data handling rules
- collect only the user data needed for the product
- avoid storing unnecessary personal or health-adjacent data
- do not log tokens, credentials, auth responses, or sensitive profile data to console
- do not print Supabase keys in debugging output
- redact sensitive values in debug logs
- avoid storing sensitive data in UserDefaults when a more secure option is appropriate

### iOS credential storage rules
- use the Keychain for auth tokens, credentials, or similarly sensitive values when custom storage is needed
- prefer Apple-native secure storage patterns over ad hoc solutions
- do not invent custom crypto unless explicitly required and reviewed

### Networking and API rules
- prefer secure default networking behavior
- do not disable transport security casually
- do not add insecure networking exceptions unless absolutely required and explicitly justified
- validate that any new networked feature respects authentication and authorization boundaries

### Database and schema safety rules
- use explicit constraints where reasonable
- separate profile data from mutable goal data
- avoid overly permissive table structures
- prefer boring, auditable schemas over clever ones
- add indexes and constraints intentionally, not blindly

### Security workflow rules
When implementing backend or auth-related work:
1. identify what data is sensitive
2. identify who should be allowed to access it
3. verify where enforcement happens
4. prefer RLS and least privilege
5. explain any security tradeoff before taking a shortcut

If unsure, choose the safer implementation and explain the tradeoff.

## Product emphasis

AkFit should visually and functionally prioritize:

- calories
- protein
- carbs
- fat
- serving size clarity
- food search
- portion selection
- recent foods / repeated logging
- barcode / scan workflows where helpful
- daily targets and remaining macros

AkFit should de-prioritize in the MVP:

- generic wellness clutter
- excessive exercise features
- water/steps-heavy UX
- generic health-score-led UX
- motivational fluff
- overbuilt AI features
- referral / acquisition onboarding screens

## Source of truth files

Before making UI changes, inspect these files:

1. `docs/ui-reference/00_index.md`
2. files in `docs/ui-reference/02_primary/`
3. files in `docs/ui-reference/03_secondary/`
4. notes in `docs/ui-reference/05_notes/`

Before making backend/config/auth changes, inspect these files if present:

1. `CLAUDE.md`
2. config files related to Supabase
3. service/client provider files
4. current schema / SQL files
5. relevant auth or persistence code

When implementing UI, follow this priority order:

1. AkFit product direction
2. `docs/ui-reference/00_index.md`
3. `docs/ui-reference/02_primary/`
4. `docs/ui-reference/03_secondary/`
5. flow examples in `docs/ui-reference/01_flows/`
6. notes in `docs/ui-reference/05_notes/`

Do not invent a new design language if a strong reference already exists.

## Design implementation rules

AkFit should feel:

- clean
- premium
- modern
- minimal
- iOS-native
- fast
- easy to scan
- macro-first

### Keep
- large bold titles
- generous spacing
- rounded corners
- dark primary CTAs
- simple bottom navigation
- floating add button if it fits the screen
- clean cards
- strong visual hierarchy
- large tap targets
- simple inputs
- readable stat cards

### Avoid
- cluttered layouts
- tiny hard-to-tap controls
- too many competing metrics on one screen
- overly decorative visuals
- noisy gradients
- weak contrast
- gimmicky AI visual treatment
- forcing too many features into the dashboard

## Most important screens

These screens matter most and should receive the most care:

1. dashboard / home
2. food search
3. food detail / portion selection
4. onboarding target/results screens
5. barcode / scan flow

## Onboarding rules

Onboarding should be useful, not bloated.

It should help the user:

- enter body stats
- choose a goal
- choose a target pace
- understand calorie and macro targets

It should not:

- ask too many marketing questions
- overuse persuasion screens
- delay access to the product
- feel like a generic growth funnel

Tone should be:

- clear
- confident
- practical
- performance-oriented
- low fluff

## Dashboard rules

The dashboard is one of the most important screens in AkFit.

It should help the user understand in a few seconds:

- daily calorie target
- calories remaining
- protein remaining
- carbs remaining
- fat remaining
- what they logged recently
- how to quickly add more food

Dashboard priority order:

1. calories
2. protein
3. carbs
4. fat
5. recent food activity
6. quick add actions

Do not let steps, water, or low-priority health metrics dominate the dashboard.

## Food logging rules

Food logging is the most important product loop.

It should feel:

- fast
- accurate
- practical
- repeatable
- low-friction

Food search should support:

- specific food variants
- realistic foods
- practical serving units
- repeated daily use

Examples of good serving patterns:

- 4 oz chicken breast
- 6 oz chicken breast
- 1 cup rice
- 2 eggs
- 1 tbsp peanut butter

The product should make it easy for users to answer:

- what did I eat?
- how much did I eat?
- how many calories was that?
- how much protein, carbs, and fat did that add?
- what do I have left today?

## Barcode and scan rules

Barcode / scan workflows are useful, but should support the macro-tracking experience rather than take over the product.

Use scan references for:

- camera framing
- scan guidance
- clean scan UX
- label / library / barcode entry patterns

If scan UX conflicts with fast logging or macro clarity, prioritize the broader AkFit product loop.

## Exercise rules

Exercise features are not the main visual or product priority of the first MVP.

Do not overbuild exercise logging early unless explicitly asked.

## Technical architecture rules

Prefer:

- simple architecture
- strong separation of concerns
- reusable SwiftUI components
- small composable views
- clear domain models
- predictable state management
- maintainable data flow
- no unnecessary abstraction layers

Keep a clean separation between:

- UI / presentation
- domain/business logic
- networking / data access
- persistence / model mapping

## Workflow rules

Before making changes:

1. inspect the current repo structure
2. inspect relevant files
3. inspect `CLAUDE.md`
4. inspect relevant UI references
5. inspect relevant security/config/auth files when applicable
6. explain the implementation plan briefly

Then make changes.

After making changes, always summarize:

1. files created
2. files edited
3. what changed
4. how to test it
5. recommended next step
6. any security implications if relevant

## Editing rules

Do not make large speculative refactors unless they are clearly needed.

Prefer:

- focused changes
- minimal disruption
- clear file ownership
- incremental implementation
- preserving working code

If a task is ambiguous, choose the simplest practical option and explain the tradeoff.

## UI component rules

When building shared UI, optimize for reuse across:

- onboarding
- dashboard
- food search
- food detail
- scan flows
- settings

Likely reusable patterns include:

- stat cards
- macro rings
- CTA buttons
- food result rows
- search fields
- section headers
- bottom nav
- floating action button
- confirmation banners / toasts

## Product adaptation rule

If a reference from Cal AI is visually strong but product-wise not a great fit for AkFit:

- keep the visual pattern if useful
- adapt the behavior and content to AkFit’s macro-first product direction

Do not copy product decisions blindly from references.

## Scope-control rules

When unsure, choose the option that is:

- simpler
- faster to ship
- easier to maintain
- more aligned with the MVP
- more useful to repeated daily users
- safer from a security and privacy perspective

Avoid:

- overengineering
- premature optimization
- feature sprawl
- AI gimmicks
- building secondary systems before the core loop is excellent
- insecure shortcuts for speed

## Final rule

Every implementation decision should support this goal:

**AkFit should help users log food quickly, understand their calories and macros clearly, and stay aligned with their body-composition goals without unnecessary friction.**