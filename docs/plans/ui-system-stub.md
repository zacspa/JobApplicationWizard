# Design System Token Stub

## Context

JobApplicationWizard has 50+ UI components with zero shared design tokens. All colors, spacing, typography, and corner radii are hardcoded per-component. We're establishing a `DesignSystem/` foundation that components will consume during future migration. The design direction: Apple frosted glass with muted productivity feel, system accent color, SF Pro throughout, and one expressive element (iridescent sheen on Cuttle-docked panels).

## File Structure

```
Sources/JobApplicationWizardCore/DesignSystem/
├── DS.swift                            // Root namespace enum
├── DSColor.swift                       // Semantic colors + opacity scale
├── DSTypography.swift                  // Font presets (SF Pro)
├── DSSpacing.swift                     // 4pt-based spacing scale
├── DSRadius.swift                      // Corner radius presets
├── DSShadow.swift                      // Elevation/shadow presets
├── DSMaterial.swift                    // Glass surface material definitions
├── DSTheme.swift                       // Environment-based theme slicing
├── Styles/
│   ├── GlassSurfaceModifier.swift      // .glassSurface() ViewModifier
│   ├── CardModifier.swift              // .cardStyle() ViewModifier
│   ├── PillButtonStyle.swift           // Capsule pill button (filter pills, chips)
│   ├── GhostButtonStyle.swift          // Borderless secondary action button
│   ├── SearchFieldStyle.swift          // Styled search TextFieldStyle
│   └── IridescentSheenModifier.swift   // .iridescentSheen() for Cuttle panels
└── DSPreview.swift                     // #Preview catalog for all tokens
```

## Token Definitions

### Colors (`DS.Color`)
- **Backgrounds:** `windowBackground`, `controlBackground`, `textBackground`, `surfaceElevated` (all via NSColor bridging for auto light/dark)
- **Text:** `textPrimary` (.primary), `textSecondary` (.secondary)
- **Borders:** `border` (.secondary @ 0.3), `borderSubtle` (.secondary @ 0.08)
- **Feedback:** `success`, `warning`, `error`, `info`
- **Opacity scale** (`DS.Color.Opacity`): `subtle` (0.08), `wash` (0.12), `tint` (0.15), `medium` (0.18), `strong` (0.25), `border` (0.3); replaces 15+ scattered magic opacity values
- Status colors stay on `JobStatus.color` (data-driven, not tokens)

### Typography (`DS.Typography`)
- **Display:** `displayLarge` (60pt), `displayMedium` (36pt), `displaySmall` (32pt)
- **Headings:** `heading1` (.title2.bold), `heading2` (.title3.bold), `heading3` (.headline)
- **Body:** `body`, `bodyMedium`, `bodySemibold`
- **Supporting:** `subheadline`, `subheadlineSemibold`, `caption`, `captionSemibold`, `caption2`, `footnote`
- **Special:** `micro` (9pt), `badge` (10pt)

### Spacing (`DS.Spacing`) — 4pt grid
`xxxs`=2, `xxs`=4, `xs`=6, `sm`=8, `md`=12, `lg`=16, `xl`=20, `xxl`=24, `xxxl`=32, `huge`=40

### Radius (`DS.Radius`)
`small`=6 (buttons/inputs), `medium`=8 (cards), `large`=10 (swimlanes), `xl`=12 (chat bubbles), `xxl`=16 (Cuttle panel)

### Shadows (`DS.Shadow`)
- `card`: black 4% opacity, radius 2, y 1
- `floating`: black 15% opacity, radius 12, y 4
- `none`: clear
- Plus `.dsShadow(_:)` View extension

### Materials (`DS.Glass`)
- `surface`: `.ultraThinMaterial` (floating panels)
- `overlay`: `.ultraThinMaterial` (processing overlays)
- `chrome`: `.regularMaterial` (header bars, input bars)

## Theme Slicing (`DSTheme.swift`)

Environment-based scoping so leaf views only receive the token subset they need, rather than coupling to the full `DS` namespace.

### Architecture

**`DSTheme`** is a struct containing optional slices of the token system:

