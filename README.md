# Mail Badge Notifier

Unread mail taskbar badges for **Thunderbird** and **Betterbird** on Linux, featuring a headless background `systemd` user service, a seamless GUI wrapper, XDG Base Directory compliance, and native messaging integration.

### ⚠️ Important Notice Regarding Thunderbird 159.0+

Starting with **Thunderbird 159.0**, Mozilla added basic unread indicators to Linux system tray icons (showing unread status and count in the hover tooltip on supported X11/AppIndicator setups). However, **mail-badge-notifier** remains essential for modern Linux desktops—especially **KDE Plasma 6 on Wayland**—for several key reasons:

1. **Taskbar / Dock Numeric Badges (`Unity.LauncherEntry`):** Thunderbird 159.0+ still does not emit `com.canonical.Unity.LauncherEntry` D-Bus signals to display numeric unread counters directly on your taskbar or dock icon.
2. **KDE Plasma & Wayland Tray Limitations:** On pure Wayland sessions (such as KDE Plasma 6), Thunderbird's native system tray option is unavailable/hidden because it relies on legacy GTK/X11 tray mechanisms rather than Freedesktop `StatusNotifierItem` (SNI).
3. **True Headless Background Operation:** Standard Thunderbird terminates its process when you close the main window. Our `systemd` user service allows mail monitoring and badge updates to continue **even when the main window is completely closed**, without profile locking conflicts.
4. **Betterbird & Cairo-Dock Support:** Betterbird users and specialized docks (like Cairo-Dock) rely on explicit `Unity.LauncherEntry` D-Bus signals provided by this bridge.

*Compatibility Note:* Tested in production with Thunderbird 159.0+ on Arch Linux / KDE Plasma (Wayland) with zero D-Bus signal conflicts or counter flickering.

---

## How It Differs from Birdtray and SysTray-X

While tools like **Birdtray** and **SysTray-X** focus on adding a **System Tray icon** and managing window visibility (*Close/Minimize to Tray*), **mail-badge-notifier** takes a different architectural approach designed for modern Linux desktops (such as KDE Plasma 6 and Wayland):

- **Taskbar / Dock Badge vs. System Tray:**
  `mail-badge-notifier` updates the unread counter badge directly on your main application icon in the taskbar or dock (`Unity.LauncherEntry` D-Bus signal), rather than placing a separate icon in the system tray (`StatusNotifierItem`).
- **True Headless Operation:**
  Unlike Birdtray and SysTray-X—which require the full Thunderbird or Betterbird GUI process to remain open and hidden in RAM—`mail-badge-notifier` decouples unread tracking into a lightweight background `systemd` user service. You can completely close the mail client window and still receive live badge updates.
- **Native Wayland & KWin Compatibility:**
  Because it never attempts to hide, minimize, or manipulate application windows, it requires no KWin scripts or X11 fallbacks and works seamlessly across Wayland and X11 compositors.
- **Accurate Unread Count:**
  Instead of parsing binary `.msf` index files from disk (which can desync during folder compaction), it reads the exact unread count directly via the WebExtension API and background bridge.

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

- **Thunderbird or Betterbird 128 or newer** (Installed natively via system package manager; Flatpak and Snap are *not supported* due to container sandboxing restrictions).
- **Linux Desktop Environment / Dock** supporting `Unity.LauncherEntry` badges (e.g., KDE Plasma 5/6, Cairo-Dock).
- **Python 3**, **Bash**, and **Systemd**.

---

## Installation

### Option A: Via AUR (Recommended for Arch Linux)

If you are on Arch Linux, install the package directly from the Arch User Repository:


yay -S mail-badge-notifier-git

Once installed from AUR, run the user-space installer for your mail client:

# For Thunderbird users:
/usr/share/mail-badge-notifier-git/install.sh --thunderbird

# For Betterbird users:
/usr/share/mail-badge-notifier-git/install.sh --betterbird

### Option B: Manual Installation (Git Clone)
1.    Clone the repository:

git clone https://github.com/salexandarz/mail-badge-notifier.git
cd mail-badge-notifier

2.    Run the installer script:

# For Thunderbird:
./install.sh --thunderbird

# For Betterbird:
./install.sh --betterbird

## Installation Step 2:

### Install the Add-on Package

After running the installer script:

