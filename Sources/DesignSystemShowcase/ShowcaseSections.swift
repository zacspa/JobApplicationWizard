import SwiftUI
import JobApplicationWizardCore

// MARK: - Colors

struct ColorsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Backgrounds")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: DS.Spacing.sm) {
                colorCard("windowBackground", DS.Color.windowBackground)
                colorCard("controlBackground", DS.Color.controlBackground)
                colorCard("textBackground", DS.Color.textBackground)
            }

            sectionHeader("Text")
            HStack(spacing: DS.Spacing.xl) {
                VStack {
                    Text("textPrimary")
                        .foregroundColor(DS.Color.textPrimary)
                    Text("On window background")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.windowBackground)
                .cornerRadius(DS.Radius.medium)

                VStack {
                    Text("textSecondary")
                        .foregroundColor(DS.Color.textSecondary)
                    Text("On control background")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.controlBackground)
                .cornerRadius(DS.Radius.medium)
            }

            sectionHeader("Borders")
            HStack(spacing: DS.Spacing.lg) {
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .stroke(DS.Color.border, lineWidth: 1)
                    .frame(width: 100, height: 60)
                    .overlay(Text("border").font(DS.Typography.caption))

                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .stroke(DS.Color.borderSubtle, lineWidth: 1)
                    .frame(width: 100, height: 60)
                    .overlay(Text("borderSubtle").font(DS.Typography.caption))
            }

            sectionHeader("Feedback")
            HStack(spacing: DS.Spacing.lg) {
                feedbackChip("success", DS.Color.success)
                feedbackChip("warning", DS.Color.warning)
                feedbackChip("error", DS.Color.error)
                feedbackChip("info", DS.Color.info)
            }

            sectionHeader("Opacity Scale")
            HStack(spacing: DS.Spacing.sm) {
                opacityStep("subtle\n0.08", DS.Color.Opacity.subtle)
                opacityStep("wash\n0.12", DS.Color.Opacity.wash)
                opacityStep("tint\n0.15", DS.Color.Opacity.tint)
                opacityStep("medium\n0.18", DS.Color.Opacity.medium)
                opacityStep("strong\n0.25", DS.Color.Opacity.strong)
                opacityStep("border\n0.3", DS.Color.Opacity.border)
            }
        }
    }

    @ViewBuilder
    private func colorCard(_ name: String, _ color: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .stroke(DS.Color.border, lineWidth: 1)
                )
            Text(name).font(DS.Typography.caption)
        }
    }

    @ViewBuilder
    private func feedbackChip(_ name: String, _ color: Color) -> some View {
        Text(name)
            .font(DS.Typography.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(color.opacity(DS.Color.Opacity.tint))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func opacityStep(_ label: String, _ opacity: Double) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(Color.accentColor.opacity(opacity))
                .frame(width: 80, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .stroke(DS.Color.border, lineWidth: 1)
                )
            Text(label)
                .font(DS.Typography.micro)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Typography

struct TypographyShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            sectionHeader("Display")
            Text("displayLarge (60pt)").font(DS.Typography.displayLarge)
            Text("displayMedium (36pt)").font(DS.Typography.displayMedium)
            Text("displaySmall (32pt)").font(DS.Typography.displaySmall)

            Divider()

            sectionHeader("Headings")
            Text("heading1 — title2.bold").font(DS.Typography.heading1)
            Text("heading2 — title3.bold").font(DS.Typography.heading2)
            Text("heading3 — headline").font(DS.Typography.heading3)

            Divider()

            sectionHeader("Body")
            Text("body — default weight").font(DS.Typography.body)
            Text("bodyMedium — .medium weight").font(DS.Typography.bodyMedium)
            Text("bodySemibold — .semibold weight").font(DS.Typography.bodySemibold)

            Divider()

            sectionHeader("Supporting")
            Text("subheadline").font(DS.Typography.subheadline)
            Text("subheadlineSemibold").font(DS.Typography.subheadlineSemibold)
            Text("caption").font(DS.Typography.caption)
            Text("captionSemibold").font(DS.Typography.captionSemibold)
            Text("caption2").font(DS.Typography.caption2)
            Text("footnote").font(DS.Typography.footnote)

            Divider()

            sectionHeader("Special")
            Text("micro (9pt)").font(DS.Typography.micro)
            Text("badge (10pt)").font(DS.Typography.badge)
        }
    }
}