```swift
struct DSTheme {
    var colors: DSColorSlice
    var typography: DSTypographySlice
    var spacing: DSSpacingSlice
    var radius: DSRadiusSlice
    var shadow: DSShadowSlice
    var glass: DSGlassSlice
}
```

Each slice is a protocol with a default conformance backed by the `DS` static values:

```swift
protocol DSColorSlice {
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var border: Color { get }
    // ... semantic color properties
}

// Default conformance reads from DS.Color
struct DefaultColorSlice: DSColorSlice {
    var textPrimary: Color { DS.Color.textPrimary }
    // ...
}
```

### How It Works

1. **Root view** injects a full `DSTheme` via `.environment(\.dsTheme, .default)`.
2. **Intermediate views** can narrow scope by injecting a modified theme with nil'd-out slices, or by injecting a custom slice (e.g., a different color palette for onboarding).
3. **Leaf views** read only the slice they need: `@Environment(\.dsTheme) var theme`, then access `theme.colors.textPrimary`.

### Benefits
- Components declare dependencies implicitly by which `theme.*` properties they access
- Testable: inject mock themes in previews/tests
- Future theming: swap an entire slice (e.g., high-contrast mode, onboarding palette) at any subtree boundary
- The static `DS.*` namespace remains the source of truth; themes just provide a scoped view into it

### Stub Scope
For the stub, we implement `DSTheme` with all slices using the default `DS.*` values. The slicing infrastructure is in place; custom scopes are a future migration concern.

## Component Styles

### `.glassSurface()` ViewModifier
Applies: material background + subtle border + shadow + corner radius. Replaces the 5-line pattern currently repeated in CuttleView, toast overlays, etc.

### `.cardStyle(isSelected:tintColor:)` ViewModifier
Applies: padding + elevated background + optional selection tint + card shadow. Replaces JobCard/StatBubble inline styling.

### `PillButtonStyle(isSelected:tint:)` ButtonStyle
Capsule shape with selected/unselected states. Replaces FilterPill and SuggestionChip inline styling.

### `GhostButtonStyle` ButtonStyle
Minimal borderless style for secondary actions.

### `DSSearchFieldStyle` TextFieldStyle
Search icon + rounded control background.

### `.iridescentSheen(isActive:cornerRadius:)` ViewModifier
Animated `LinearGradient` overlay with low-opacity hue-shifting colors (teal/cyan to violet). Sweeps via animated phase. `allowsHitTesting(false)`. Later integrates with `CuttleDockableModifier` to activate on dock.

## Implementation Order

1. `DS.swift` (namespace)
2. Token files (all independent): `DSColor`, `DSSpacing`, `DSRadius`, `DSTypography`, `DSShadow`, `DSMaterial`
3. `DSTheme.swift` (environment-based slicing; depends on token files)
4. Style files: `GlassSurfaceModifier`, `CardModifier`, `PillButtonStyle`, `GhostButtonStyle`, `SearchFieldStyle`
5. `IridescentSheenModifier`
6. `DSPreview.swift`
7. `swift build` verification

## Key Design Decisions

- **`DS` namespace** (not `Color.surface` extensions): avoids polluting autocomplete, prevents collisions with future Apple additions
- **NSColor bridging** for backgrounds: correct adaptive behavior without asset catalog
- **No existing code changes**: purely additive stub; migration is a separate pass
- **`SwiftUI.Color` fully qualified** inside `DS.Color` to avoid name collision
- **Environment-based theme slicing**: leaf views read `@Environment(\.dsTheme)` instead of `DS.*` directly; parents scope tokens per subtree

## Verification

- `swift build` compiles without errors
- Open `DSPreview.swift` in Xcode previews to visually verify all tokens
- Toggle light/dark appearance in preview to confirm adaptive colors

## Critical Files (reference, not modified)

- `Models.swift` — existing `Color(hex:)`, `JobStatus.color`, label colors
- `Features/Cuttle/CuttleContext.swift:104-135` — `CuttleDockableModifier` (future sheen integration point)
- `CuttleView.swift` — glass surface pattern to eventually replace
- `KanbanView.swift` — densest hardcoded values (primary migration target)
- `ContentView.swift` — FilterPill, toast, search bar patterns
