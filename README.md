# Mail Badge Notifier

### ⚠️ Important Notice Regarding Thunderbird 159.0+ Native Support

Starting with **Thunderbird 159.0**, Mozilla has introduced **native unread badge support** on Linux taskbars into the official codebase.

* **If you use clean Thunderbird 159.0+:** You may no longer need our extension (add-on) and background service for basic notifications, as the client now handles this natively when the window is open.
* **Why this project is still useful (and essential for Betterbird):**
  1. **Betterbird:** Betterbird does not yet have this native implementation to the same extent, so our tool provides a seamless system tray and synchronization setup.
  2. **True Headless Background Operation:** Thunderbird kills its process when you close the main window. Our `systemd` headless service allows mail monitoring and badge updates to continue **even when the main window is completely closed**, without profile locking conflicts.
  3. **Cairo-Dock and Alternative Panels:** Native implementations rely on standard desktop portals that often fail with specialized docks (like Cairo-Dock), whereas our code explicitly emits `com.canonical.Unity.LauncherEntry` signals.

*Conflict Warning:* If you run Thunderbird 159.0+ with native badges enabled and our extension simultaneously, duplicate D-Bus signals may occur. If you notice counter flickering, you can disable our WebExtension and rely on native support, or keep our toolkit if you require headless background operation.

Unread mail taskbar badges for **Thunderbird** and **Betterbird** on Linux, featuring a headless background `systemd` user service, a seamless GUI wrapper, XDG Base Directory compliance, and native messaging integration.

This project is a heavily refactored, modernized, and XDG-compliant fork of [bakatamas/mail-badge-bridge](https://github.com/bakatamas/mail-badge-bridge).

---

## Why This Exists

Thunderbird and Betterbird include an "App icon badge" setting, but on Linux, they do not natively output unread badge counts to the taskbar/dock out of the box. Desktop environments like KDE Plasma support these badges via the `com.canonical.Unity.LauncherEntry` D-Bus API. 

This project bridges that gap:
1. **WebExtension Add-on:** Monitors all configured mail inboxes and calculates the total unread message count.
2. **Native Python Helper:** Receives the total count via standard I/O (Native Messaging) and broadcasts `Unity.LauncherEntry` D-Bus signals.
3. **Smart Integration:** 
   - **Thunderbird:** Uses a headless `systemd` user service and a custom GUI wrapper script to keep unread badges updated even when the mail client window is closed, completely avoiding profile locking issues.
   - **Betterbird:** Leverages native system tray support ("Minimize/Close to Tray"), running without requiring background systemd services.

---

## Requirements

* **Thunderbird or Betterbird 128 or newer** (Installed natively via system package manager; Flatpak and Snap are *not supported* due to container sandboxing restrictions).
* **Linux Desktop Environment / Dock** supporting `Unity.LauncherEntry` badges (e.g., KDE Plasma 5/6, Cairo-Dock).
* **Python 3**, **Bash**, and **Systemd**.

---

## Installation

### Option A: Via AUR (Recommended for Arch Linux)

If you are on Arch Linux, install the package directly from the Arch User Repository:

```bash
yay -S mail-badge-notifier-git

Once installed from AUR, run the user-space installer for your mail client:
Bash

# For Thunderbird users:
/usr/share/mail-badge-notifier-git/install.sh --thunderbird

# For Betterbird users:
/usr/share/mail-badge-notifier-git/install.sh --betterbird

Option B: Manual Installation (Git Clone)

    Clone the repository:
    Bash

    git clone [https://github.com/salexandarz/mail-badge-notifier.git](https://github.com/salexandarz/mail-badge-notifier.git)
    cd mail-badge-notifier

    Run the installer script:
    Bash

    # For Thunderbird:
    ./install.sh --thunderbird

    # For Betterbird:
    ./install.sh --betterbird

Step 2: Install the Add-on Package

After running the installer script:

    Launch Thunderbird or Betterbird.

    Open Add-ons and Themes (Ctrl + Shift + A).

    Click the Gear icon (⚙) in the top right corner and select Install Add-on From File....

    Navigate to and select the compiled .xpi package located at:
    Plaintext

    ~/.local/share/mail-badge-notifier/mail-badge-bridge.xpi

    Confirm the installation.

    Restart your mail client once to finalize the native messaging bridge initialization.

Post-Installation Notes & Best Practices
1. Default Client Prompt (Thunderbird)

Because Thunderbird launches via a custom wrapper script (~/.local/bin/thunderbird) to handle background service toggling, it may ask to become the default mail client on startup.

    Do not click "Set as Default", as this will generate a userapp-Thunderbird-...desktop file that bypasses the wrapper.

    Instead, check "Always perform this check when starting Thunderbird" off and click Skip Integration (or set mail.shell.checkDefaultClient to false in Thunderbird`s Config Editor).

    To set default applications manually in KDE Plasma, go to:

        System Settings → Default Applications → Email client → Thunderbird.

        System Settings → File Associations → message/rfc822 → move Thunderbird to the top.