// MARK: - Spacing

struct SpacingShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("Spacing Scale (4pt grid)")

            spacingRow("xxxs", 2, DS.Spacing.xxxs)
            spacingRow("xxs", 4, DS.Spacing.xxs)
            spacingRow("xs", 6, DS.Spacing.xs)
            spacingRow("sm", 8, DS.Spacing.sm)
            spacingRow("md", 12, DS.Spacing.md)
            spacingRow("lg", 16, DS.Spacing.lg)
            spacingRow("xl", 20, DS.Spacing.xl)
            spacingRow("xxl", 24, DS.Spacing.xxl)
            spacingRow("xxxl", 32, DS.Spacing.xxxl)
            spacingRow("huge", 40, DS.Spacing.huge)
        }
    }

    @ViewBuilder
    private func spacingRow(_ name: String, _ pts: Int, _ value: CGFloat) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text("\(name) (\(pts)pt)")
                .font(DS.Typography.caption)
                .frame(width: 100, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: value * 6, height: 20)
            // Visual spacer demo
            HStack(spacing: 0) {
                Rectangle().fill(Color.accentColor.opacity(DS.Color.Opacity.tint))
                    .frame(width: 30, height: 30)
                Color.clear.frame(width: value)
                Rectangle().fill(Color.accentColor.opacity(DS.Color.Opacity.tint))
                    .frame(width: 30, height: 30)
            }
        }
    }
}

// MARK: - Radii

struct RadiiShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Corner Radii")

            HStack(spacing: DS.Spacing.xl) {
                radiusSample("small (6)", DS.Radius.small)
                radiusSample("medium (8)", DS.Radius.medium)
                radiusSample("large (10)", DS.Radius.large)
                radiusSample("xl (12)", DS.Radius.xl)
                radiusSample("xxl (16)", DS.Radius.xxl)
            }

            sectionHeader("In Context")

            HStack(spacing: DS.Spacing.lg) {
                Text("Button")
                    .font(DS.Typography.caption)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Color.controlBackground)
                    .cornerRadius(DS.Radius.small)

                Text("Card")
                    .font(DS.Typography.caption)
                    .padding(DS.Spacing.lg)
                    .background(DS.Color.controlBackground)
                    .cornerRadius(DS.Radius.medium)

                Text("Panel")
                    .font(DS.Typography.caption)
                    .padding(DS.Spacing.xl)
                    .background(DS.Color.controlBackground)
                    .cornerRadius(DS.Radius.xxl)
            }
        }
    }

    @ViewBuilder
    private func radiusSample(_ label: String, _ radius: CGFloat) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: radius)
                .fill(DS.Color.controlBackground)
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DS.Color.border, lineWidth: 1)
                )
            Text(label).font(DS.Typography.caption)
        }
    }
}

// MARK: - Shadows

