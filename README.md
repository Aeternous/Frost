# Frost

A free menu-bar app for MacBooks that turns the screen into a sheet of frosted glass as you close the lid.

As the lid tips down, your screen blurs in place under a glossy glass pane shaped like the display itself, rounded corners and camera notch included. The further you close it, the stronger the blur and the brighter the glass. Stop moving the lid and it fades back to normal.

## Requirements

- A MacBook with a **lid angle sensor**: 14″ and 16″ MacBook Pro, or MacBook Air M2 and later. On other Macs, Frost shows "No lid angle sensor found" and does nothing.
- macOS 13 Ventura or later, Apple silicon.
- **Screen Recording** permission (see below).

## Download

### Option 1: Download the app

1. Open the [latest release](../../releases/latest) and download `Frost.zip`.
2. Unzip it and drag **Frost.app** into your **Applications** folder.
3. Open Frost. macOS will block it the first time, because the app isn't notarized by Apple (that costs $99 a year, and Frost is free). To allow it:
   - open **System Settings → Privacy & Security**,
   - scroll down to the message about Frost and click **Open Anyway**,
   - confirm with your password or Touch ID.

   You only need to do this once.

### Option 2: Build it yourself

You need Apple's free command-line tools. If you don't have them, run `xcode-select --install`.

```bash
git clone https://github.com/Aeternous/Frost.git
cd Frost
./build.sh
open /Applications/Frost.app
```

`build.sh` compiles the app and installs it into `/Applications`. An app you build yourself opens without the security warning.

### Allow Screen Recording

Frost needs to see your screen in order to blur it. The first time it runs, macOS asks for **Screen Recording** permission:

1. Open **System Settings → Privacy & Security → Screen & System Audio Recording** and switch on **Frost**.
2. Quit Frost (menu-bar icon → Quit Frost, or ⌃⌥⌘Q) and open it again.

Frost never saves, records or sends anything. Each frame is blurred, shown, and thrown away.

## Shortcuts

All shortcuts use **Control + Option + Command** and work from any app.

| Shortcut | Action |
|---|---|
| **⌃⌥⌘E** | Turn the effect on or off |
| **⌃⌥⌘R** | Reset the resting angle (where Frost thinks your lid normally sits) |
| **⌃⌥⌘P** | Preview the effect for 5 seconds |
| **⌃⌥⌘Q** | Quit Frost |

The same actions are in the menu-bar icon's menu, which also shows the current lid angle.

## How it behaves when you tilt the lid

- **It only shows while the lid is moving.** Frost doesn't stay blurred. If you stop moving the lid partway, even while it's half closed, the glass fades back to the normal screen after about a second.
- **Picking up where you left off:** if you pause and then keep closing within a few seconds, the glass comes back at the same strength and keeps building.
- **Small adjustments are ignored.** Moving the lid less than about 6° does nothing, so nudging the screen while you work won't set it off.
- **"Normal" is where the lid last settled.** After the lid has been still for about 8 seconds, that angle becomes the new resting position. Briefly opening the lid wider and setting it back doesn't count as closing.
- **Opening the lid back up** reduces the effect as you go.
- **Only the built-in display** gets the effect, never external monitors.
- **It doesn't interfere with your work.** Clicks and typing pass straight through the glass, and it's hidden from screen sharing and screen recordings.
- **Screen-recording indicator:** while the lid is moving, macOS briefly shows its screen-recording indicator in the menu bar. That's Frost capturing the screen to blur it, and it stops a few seconds after the lid settles.
- If the effect ever triggers at your normal angle, press **⌃⌥⌘R** to reset the resting angle.

## How it works

| File | What it does |
|---|---|
| `Sources/LidSensor.swift` | Reads the hinge angle from the MacBook's built-in lid angle sensor (an Apple HID sensor device), 60 times a second. |
| `Sources/TiltTracker.swift` | Turns raw angles into "how far has the lid closed from where it normally sits" and "is it moving right now". |
| `Sources/ScreenMirror.swift` | Captures the built-in display with ScreenCaptureKit, only while the lid is moving, and leaves Frost's own window out of the capture. |
| `Sources/GlassOverlay.swift` | A click-through window over the display. It blurs each captured frame with Core Image and draws a glass pane on top: a bright edge that traces the display's rounded corners and notch, a glow fading down from the top, faint side edges and a soft shadow. As the lid closes, the blur deepens and the pane's bottom edge draws in slightly, like a sheet of glass tipping toward you. |
| `Sources/Hotkeys.swift` | Registers the ⌃⌥⌘ shortcuts. |
| `Sources/main.swift` | The menu-bar app: wires everything together and runs the update loop. |

## License

[MIT](LICENSE): free to use, change and share.
