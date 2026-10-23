import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: BooBarController
    private func text(_ key: BooText) -> String { controller.language.text(key) }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BooBar").font(BooPalette.font(32, strong: true)).tracking(-0.6)
                    Text(text(.tagline))
                        .font(BooPalette.font(14)).foregroundStyle(BooPalette.muted)
                }
                Spacer(minLength: 0)
                AnimatedMascot(active: controller.settingsVisible)
                    .accessibilityLabel(text(.mascot))
            }

            VStack(alignment: .leading, spacing: 15) {
                Text(text(.organize)).font(BooPalette.font(16, strong: true))
                HStack(spacing: 12) {
                    Text("⌘⇧").font(.system(size: 25, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(BooPalette.panel, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(text(.keys))
                    Text(text(.drag)).font(BooPalette.font(16)).foregroundStyle(BooPalette.muted)
                }
                HStack(spacing: 12) {
                    zone(text(.hidden), symbol: "eye.slash", detail: text(.left))
                    wall("|")
                    zone(text(.temporary), symbol: "cursorarrow", detail: text(.between))
                    wall(":")
                    zone(text(.visible), symbol: "eye", detail: text(.right))
                }
                .padding(.horizontal, 18).padding(.vertical, 21)
                .background(BooPalette.panel.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(BooPalette.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(text(.settings)).font(BooPalette.font(16, strong: true))
                VStack(alignment: .leading, spacing: 17) {
                    HStack(spacing: 13) {
                        settingIcon("hand.raised")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text(.permission)).font(BooPalette.font(13, strong: true))
                            Text(text(.permissionDetail))
                                .font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                        }
                        Spacer(minLength: 12)
                        if controller.authorized {
                            Label(text(.allowed), systemImage: "checkmark.circle.fill")
                                .font(BooPalette.font(12)).foregroundStyle(BooPalette.accent)
                        } else {
                            Button(text(.allow), action: controller.requestPermission)
                                .buttonStyle(BooButtonStyle(primary: true))
                        }
                    }
                    if !controller.authorized {
                        HStack(spacing: 5) {
                            Text(text(.alreadyAllowed)).foregroundStyle(BooPalette.muted)
                            Button(text(.restart), action: controller.restart)
                                .buttonStyle(.plain).foregroundStyle(BooPalette.accent)
                        }.font(BooPalette.font(11))
                    }
                    Rectangle().fill(BooPalette.border).frame(height: 1)
                    HStack(spacing: 13) {
                        settingIcon("arrow.right.to.line")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text(.login)).font(BooPalette.font(13, strong: true))
                            Text(text(.loginDetail))
                                .font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                        }
                        Spacer(minLength: 12)
                        Toggle(text(.login), isOn: Binding(
                            get: { controller.launchesAtLogin },
                            set: { controller.setLaunchAtLogin($0) }))
                            .labelsHidden().toggleStyle(.switch).tint(BooPalette.primary)
                    }
                    if controller.loginItemStatus == .requiresApproval {
                        Text(text(.loginApproval))
                            .font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                    }
                    if let error = controller.loginItemError { notice(text(.loginFailure) + " " + error) }
                    if controller.loginItemStatus == .requiresApproval || controller.loginItemError != nil {
                        Button(text(.loginSettings), action: controller.openLoginSettings)
                            .buttonStyle(.plain).font(BooPalette.font(12)).foregroundStyle(BooPalette.accent)
                    }
                    Rectangle().fill(BooPalette.border).frame(height: 1)
                    HStack(spacing: 13) {
                        Image(systemName: "globe")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(BooPalette.text).frame(width: 36, height: 36)
                            .background(BooPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text(.language)).font(BooPalette.font(13, strong: true))
                            Text(text(.languageDetail)).font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                        }
                        Spacer(minLength: 12)
                        Picker(text(.language), selection: $controller.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.title).tag(language)
                            }
                        }.labelsHidden().frame(width: 128)
                    }
                    Rectangle().fill(BooPalette.border).frame(height: 1)
                    HStack(spacing: 13) {
                        settingIcon("keyboard")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text(.shortcut)).font(BooPalette.font(13, strong: true))
                            Text(text(.shortcutHint)).font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                        }
                        Spacer(minLength: 8)
                        Button(controller.recordingShortcut ? text(.shortcutRecording) : controller.shortcut?.label ?? text(.shortcutRecord), action: controller.recordShortcut)
                            .buttonStyle(BooButtonStyle())
                    }
                    if controller.shortcutError { notice(text(.shortcutConflict)) }
                    Rectangle().fill(BooPalette.border).frame(height: 1)
                    UpdateSettings(manager: controller.updater, language: controller.language)
                }
                .padding(21)
                .background(BooPalette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(BooPalette.border, lineWidth: 1))
            }

            if let problem = controller.problem { notice(text(problem)) }
            else if !controller.nativeAvailable { notice(text(.unsupported)) }

            HStack(spacing: 12) {
                Button(action: controller.reset) {
                    Label(text(.reset), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(BooButtonStyle())
                .help(text(.resetHelp))
                Spacer(minLength: 0)
                Button(action: controller.quit) { Label(text(.quit), systemImage: "power") }
                    .buttonStyle(BooButtonStyle())
                    .keyboardShortcut("q", modifiers: .command)
                    .help(text(.quitHelp))
            }
            HStack {
                Spacer()
                Link("powered by unshapedstudio", destination: URL(string: "https://unshapedstudio.com/")!)
                    .font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                Spacer()
            }
        }
        .padding(.horizontal, 32).padding(.top, 38).padding(.bottom, 28)
        }
        .frame(width: 680, height: min(980, (NSScreen.main?.visibleFrame.height ?? 1028) - 48))
        .font(BooPalette.font(13)).foregroundStyle(BooPalette.text)
        .background {
            ZStack {
                BooPalette.background
                RadialGradient(colors: [BooPalette.primary.opacity(0.23), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 520)
            }.ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
    }

    private func zone(_ title: String, symbol: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(BooPalette.accent)
            Text(title).font(BooPalette.font(13, strong: true)).lineLimit(1)
            Text(detail).font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
        }.frame(maxWidth: .infinity)
    }

    private func wall(_ text: String) -> some View {
        Text(text).font(.system(size: 25, weight: .regular, design: .monospaced))
            .foregroundStyle(BooPalette.accent.opacity(0.75))
            .accessibilityLabel(self.text(text == "|" ? .permanentWall : .mainWall))
    }

    private func settingIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 17))
            .foregroundStyle(BooPalette.accent).frame(width: 36, height: 36)
            .background(BooPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    private func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(BooPalette.font(12)).foregroundStyle(Color(boobarHex: 0xeab47b))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct UpdateSettings: View {
    @ObservedObject var manager: UpdateManager
    let language: AppLanguage
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 13) {
                Image(systemName: "arrow.down.circle").font(.system(size: 19))
                    .foregroundStyle(BooPalette.accent).frame(width: 36, height: 36)
                    .background(BooPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.text(.updates)).font(BooPalette.font(13, strong: true))
                    Text(language.text(manager.status)).font(BooPalette.font(11)).foregroundStyle(BooPalette.muted)
                }
                Spacer(minLength: 8)
                Toggle(language.text(.updates), isOn: $manager.enabled)
                    .labelsHidden().toggleStyle(.switch).tint(BooPalette.primary)
            }
            Button(language.text(.updateCheck)) { Task { await manager.check(manual: true) } }
                .buttonStyle(.plain).foregroundStyle(BooPalette.accent).font(BooPalette.font(12))
                .disabled(manager.busy)
        }
    }
}