struct ShadowsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Shadow Presets")

            HStack(spacing: DS.Spacing.xxxl) {
                VStack(spacing: DS.Spacing.sm) {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(DS.Color.controlBackground)
                        .frame(width: 160, height: 100)
                        .dsShadow(DS.Shadow.card)
                    Text("card").font(DS.Typography.caption)
                    Text("For job cards, stat bubbles").font(DS.Typography.micro)
                        .foregroundColor(DS.Color.textSecondary)
                }

                VStack(spacing: DS.Spacing.sm) {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(DS.Color.controlBackground)
                        .frame(width: 160, height: 100)
                        .dsShadow(DS.Shadow.floating)
                    Text("floating").font(DS.Typography.caption)
                    Text("For Cuttle panel, popovers").font(DS.Typography.micro)
                        .foregroundColor(DS.Color.textSecondary)
                }

                VStack(spacing: DS.Spacing.sm) {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(DS.Color.controlBackground)
                        .frame(width: 160, height: 100)
                        .dsShadow(DS.Shadow.none)
                    Text("none").font(DS.Typography.caption)
                    Text("Flat elements").font(DS.Typography.micro)
                        .foregroundColor(DS.Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Glass

struct GlassShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Glass Materials")
            Text("Materials over a gradient background")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            ZStack {
                LinearGradient(
                    colors: [.blue, .purple, .pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 300)
                .cornerRadius(DS.Radius.large)

                HStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.sm) {
                        Text("Glass.surface")
                            .font(DS.Typography.bodySemibold)
                        Text("ultraThinMaterial")
                            .font(DS.Typography.caption)
                        Text("Floating panels, Cuttle")
                            .font(DS.Typography.micro)
                    }
                    .padding(DS.Spacing.xl)
                    .glassSurface()

                    VStack(spacing: DS.Spacing.sm) {
                        Text("Glass.chrome")
                            .font(DS.Typography.bodySemibold)
                        Text("regularMaterial")
                            .font(DS.Typography.caption)
                        Text("Headers, input bars")
                            .font(DS.Typography.micro)
                    }
                    .padding(DS.Spacing.xl)
                    .background(DS.Glass.chrome, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .stroke(DS.Color.borderSubtle, lineWidth: 1)
                    )
                }
            }

            sectionHeader(".glassSurface() Modifier")
            Text("Applies material + border + shadow in one call")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.lg) {
                Text("Default")
                    .padding(DS.Spacing.xl)
                    .glassSurface()

                Text("No border")
                    .padding(DS.Spacing.xl)
                    .glassSurface(border: false)

                Text("Card shadow")
                    .padding(DS.Spacing.xl)
                    .glassSurface(shadow: DS.Shadow.card)

                Text("Custom radius")
                    .padding(DS.Spacing.xl)
                    .glassSurface(radius: DS.Radius.xxl)
            }
        }
    }
}

// MARK: - Buttons

struct ButtonsShowcase: View {
    @State private var selectedPill = 1

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("PillButtonStyle")
            Text("Filter pills, suggestion chips, tag toggles")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<5) { i in
                    Button("Option \(i)") { selectedPill = i }
                        .buttonStyle(PillButtonStyle(isSelected: selectedPill == i))
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Button("Custom Tint") {}
                    .buttonStyle(PillButtonStyle(isSelected: true, tint: .purple))
                Button("Green Tint") {}
                    .buttonStyle(PillButtonStyle(isSelected: true, tint: .green))
                Button("Orange Tint") {}
                    .buttonStyle(PillButtonStyle(isSelected: true, tint: .orange))
            }

            Divider()

            sectionHeader("GhostButtonStyle")
            Text("Secondary actions, toolbar icons")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.lg) {
                Button { } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(GhostButtonStyle())

                Button { } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(GhostButtonStyle())

                Button { } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(GhostButtonStyle())
            }

            Divider()

            sectionHeader("System Styles (for comparison)")
            HStack(spacing: DS.Spacing.lg) {
                Button("Bordered") {}
                    .buttonStyle(.bordered)
                Button("Bordered Prominent") {}
                    .buttonStyle(.borderedProminent)
                Button("Plain") {}
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Cards

struct CardsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader(".cardStyle() Modifier")
            Text("Job cards, stat bubbles, info panels")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Acme Corp").font(DS.Typography.bodySemibold)
                    Text("Senior Engineer").font(DS.Typography.subheadline)
                    Text("San Francisco, CA")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(width: 200)
                .cardStyle()

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Selected Card").font(DS.Typography.bodySemibold)
                    Text("With accent tint").font(DS.Typography.subheadline)
                    Text("isSelected: true")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(width: 200)
                .cardStyle(isSelected: true)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Custom Tint").font(DS.Typography.bodySemibold)
                    Text("With purple tint").font(DS.Typography.subheadline)
                    Text("tintColor: .purple")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(width: 200)
                .cardStyle(isSelected: true, tintColor: .purple)
            }

            sectionHeader("Stat Bubbles")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                statBubble("12", "Total Jobs")
                statBubble("3", "Interviews")
                statBubble("1", "Offers")
                statBubble("5", "Applied")
            }
            .frame(width: 300)
        }
    }

    @ViewBuilder
    private func statBubble(_ value: String, _ label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value).font(DS.Typography.heading1)
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundColor(DS.Color.textSecondary)
        }
        .cardStyle()
    }
}