2. Betterbird System Tray Setup

Betterbird does not require a background systemd service. To keep unread badges active when the main window is closed:

    Open Betterbird Settings → General.

    Enable "When Betterbird is closed, move it to the tray".

3. Cairo-Dock Setup

If you use Cairo-Dock and the dock launcher does not switch to the wrapper executable properly:

    Right-click the app icon in Cairo-Dock.

    Select thunderbird (or betterbird) → Edit.

    Change Command to launch on click to:
    Plaintext

    ~/.local/bin/thunderbird

    Click Apply.

    Visibility Tip: In Cairo-Dock settings (Configure → Captions → Style: Custom), set background to black, outline to white, and text to white for optimal badge readability.

Uninstallation Procedure

To prevent orphaned processes or native host connection errors, follow this exact order:
1. Remove the Add-on in GUI

    Open Thunderbird / Betterbird.

    Go to Add-ons and Themes (Ctrl + Shift + A).

    Locate Mail Badge Bridge, click the ... menu, and select Remove.

    Close the application.

2. Run the Uninstaller Script

Run the uninstaller script based on your installation method:

    If installed manually or via AUR:
    Bash

    ~/.local/share/mail-badge-notifier/uninstall.sh

    If installed via AUR, clean up the package afterwards:
    Bash

    yay -Rns mail-badge-notifier-git

Troubleshooting
No badge appearing on the taskbar icon

    Check Native Host Logs in Mail Client:

        Press Ctrl + Shift + J in Thunderbird/Betterbird to open the Error Console.

        Filter logs by typing mail-badge-bridge.

        If you see "No such native application", re-run install.sh to fix the messaging host manifest link.

    Test Taskbar D-Bus Reception:
    Run the following command in terminal while your mail client is running to verify if your desktop panel supports Unity.LauncherEntry:
    Bash

    gdbus emit --session --object-path /test \
      --signal com.canonical.Unity.LauncherEntry.Update \
      "application://org.mozilla.Thunderbird.desktop" \
      "{'count': <int64 5>, 'count-visible': <true>}"

    If no badge with number 5 appears on your taskbar icon:

        Unpin the icon from your taskbar/dock.

        Launch Thunderbird/Betterbird directly from the application menu (~/.local/share/applications/).

        Pin the running window icon back to your taskbar.

    Monitor D-Bus Signal Traffic:
    To watch live signals emitted by the Python helper:
    Bash

    dbus-monitor "interface='com.canonical.Unity.LauncherEntry'"

    Check Systemd Service (Thunderbird only):
    Bash

    systemctl --user status thunderbird.service
    journalctl --user -u thunderbird.service -f

Limitations

    Flatpak / Snap: Sandboxed applications cannot execute native messaging helpers outside their runtime container.

    GNOME Desktop: Stock GNOME Dash does not natively support Unity.LauncherEntry badges unless an extension with launcher entry support is enabled.

Credits & License

    Refactored, modernized, packaged, and custom headless service developed by Aleksandar Zarić (salexandarz).

    Original implementation by Baka Tamás and Claude (Anthropic) as mail-badge-bridge.

    Distributed under the MIT License.
