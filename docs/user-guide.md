# Get comfortable with Paper

Paper puts a paper texture over your Mac's displays. Your apps still work as usual: you can click, type, scroll, and move windows through it. Your documents stay exactly as they were. The computer is simply wearing a little paper.

It works on Apple Silicon Macs with macOS 13 or later. **Free and open source. Always.** All 26 built-in textures come from [Deckle](https://github.com/YellowFoxH4XOR/deckle), whose contributors made the texture renderer and paper catalog that Paper uses. Thank you, Deckle.

For a first try, install Paper, leave **Soft Wove** selected, and adjust **Intensity** while looking at something you actually read. You can leave the rest alone until you want it.

Looking for a particular control?

- [Install and find Paper](#install)
- [Texture, intensity, and grain](#pick-a-paper)
- [Favorites and saved looks](#favorites-and-saved-looks)
- [Schedules, automatic looks, and battery rules](#make-it-fit-your-day)
- [Pause, snooze, and app exclusions](#pause-or-get-out-of-the-way)
- [Displays, desk profiles, Desk Lamp, and the reading strip](#a-few-extra-controls)
- [Keyboard shortcuts and Apple's Shortcuts app](#shortcuts)
- [Import papers and back up your collection](#bring-your-own-paper)
- [Privacy, updates, and help](#privacy-and-help)

## Install

1. Download the current DMG from [Paper releases](https://github.com/aindaco1/paper/releases/latest). A DMG is the disk image that holds the app.
2. Open it and drag **Paper** into **Applications**.
3. Open Paper from Applications. Its Settings window opens, and a Paper icon appears in the menu bar at the top of your screen.

The **Enable Paper** switch turns the effect on and off. Try it a couple of times to compare the texture with your original screen. Closing Settings leaves Paper running; click its menu-bar icon and choose **Settings…** to get back. **Quit Paper** stops the app and removes the effect.

If you'd like Paper to start when you sign in to your Mac, turn on **Launch at login** under **Preferences**. If macOS asks for approval, use **Approve in Login Items…** to finish that step. Starting at login doesn't mean Paper ignores your pause rules.

### Keeping it up to date

Choose **Check for Updates…** from the menu bar or **Updates & support** in Settings. Paper can check automatically, but installing an update still requires your action. You can turn automatic checks off in Settings.

If you're coming from version 0.3.0 or earlier, download and install a current copy manually once to get the built-in updater. Quit a pre-1.0 copy before replacing it.

## Pick a paper

Open **Your paper** in Settings and choose a **Texture**. Soft Wove is the starting point; the other papers have different tints and surface details. Try them over a document, a website, and a dark window. A texture you like on a blank page may feel stronger over a busy screen.

**Intensity** controls how much paper you see. Lower it for a faint surface, or raise it for a more noticeable effect. The range is 5–45%; you don't have to fill the slider to get your money's worth. When you return to a texture, Paper remembers the intensity you last used for it.

**Grain** changes the size of the texture's detail. Choose **Fine** for smaller detail, **Natural** for its original scale, or **Coarse** for larger detail. This doesn't change your Mac's display resolution or the size of your text.

If Intensity and Grain are unavailable, an automatic or app-specific saved look is currently supplying those settings. Select a texture or apply a saved look manually to leave automatic switching and adjust it yourself.

## Favorites and saved looks

A **favorite** is a texture you want to find quickly. Click **Favorite** beside the current paper. Favorites move to the top of the texture picker and appear in the menu bar's **Favorites** menu. Click the star again to remove one from that list.

A **saved look** keeps a texture, its intensity, and its grain settings together. You might save a faint Soft Wove as “Writing” and a stronger Book Cream as “Evening reading.”

To make one, get the paper how you like it, then choose **Saved looks → Save current look…** and give it a name. Select that name from **Saved looks** to use it again. Paper keeps up to eight looks; saving with an existing name replaces that look. **Saved looks → Remove look** lets you clear one you no longer use.

Saved looks don't include every setting in Paper. In particular, a display's custom intensity stays independent, and applying a look doesn't turn Paper on or cancel a pause.

## Make it fit your day

### Show paper at certain times

Under **When to show it**, turn on **Use a daily schedule**. The schedule decides when the effect is allowed to appear.

For fixed times, set **From** and **To** using your Mac's local time. A window from 6 PM to 7 AM works overnight. Matching start and end times keep Paper available all day. Turning Paper off yourself still takes priority over the schedule.

You can also use sunrise to sunset, or sunset to sunrise. Choose **Choose city…**, enter a city and country, click **Find**, and select the result. Paper calculates the sun times for that city and its time zone. It doesn't follow your location when you travel, so change the city if you want the schedule to match somewhere new.

City lookup uses Apple's service. Once the city is chosen, the sun times are calculated on your Mac; no location permission is needed. A solar schedule needs a selected city before it can show Paper.

### Change the look as the day changes

**Automatic day/night looks** chooses which saved look to use. It can run with or without a daily schedule. For example, you can leave Paper available all day and use a different paper after sunset.

Save two looks first, then turn on **Automatic day/night looks** and choose **Switch with**:

- **Sunrise and sunset:** assign a **Day look** and a **Night look**, and choose a city.
- **macOS appearance:** assign a **Light look** and a **Dark look**. Paper follows your Mac's light or dark appearance; it doesn't change that setting for you.

Choose both looks to finish the setup. Selecting a texture or applying a look manually turns automatic switching off, so your choice stays put. Turn it back on when you want Paper to take over again.

### Give an app its own look

Under **App-specific looks**, choose **Assign a look to an app…**, select the app, and assign a saved look. **Use app-specific looks** enables the assignments. You could use a quiet paper while writing in Notes and a different one while reading in your browser.

The assigned look follows the app you're actively using and appears across your enabled displays. It isn't attached to just that app's window. When you switch to an app without an assignment, Paper uses your day/night look if that feature is enabled, or your usual manual settings otherwise.

An app-specific look takes priority over a day/night look. It cannot override an app exclusion or another pause rule. Manual texture or saved-look selection turns off app-specific switching too; your assignments remain available to enable again.

### Let battery rules handle a pause

There are three separate choices under **When to show it**:

- **Pause on battery** hides the effect whenever your Mac is unplugged and running on battery.
- **Pause in Low Power Mode** follows macOS Low Power Mode.
- **Pause at low battery** hides it at or below the percentage you choose, while running on battery. The starting threshold is 20%.

For example, leave Pause on battery off and use a 20% threshold if you want paper while unplugged but prefer to pause near the end of the battery. Plugging in or getting above the threshold removes that reason to pause. Other rules, such as a snooze or an excluded app, can still keep the effect hidden.

## Pause or get out of the way

You don't need to visit Settings every time. The menu-bar icon gives you the current status, on/off, snooze, favorites, the reading strip, and presentation pause.

### Off, snooze, or presentation pause?

Use **Turn Paper off** when you want it off until you choose otherwise. You can also use the Enable Paper switch or your toggle shortcut.

**Snooze** is a timed break: 15 minutes, 30 minutes, one hour, two hours, or until tomorrow at 6 AM. **Custom duration…** accepts 1–1,440 minutes. Choose **End snooze** to finish early. The deadline survives quitting and reopening Paper; reopening doesn't start the timer over.

**Pause for presentation** is a break you end yourself. Choose it before sharing your screen, recording, taking screenshots, checking colors, or opening a protected authorization prompt. When you're finished, choose **End presentation pause**. This pause also survives quitting and reopening the app.

Always check your sharing or recording preview. Capture tools handle overlays differently, so Paper doesn't promise that an active texture will be invisible to them. Presentation pause removes the texture and optional lighting together.

### Keep particular apps clear

Under **Pause in these apps**, click **Add app…** and select an app. Paper pauses while that app is active, then can return when you switch away. This is useful for a photo editor, a video editor, or anywhere you need an unmodified view. Excluded apps' floating panels also stay above the texture.

If you only want Paper in a few apps, turn on **Only show in selected apps** under **App rules**, then use **Add selected app…** to build your list. With an empty list, the effect won't appear anywhere. If an app is in both lists, its exclusion wins.

Paper also hides the texture in Mission Control so you can see your Spaces previews. It stays visible while revealing the Dock or using Command-Tab.

### Paper is on, but where did it go?

Read the status at the top of Settings or the menu. It may say **Waiting for your schedule**, **Paused on battery**, or **Waiting for a selected app**. Enable Paper allows the effect to run; the other controls decide whether it should be visible right now.

Check for a snooze or presentation pause, an excluded app, the daily schedule, and battery rules. If every display is switched off under Displays, enable the one you want. Ending one pause doesn't cancel the others. You shouldn't have to reset your favorite paper to sort this out.

## A few extra controls

### Choose which displays get paper

Under **Displays**, each connected screen has its own switch. Leave your laptop display textured and keep an external display clear, for example.

Turn on **Custom intensity** for a display to give it a separate intensity slider. This helps when the same paper looks stronger on one screen than another. Turn Custom intensity off to use the current look's intensity again. Choosing a new texture or saved look doesn't erase a display's custom intensity.

### Remember a desk setup

**Desk profiles** save the texture and rules for a particular set of connected displays. Set things up, enter a **Desk name**, and click **Save this setup**. Paper recalls it when those same displays reconnect or when Paper launches with them attached.

A profile matches the actual displays, not just the number of screens. You could keep a setup for your laptop alone and another for your desk monitor. Later adjustments aren't silently saved into the profile: click Save this setup again to replace the profile for that display arrangement.

Recalling a desk doesn't undo manual off, your current display exclusions, snooze, or presentation pause. Desk profiles stay on this Mac and aren't included in library exports.

### Add a little warmth with Desk Lamp

Expand **Desk Lamp** under **Surface options**, then turn on **Warm ambient light**. **Warmth** changes the tint; **Strength** changes how much of it you see. The wash is blended with your paper intensity, so a very faint paper also makes for a faint lamp.

This is a static wash of color over the display. It doesn't move with the pointer or change your Mac's brightness setting. Pause Paper for color-sensitive work, including judging a photograph's color. A cozy yellow cast is still a yellow cast.

### Use the reading strip

Choose **Show reading strip** from the menu bar to leave a clear horizontal band through the paper and Desk Lamp. Under **Surface options → Reading strip**, adjust **Strip height** and **Strip position (bottom to top)** to place it where you want.

The strip stays where you put it; it doesn't follow your pointer or scroll along with a document. It appears on each enabled display. You can assign shortcuts to move it up and down, and choose **Hide reading strip** when you're done. It follows Paper's normal pause rules.

## Shortcuts

### Keep a few controls on the keyboard

The default toggle is **Shift–Option–Command–P** (⇧⌥⌘P). It turns Paper on or off without opening the menu.

Under **Shortcuts** in Settings, turn on **Enable global shortcuts**, then click the combination beside a command to change it. You can also assign keys for a 15-minute snooze, the next favorite, moving the reading strip up or down, and presentation pause. Those extra commands start unassigned.

Choose a letter key and include Command or Control. The bindings use the physical A–Z keys, which matters if you switch keyboard layouts. If Paper reports a shortcut conflict, choose another combination. You can clear an optional shortcut or restore the default toggle.

### Put Paper into an Apple shortcut

In Apple's **Shortcuts** app, search for Paper when adding an action. Paper provides **Toggle Paper**, **Set Paper Enabled**, **Snooze Paper**, **Select Paper Texture**, and **Apply Paper Look**.

For a simple writing shortcut, open your writing app, select your saved “Writing” look with Apply Paper Look, and add Set Paper Enabled with Enabled on. That gives the shortcut a predictable result; Toggle Paper flips whatever state you're already in.

These actions use the same controls as the app. Selecting a texture or look ends automatic switching. Enabling Paper clears a snooze, but presentation pause, app exclusions, schedules, and battery rules still apply.

## Bring your own paper

### Import a texture recipe

**Import paper…** in Your paper accepts Deckle-compatible JSON recipes, including files ending in `.decklepaper.json`. Think of a recipe as the instructions for drawing a texture. You don't need to read or edit the file to use one, and a photo or wallpaper image won't work in its place.

Save a recipe to your Mac, choose Import paper…, and select the file. You can select several at once. Paper keeps up to 50 custom papers, with a 1 MB limit per file. If one file can't be imported, Paper reports it; other valid files in that selection can still be added.

To try an example, open [Soft Linen](examples/soft-linen.decklepaper.json) on GitHub and use **Download raw file**. Import the downloaded `.decklepaper.json` file into Paper. To remove a custom paper, select it and choose **Remove imported paper**. The built-in Deckle collection stays available.

### Back up your collection

Under **Library backup**, choose **Export library…** and save the file somewhere you keep backups. It includes your custom papers, favorites, and saved looks.

**Import library…** adds that collection to what you already have. It doesn't wipe the current collection, and importing an unchanged backup again doesn't make another copy of everything. If a backup is invalid or would exceed the collection limits, the import leaves the collection unchanged.

A library backup isn't a backup of every preference: it leaves out your city, app rules, display setup, desk profiles, and keyboard shortcuts. Set those up separately on another Mac. For file details and examples, see [recipes and backups](recipes.md).

## Privacy and help

Paper doesn't capture what's on your screen, and it doesn't need Accessibility, Input Monitoring, or Screen Recording permission. Your settings and recipes stay on your Mac. It draws an overlay rather than changing the display's underlying color settings.

City searches use Apple's service, update checks use GitHub, and diagnostic reports are only sent after you review them and choose **Send**. The [privacy page](privacy.md) explains those connections.

If something isn't behaving, choose **Help & diagnostics…** from Settings or the menu bar, or start with [Get help](support.md). Include what you were trying to do and what happened instead. For sensitive security reports, use the private channel in [Security](../SECURITY.md).