// MARK: - Inputs

struct InputsShowcase: View {
    @State private var searchText = ""
    @State private var emptyField = ""
    @State private var filledField = "Acme Corp"
    @State private var notesText = "Some notes about this application..."
    @State private var selectedDate: Date? = Date()
    @State private var nilDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Search Field (DSTextField + .outlinedField)")

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                DSTextField("Search companies, titles...", text: $searchText)
            }
            .outlinedField("Search", isEmpty: searchText.isEmpty)
            .frame(width: 360)

            Divider()

            sectionHeader("Outlined Fields")
            Text("Primary input pattern. Fields accent with the lane color (dsLaneAccent).")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Empty (closed border)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    DSTextField("Company", text: $emptyField)
                        .outlinedField("Company", isEmpty: emptyField.isEmpty)
                }
                .frame(width: 240)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Filled (floating label)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    DSTextField("Company", text: $filledField)
                        .outlinedField("Company", isEmpty: filledField.isEmpty)
                }
                .frame(width: 240)
            }

            Divider()

            sectionHeader("DSOutlinedTextEditor")
            DSOutlinedTextEditor("Notes", text: $notesText)
                .frame(width: 400)

            Divider()

            sectionHeader("DSDateField (Optional Date)")
            Text("Supports optional Date? binding; nil shows placeholder, set shows formatted date.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("With date set")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    DSDateField("Interview Date", date: $selectedDate)
                }
                .frame(width: 280)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("No date (nil)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    DSDateField("Deadline", date: $nilDate)
                }
                .frame(width: 280)
            }
        }
    }
}

// MARK: - Note Cards

struct NoteCardsShowcase: View {
    @State private var editorNote = "Research the team culture and recent product launches before the interview."
    @State private var editorTitle = "Interview Prep"
    @State private var editorSubtitle = "Round 2 with engineering"

    private let cardColors: [Color] = [
        Color(red: 1.0, green: 0.87, blue: 0.8),
        Color(red: 0.8, green: 0.92, blue: 1.0),
        Color(red: 0.85, green: 1.0, blue: 0.88),
        Color(red: 0.95, green: 0.85, blue: 1.0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Note Card Grid")
            Text("Compact cards shown in a grid; tap to expand into the editor view.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: DS.Spacing.md) {
                ForEach(Array(zip(0..., ["Interview Prep", "Salary Research", "Company Notes", "Follow-up"])), id: \.0) { idx, title in
                    noteCardSample(title: title, accentColor: cardColors[idx % cardColors.count])
                }
            }
            .frame(maxWidth: 500)

            Divider()

            sectionHeader("Note Editor (Expanded Card)")
            Text("Full editing view with accent bar, inline title/subtitle, and body editor.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(cardColors[0])
                    .frame(height: 6)

                HStack {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text("Notes")
                    }
                    .font(DS.Typography.subheadline)
                    .foregroundColor(.accentColor)

                    Spacer()

                    Button {} label: {
                        Label("Delete", systemImage: "trash").font(DS.Typography.footnote)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSTextField("Untitled", text: $editorTitle, font: .systemFont(ofSize: 20, weight: .bold))
                        .frame(minHeight: 28)
                    DSTextField("Add a subtitle...", text: $editorSubtitle, font: .systemFont(ofSize: 13))
                    Divider().padding(.vertical, DS.Spacing.xs)
                    DSOutlinedTextEditor("Body", text: $editorNote, minHeight: 80)
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .stroke(Color.secondary.opacity(DS.Color.Opacity.tint), lineWidth: 1)
            )
            .frame(maxWidth: 480)
        }
    }

    @ViewBuilder
    private func noteCardSample(title: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(height: 6)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text("Sample note body text for preview.")
                    .font(DS.Typography.footnote).foregroundColor(DS.Color.textSecondary)
                    .lineLimit(2)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .stroke(Color.secondary.opacity(DS.Color.Opacity.tint), lineWidth: 1)
        )
        .dsShadow(DS.Shadow.card)
    }
}