1.    Launch Thunderbird or Betterbird.

2.    Open Add-ons and Themes (Ctrl + Shift + A).

3.    Click the Gear icon (⚙) in the top right corner and select Install Add-on From File....

4.    Navigate to and select the compiled .xpi package located at:

~/.local/share/mail-badge-notifier/mail-badge-bridge.xpi

5.    Confirm the installation.

6.    Restart your mail client once to finalize the native messaging bridge initialization.


Post-Installation Notes & Best Practices
1. Default Client Prompt (Thunderbird)

Because Thunderbird launches via a custom wrapper script (~/.local/bin/thunderbird) to handle background service toggling, it may ask to become the default mail client on startup.

*    Do not click "Set as Default", as this will generate a userapp-Thunderbird-...desktop file that bypasses the wrapper.

*    Instead, uncheck "Always perform this check when starting Thunderbird" and click Skip Integration (or set mail.shell.checkDefaultClient to false in Thunderbird's Config Editor).

*    To set default applications manually in KDE Plasma, go to:

     *   System Settings → Default Applications → Email client → Thunderbird

     *   System Settings → File Associations → message/rfc822 → move Thunderbird to the top

2. Betterbird System Tray Setup

Betterbird does not require a background systemd service. To keep unread badges active when the main window is closed:

1.    Open Betterbird Settings → General.

2.    Enable "When Betterbird is closed, move it to the tray".

3. Cairo-Dock Setup

If you use Cairo-Dock and the dock launcher does not switch to the wrapper executable properly:

1.    Right-click the app icon in Cairo-Dock.

2.    Select thunderbird (or betterbird) → Edit.

3.    Change Command to launch on click to:

~/.local/bin/thunderbird

4.    Click Apply.

5.    Visibility Tip: In Cairo-Dock settings (Configure → Captions → Style: Custom), set background to black, outline to white, and text to white for optimal badge readability.

Uninstallation Procedure

To prevent orphaned processes or native host connection errors, follow this exact order:
1. Remove the Add-on in GUI

1.    Open Thunderbird / Betterbird.

2.    Go to Add-ons and Themes (Ctrl + Shift + A).

3.    Locate Mail Badge Bridge, click the ... menu, and select Remove.

4.    Close the application.

2. Run the Uninstaller Script

Run the uninstaller script based on your installation method:

# If installed manually or via AUR:
~/.local/share/mail-badge-notifier/uninstall.sh

# If installed via AUR, clean up the package afterwards:
yay -Rns mail-badge-notifier-git

Troubleshooting
No badge appearing on the taskbar icon

1.    Check Native Host Logs in Mail Client:

      *  Press Ctrl + Shift + J in Thunderbird/Betterbird to open the Error Console.

      *  Filter logs by typing mail-badge-bridge.

      *  If you see "No such native application", re-run install.sh to fix the messaging host manifest link.

2.    Test Taskbar D-Bus Reception:
    Run the following command in terminal while your mail client is running to verify if your desktop panel supports Unity.LauncherEntry:
    
    gdbus emit --session --object-path /test \
  --signal com.canonical.Unity.LauncherEntry.Update \
  "application://org.mozilla.Thunderbird.desktop" \
  "{'count': <int64 5>, 'count-visible': <true>}"
  
  If no badge with number 5 appears on your taskbar icon:

   * Unpin the icon from your taskbar/dock.

   * Launch Thunderbird/Betterbird directly from the application menu (~/.local/share/applications/).

   * Pin the running window icon back to your taskbar.

3.    Monitor D-Bus Signal Traffic:
To watch live signals emitted by the Python helper:

dbus-monitor "interface='com.canonical.Unity.LauncherEntry'"

4.    Check Systemd Service (Thunderbird only):

systemctl --user status thunderbird.service
journalctl --user -u thunderbird.service -f

Limitations

   * Flatpak / Snap: Sandboxed applications cannot execute native messaging helpers outside their runtime container.

   * GNOME Desktop: Stock GNOME Dash does not natively support Unity.LauncherEntry badges unless an extension with launcher entry support is enabled.

Credits & License

   * Refactored, modernized, packaged, and custom headless service developed by Aleksandar Zarić (salexandarz).

   * Original implementation by Baka Tamás and Claude (Anthropic) as mail-badge-bridge.

   * Distributed under the MIT License.
