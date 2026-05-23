# tprofile

An [Oh My Zsh](https://ohmyz.sh/) plugin to manage per-client terminal
profiles. Each profile gets its own **segregated zsh history**, its own
**`rc.zsh`** (environment variables, aliases, custom `PATH`, …), and a clear
**visual distinction** (a matching Terminal.app color profile, a tab title and a
yellow prompt badge). Built for people juggling several clients or personal
projects in the same terminal without cross-contaminating contexts.

## Requirements

- macOS with **Terminal.app** or **iTerm2** for the color switching; everything
  else works on any platform (the plugin only ever talks to the terminal you are
  actually running in, so iTerm2 never pokes Terminal.app and vice versa).
- **zsh** 5.9+ with **Oh My Zsh**.
- No external dependencies beyond what ships with macOS (`zsh`, `osascript`).

## Installation

### With `install.sh`

```sh
git clone https://github.com/Robyt96/tprofile.git tprofile
cd tprofile
./install.sh
```

The installer symlinks (or copies) the plugin into
`$ZSH_CUSTOM/plugins/tprofile`. It **does not** edit your `~/.zshrc`; it prints
the line to add.

### Manual

```sh
git clone https://github.com/Robyt96/tprofile.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/tprofile"
```

Then enable it by adding `tprofile` to the plugins list in `~/.zshrc`:

```sh
plugins=(... tprofile)
```

Reload your shell:

```sh
exec zsh
```

## Color profiles (manual setup)

The plugin never creates terminal profiles for you. To get per-client colors,
create the matching profiles by hand, **named exactly like your tprofile
profile** (e.g. `acme`).

**Terminal.app**
1. Open **Terminal → Settings… → Profiles**.
2. Duplicate a profile (or create a new one) and customize its colors.
3. Name it exactly like your tprofile profile.

**iTerm2**
1. Open **iTerm2 → Settings… → Profiles**.
2. Duplicate a profile (or create a new one) and customize its colors.
3. Name it exactly like your tprofile profile.

When you run `tprofile use acme` / `tprofile window acme`, the plugin switches
the current terminal to the profile named `acme`. On iTerm2 this uses iTerm2's
native escape sequence (no automation permission needed); on Terminal.app it
uses AppleScript. If no matching profile exists, nothing breaks — you just don't
get the colors.


## Usage

```sh
tprofile new acme        # create a profile + a default rc.zsh
tprofile list            # list profiles (alias: tprofile ls)
tprofile use acme        # activate acme in the current shell (re-execs zsh)
tprofile window acme     # open a NEW Terminal window already in acme
tprofile edit acme       # edit acme's rc.zsh with $EDITOR (fallback: vi)
tprofile current         # print the active profile, or "(none)"
tprofile remove acme     # remove acme + its history (asks to confirm; alias: rm)
tprofile help            # show help (also -h / --help)
```

Tab completion is provided for the subcommands and, for
`use`/`window`/`edit`/`remove`/`rm`, for the existing profile names:

```sh
tprofile use <TAB>
```

A profile is just a directory:

```
$TPROFILE_DIR/<name>/rc.zsh
```

Put any per-client configuration in `rc.zsh`; it is sourced automatically while
the profile is active. The profile's history lives in
`~/.zsh_history_<name>`, fully separate from your default history and from other
profiles.

## Environment variables

| Variable             | Default                    | Meaning                                              |
| -------------------- | -------------------------- | ---------------------------------------------------- |
| `TPROFILE_DIR`       | `~/.config/term-profiles`  | Where profiles are stored. Created automatically.    |
| `TPROFILE_NO_PROMPT` | _(unset)_                  | Set to `1` to disable the yellow `[profile]` prompt badge. |
| `TERM_PROFILE`       | _(set by `tprofile use`)_  | The active profile. Read by the plugin on startup.   |

## Compatibility

- The **color switching** works on macOS with **Terminal.app** and **iTerm2**.
  The backend is detected from `$TERM_PROGRAM` (and `$LC_TERMINAL`, so it also
  works through tmux/ssh into iTerm2). Other terminals just skip the colors.
- The **history segregation**, **`rc.zsh` sourcing**, **tab title** and
  **prompt badge** work in any zsh + Oh My Zsh environment; only the colors
  require Terminal.app or iTerm2.
- `tprofile window` is supported on Terminal.app and iTerm2; on other terminals
  it reports that it is unsupported instead of opening the wrong app.

## Troubleshooting

**The prompt badge doesn't appear (Powerlevel10k).**
Powerlevel10k builds `$PROMPT` itself on every prompt, so the badge prepended by
this plugin gets overwritten. Options:
- Rely on the **tab title** and the **Terminal color** for visual distinction,
  and set `TPROFILE_NO_PROMPT=1` to hide the (ineffective) badge.
- Or add a small custom segment to your P10k config that shows `$TERM_PROFILE`,
  e.g. a `prompt_my_tprofile` function returning `[$TERM_PROFILE]` added to
  `POWERLEVEL9K_LEFT_PROMPT_ELEMENTS`.

**The colors don't change.**
The plugin switches to the terminal profile whose **name matches exactly** the
tprofile name. Check **Settings → Profiles** in Terminal.app or iTerm2 and make
sure a profile named exactly like your tprofile (case-sensitive, e.g. `acme`)
exists. If it doesn't, the switch is ignored silently and the colors stay as
they are.

**It asked permission to control Terminal while I was in iTerm2.**
That was a bug in earlier versions, now fixed: the plugin detects the terminal
from `$TERM_PROGRAM`/`$LC_TERMINAL` and only talks to the emulator you are
actually in. On iTerm2, `tprofile use` switches profile via iTerm2's escape
sequence and needs **no** automation permission. (Opening a *new* window with
`tprofile window` still uses AppleScript on both terminals, so the first
`window` may prompt once to allow controlling that app — that part is
unavoidable when one app spawns a window in another.)

## License

MIT — see [LICENSE](LICENSE).