// MARK: - Rows & Bars

struct RowsShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader(".sectionHeaderStyle()")
            Text("Applies heading3 font with bottom padding; used for tab section titles")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Overview")
                    .sectionHeaderStyle()
                Text("Contacts")
                    .sectionHeaderStyle()
                Text("Documents")
                    .sectionHeaderStyle()
            }
            .padding(DS.Spacing.lg)
            .background(DS.Color.controlBackground)
            .cornerRadius(DS.Radius.medium)

            Divider()

            sectionHeader(".detailRow()")
            Text("Icon + label rows for the Overview tab; optional divider between items")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "building.2")
                        .foregroundColor(DS.Color.textSecondary)
                    Text("Acme Corp")
                        .font(DS.Typography.body)
                }
                .detailRow(showDivider: true)

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(DS.Color.textSecondary)
                    Text("San Francisco, CA")
                        .font(DS.Typography.body)
                }
                .detailRow(showDivider: true)

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(DS.Color.textSecondary)
                    Text("$180,000 - $220,000")
                        .font(DS.Typography.body)
                }
                .detailRow(showDivider: false)
            }
            .background(DS.Color.controlBackground)
            .cornerRadius(DS.Radius.medium)
            .frame(width: 360)

            Divider()

            sectionHeader(".actionBar()")
            Text("Horizontal bar for tab-level actions; provides padding and controlBackground fill")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.sm) {
                Button {} label: {
                    Label("Add Contact", systemImage: "plus")
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button {} label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(GhostButtonStyle())

                Button {} label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .actionBar()
            .cornerRadius(DS.Radius.medium)
            .frame(width: 480)
        }
    }
}

// MARK: - Iridescent Sheen

struct SheenShowcase: View {
    @State private var sheenActive = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            sectionHeader("Iridescent Sheen")
            Text("Animated overlay for Cuttle-docked panels; the one expressive element in a muted UI. Now live on docked panels in the app, not just a demo.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)

            Toggle("Sheen active", isOn: $sheenActive)

            HStack(spacing: DS.Spacing.xl) {
                VStack(spacing: DS.Spacing.sm) {
                    Text("Cuttle is here")
                        .font(DS.Typography.bodySemibold)
                    Text("Docked to this panel")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(width: 240, height: 120)
                .glassSurface(radius: DS.Radius.large)
                .iridescentSheen(isActive: sheenActive, cornerRadius: DS.Radius.large)

                VStack(spacing: DS.Spacing.sm) {
                    Text("No Cuttle")
                        .font(DS.Typography.bodySemibold)
                    Text("Plain glass surface")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .frame(width: 240, height: 120)
                .glassSurface(radius: DS.Radius.large)
            }

            sectionHeader("On Cards")
            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Acme Corp").font(DS.Typography.bodySemibold)
                    Text("Senior Engineer").font(DS.Typography.subheadline)
                }
                .frame(width: 200)
                .cardStyle()
                .iridescentSheen(isActive: sheenActive, cornerRadius: DS.Radius.medium)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("No sheen").font(DS.Typography.bodySemibold)
                    Text("Regular card").font(DS.Typography.subheadline)
                }
                .frame(width: 200)
                .cardStyle()
            }

            sectionHeader("On Pills")
            HStack(spacing: DS.Spacing.xs) {
                Button("All Jobs") {}
                    .buttonStyle(PillButtonStyle(isSelected: true))
                    .iridescentSheen(isActive: sheenActive, cornerRadius: 20)
                Button("Applied") {}
                    .buttonStyle(PillButtonStyle())
                Button("Interview") {}
                    .buttonStyle(PillButtonStyle())
            }
        }
    }
}

// MARK: - Shared Helpers

@ViewBuilder
func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(DS.Typography.heading2)
        .padding(.top, DS.Spacing.sm)
}
