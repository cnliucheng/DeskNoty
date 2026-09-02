import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var deckManager: DeckManager!
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        setupStatusItem()

        deckManager = DeckManager()
        UndoToast.shared.start()

        HotKeys.shared.register(
            newNote: { [weak self] in self?.newNote() },
            allNotes: { [weak self] in self?.openAllNotes() },
            archive:  { [weak self] in self?.openArchive() },
            capture:  { QuickCapture.shared.toggle() }
        )

        // Sparkle only schedules its background checks once the controller
        // exists. Until now nothing touched it before the pill's context menu
        // was opened, so a user who never right-clicked was never offered an
        // update however long the app ran.
        _ = Updater.shared
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeys.shared.unregisterAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Actions

    @objc func newNote() {
        let note = NoteStore.shared.create()
        deckManager.focused?.expand(note.id)
    }

    @objc func openAllNotes() { LibraryWindow.shared.show(mode: .all) }
    @objc func quickCapture() { QuickCapture.shared.toggle() }

    /// noty:// — the whole automation surface. The text only ever becomes note
    /// content, never anything executed, so there is nothing here to harden
    /// beyond ignoring what we do not recognise.
    ///   noty://new?text=…   create a note (no text → open quick capture)
    ///   noty://capture      open the quick capture box
    ///   noty://all          the All Notes window
    ///   noty://settings     the Settings window
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "noty" {
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "text" }?.value ?? ""
            switch url.host {
            case "new" where !text.isEmpty:
                _ = NoteStore.shared.create(body: text)
            case "new", "capture":
                QuickCapture.shared.show()
            case "all":      openAllNotes()
            case "settings": openSettings()
            default: break
            }
        }
    }
    @objc func openSettings() { SettingsWindow.shared.show() }

    /// Re-read preferences into every deck. Settings calls this on each change.
    func refreshDecks() { deckManager.refreshAll() }
    @objc func openArchive() { LibraryWindow.shared.show(mode: .archive) }

    @objc func toggleOverFullScreen() {
        Settings.showOverFullScreen.toggle()
        deckManager.refreshAll()
    }

    @objc func setDeckStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = DeckStyle(rawValue: raw) else { return }
        Settings.deckStyle = style
        deckManager.refreshAll()
    }

    @objc func setFontSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? Double else { return }
        Settings.noteFontSize = size
        deckManager.refreshAll()
    }

    /// ⌃+ / ⌃- while a note is open.
    func stepFontSize(by delta: Double) {
        Settings.noteFontSize += delta
        deckManager.refreshAll()
    }

    @objc func biggerText()  { stepFontSize(by: 1.5) }
    @objc func smallerText() { stepFontSize(by: -1.5) }

    @objc func setNoteFont(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Settings.noteFontName = name
        deckManager.refreshAll()
    }

    @objc func toggleDeckAlwaysShown() {
        Settings.deckAlwaysShown.toggle()
        deckManager.refreshAll()
    }

    @objc func setDeckScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        Settings.deckScale = scale
        deckManager.refreshAll()
    }

    @objc func toggleDeckEdge() {
        Settings.deckOnLeftEdge.toggle()
        deckManager.refreshAll()
    }

    @objc func setDisplayTarget(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? String else { return }
        Settings.displayTarget = target
        SettingsWindow.shared.syncPreferences()
    }

    @objc func toggleLaunchAtLogin() {
        Settings.launchAtLogin.toggle()
    }

    @objc func exportMarkdown()  { Transfer.export(.markdown,  notes: NoteStore.shared.notes) }
    @objc func exportPlainText() { Transfer.export(.plainText, notes: NoteStore.shared.notes) }
    @objc func exportSingleFile(){ Transfer.export(.singleFile, notes: NoteStore.shared.notes) }
    @objc func exportStickies()  { Transfer.export(.stickies,  notes: NoteStore.shared.notes) }
    @objc func importStickies()  { Transfer.importFiles() }

    @objc func checkForUpdates() { Updater.shared.checkForUpdates() }

    @objc func toggleAutoUpdates() {
        Updater.shared.automaticallyChecks.toggle()
    }

    @objc func quit() { NSApp.terminate(nil) }

    @objc func showAbout() {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = L10n.string("app.name")
        a.informativeText = L10n.string("app.about.message")
        a.runModal()
    }

    // MARK: Main menu
    //
    // An accessory app draws no menu bar, but NSApp.mainMenu is still what
    // dispatches ⌘C/⌘V/⌘Z inside the note editor — without it, text editing
    // loses every standard shortcut.

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.string("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: L10n.string("menu.checkUpdates"), action: #selector(checkForUpdates), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.string("menu.newNote"), action: #selector(newNote), keyEquivalent: "n")
        appMenu.addItem(withTitle: L10n.string("menu.allNotes"), action: #selector(openAllNotes), keyEquivalent: "a")
        appMenu.addItem(withTitle: L10n.string("menu.archive"), action: #selector(openArchive), keyEquivalent: "l")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.string("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.string("menu.import"), action: #selector(importStickies), keyEquivalent: "i")
        appMenu.addItem(.separator())
        let bigger = appMenu.addItem(withTitle: L10n.string("menu.biggerText"), action: #selector(biggerText), keyEquivalent: "+")
        bigger.keyEquivalentModifierMask = [.control]
        let smaller = appMenu.addItem(withTitle: L10n.string("menu.smallerText"), action: #selector(smallerText), keyEquivalent: "-")
        smaller.keyEquivalentModifierMask = [.control]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.string("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L10n.string("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // The three global shortcuts already carry ⌥; mirror that here so the menu
        // items do not shadow ⌘N / ⌘A / ⌘L inside text fields.
        for title in [L10n.string("menu.newNote"), L10n.string("menu.allNotes"), L10n.string("menu.archive")] {
            appMenu.item(withTitle: title)?.keyEquivalentModifierMask = [.command, .option]
        }
        for item in appMenu.items where item.action != nil
            && item.action != #selector(NSApplication.hide(_:))
            && item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: L10n.string("menu.edit"))
        edit.addItem(withTitle: L10n.string("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L10n.string("menu.redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L10n.string("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L10n.string("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L10n.string("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L10n.string("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    // MARK: Status Bar Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the status bar icon
            let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Noty")
            image?.isTemplate = true // Support dark/light mode
            button.image = image
            button.toolTip = L10n.string("statusItem.tooltip")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            // Left click: open All Notes window
            openAllNotes()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        
        // Add the same items as the deck context menu
        menu.addItem(withTitle: L10n.string("context.newNote"), action: #selector(newNote), keyEquivalent: "")
        menu.addItem(withTitle: L10n.string("context.allNotes"), action: #selector(openAllNotes), keyEquivalent: "")
        menu.addItem(withTitle: L10n.string("context.archive"), action: #selector(openArchive), keyEquivalent: "")
        menu.addItem(.separator())
        
        let overFS = NSMenuItem(title: L10n.string("context.showOverFullScreen"),
                                action: #selector(toggleOverFullScreen), keyEquivalent: "")
        overFS.state = Settings.showOverFullScreen ? .on : .off
        menu.addItem(overFS)
        
        let styleItem = NSMenuItem(title: L10n.string("context.deckStyle"), action: nil, keyEquivalent: "")
        let styleMenu = NSMenu()
        for s in DeckStyle.allCases {
            let it = NSMenuItem(title: s.title, action: #selector(setDeckStyle(_:)), keyEquivalent: "")
            it.representedObject = s.rawValue
            it.state = Settings.deckStyle == s ? .on : .off
            styleMenu.addItem(it)
        }
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)
        
        let fontItem = NSMenuItem(title: L10n.string("context.noteFont"), action: nil, keyEquivalent: "")
        let fontMenu = NSMenu()
        for f in Ink.faces {
            let it = NSMenuItem(title: f.name, action: #selector(setNoteFont(_:)), keyEquivalent: "")
            it.representedObject = f.body
            it.state = Ink.face.body == f.body ? .on : .off
            fontMenu.addItem(it)
        }
        fontItem.submenu = fontMenu
        menu.addItem(fontItem)
        
        let textItem = NSMenuItem(title: L10n.string("context.textSize"), action: nil, keyEquivalent: "")
        let textMenu = NSMenu()
        for entry in Settings.fontSizes {
            let it = NSMenuItem(title: entry.name, action: #selector(setFontSize(_:)), keyEquivalent: "")
            it.representedObject = entry.size
            it.state = abs(Settings.noteFontSize - entry.size) < 0.01 ? .on : .off
            textMenu.addItem(it)
        }
        textItem.submenu = textMenu
        menu.addItem(textItem)
        
        let sizeItem = NSMenuItem(title: L10n.string("context.deckSize"), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for entry in Settings.deckSizes {
            let it = NSMenuItem(title: entry.name, action: #selector(setDeckScale(_:)), keyEquivalent: "")
            it.representedObject = entry.scale
            it.state = abs(Settings.deckScale - entry.scale) < 0.01 ? .on : .off
            sizeMenu.addItem(it)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        
        let keepOpen = NSMenuItem(title: L10n.string("context.keepDeckOpen"),
                                  action: #selector(toggleDeckAlwaysShown), keyEquivalent: "")
        keepOpen.state = Settings.deckAlwaysShown ? .on : .off
        menu.addItem(keepOpen)
        
        let leftEdge = NSMenuItem(title: L10n.string("context.dockToLeft"),
                                  action: #selector(toggleDeckEdge), keyEquivalent: "")
        leftEdge.state = Settings.deckOnLeftEdge ? .on : .off
        menu.addItem(leftEdge)
        
        if NSScreen.screens.count > 1 {
            let displayItem = NSMenuItem(title: L10n.string("context.display"), action: nil, keyEquivalent: "")
            let displayMenu = NSMenu()
            
            let allItem = NSMenuItem(title: L10n.string("context.display.all"), action: #selector(setDisplayTarget(_:)), keyEquivalent: "")
            allItem.representedObject = "all"
            allItem.state = Settings.displayTarget == "all" ? .on : .off
            displayMenu.addItem(allItem)
            
            let mainItem = NSMenuItem(title: L10n.string("context.display.main"), action: #selector(setDisplayTarget(_:)), keyEquivalent: "")
            mainItem.representedObject = "main"
            mainItem.state = Settings.displayTarget == "main" ? .on : .off
            displayMenu.addItem(mainItem)
            
            displayMenu.addItem(.separator())
            
            for screen in NSScreen.screens {
                guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
                let name = screen.localizedName
                let title = screen == NSScreen.main ? "\(name) (Main)" : name
                let it = NSMenuItem(title: title, action: #selector(setDisplayTarget(_:)), keyEquivalent: "")
                it.representedObject = "id:\(id)"
                it.state = Settings.displayTarget == "id:\(id)" ? .on : .off
                displayMenu.addItem(it)
            }
            displayItem.submenu = displayMenu
            menu.addItem(displayItem)
        }
        
        let updates = NSMenuItem(title: L10n.string("context.checkUpdates"),
                                 action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(updates)
        
        let autoUpdate = NSMenuItem(title: L10n.string("context.checkAutomatically"),
                                    action: #selector(toggleAutoUpdates), keyEquivalent: "")
        autoUpdate.state = Updater.shared.automaticallyChecks ? .on : .off
        autoUpdate.isEnabled = Updater.available
        menu.addItem(autoUpdate)
        menu.addItem(.separator())
        
        let login = NSMenuItem(title: L10n.string("context.launchAtLogin"),
                               action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.state = Settings.launchAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        
        let exportItem = NSMenuItem(title: L10n.string("context.export"), action: nil, keyEquivalent: "")
        let exportMenu = NSMenu()
        exportMenu.addItem(withTitle: L10n.string("context.export.markdown"),
                           action: #selector(exportMarkdown), keyEquivalent: "")
        exportMenu.addItem(withTitle: L10n.string("context.export.plainText"),
                           action: #selector(exportPlainText), keyEquivalent: "")
        exportMenu.addItem(withTitle: L10n.string("context.export.singleFile"),
                           action: #selector(exportSingleFile), keyEquivalent: "")
        exportMenu.addItem(withTitle: L10n.string("context.export.stickies"),
                           action: #selector(exportStickies), keyEquivalent: "")
        exportItem.submenu = exportMenu
        menu.addItem(exportItem)
        menu.addItem(withTitle: L10n.string("context.import"), action: #selector(importStickies), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("context.settings"), action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: L10n.string("context.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        
        // Set target for all menu items
        for item in menu.items where item.action != nil {
            item.target = self
        }
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
}
