import SwiftUI
import Foundation

@main
struct ScrollToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

func copyCommandToClipboard(enable: Bool) {
    let command = "defaults write NSGlobalDomain com.apple.swipescrolldirection -bool \(enable ? "true" : "false")"

    // 클립보드에 텍스트 복사
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(command, forType: .string)
    
    print("Command copied to clipboard: \(command)")
}

func runAutomatorWorkflow(workflowName: String) {
    // 워크플로우 파일의 경로를 찾음
    if let workflowPath = Bundle.main.path(forResource: workflowName, ofType: "workflow") {
        // Process 객체 생성
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env") // /usr/bin/env 사용하여 npx와 같은 명령어도 호출 가능
        task.arguments = ["automator", workflowPath]  // 터미널 명령어 실행
        
        print("Executing: automator \(workflowPath)")
        
        do {
            try task.run()  // 명령어 실행
            task.waitUntilExit()  // 실행이 끝날 때까지 대기
            print("\(workflowName).workflow executed successfully.")
        } catch {
            print("Error running Automator workflow: \(error)")
        }
    } else {
        print("\(workflowName).workflow file not found in the bundle.")
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var naturalScrollMenuItem: NSMenuItem?
    var timer: Timer?
    var lastKnownState: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "scroll", accessibilityDescription: "Toggle Scroll")
        }

        let menu = NSMenu()

        let stateMenuItem = NSMenuItem(title: "Current State: Loading...", action: nil, keyEquivalent: "")
        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)
        self.naturalScrollMenuItem = stateMenuItem

        menu.addItem(NSMenuItem(title: "Toggle Natural Scrolling", action: #selector(toggleScrolling), keyEquivalent: "T"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "Q"))

        statusItem?.menu = menu
        updateScrollState()
        startPolling()
    }

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateScrollState()
        }
    }

    @objc func toggleScrolling() {
        let script = """
        defaults read -g com.apple.swipescrolldirection
        """
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if output == "1" {
            // If it's enabled, disable it
            copyCommandToClipboard(enable: false)
            toggleScrollDirection()
            runAutomatorWorkflow(workflowName: "off")

            
            print("1")
        } else {
            // If it's disabled, enable it
            copyCommandToClipboard(enable: true)
            toggleScrollDirection()
            runAutomatorWorkflow(workflowName: "on")
            print("2")
        }
    }

    func toggleScrollDirection() {
        

        updateScrollState()
    }

    func updateScrollState() {
        let script = """
        defaults read -g com.apple.swipescrolldirection
        """
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
            if self.lastKnownState != output {
                self.lastKnownState = output
                if output == "1" {
                    self.naturalScrollMenuItem?.title = "Current State: Enabled"
                } else if output == "0" {
                    self.naturalScrollMenuItem?.title = "Current State: Disabled"
                } else {
                    self.naturalScrollMenuItem?.title = "Current State: Unknown"
                }
            }
        }
    }

    @objc func quitApp() {
        timer?.invalidate()
        NSApp.terminate(nil)
    }
}
