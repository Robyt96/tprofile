# Manual testing checklist

These checks are meant to be run by hand in **Terminal.app** on macOS after the
plugin is installed and enabled (`plugins=(... tprofile)` then `exec zsh`).

1. **Create a profile.** `tprofile new acme` → creates the directory
   `~/.config/term-profiles/acme/` and an `rc.zsh` inside it.

2. **Idempotent create.** `tprofile new acme` again → warns that it already
   exists, exits 0, and does **not** overwrite `rc.zsh`.

3. **List.** `tprofile list` → shows `acme`.

4. **Activate.** `tprofile use acme` → a new shell where:
   - the prompt shows `[acme]` (unless `TPROFILE_NO_PROMPT=1`),
   - the tab title shows `[acme] <cwd>`,
   - `echo $HISTFILE` → `~/.zsh_history_acme`.

5. **History persists within the profile.** Run a command, `exit`, re-enter with
   `tprofile use acme`, press the up arrow → the previous command is there.

6. **History is segregated.** Open a normal shell (`exit` the profile), press the
   up arrow → the `acme` command is **not** there.

7. **rc.zsh is sourced.** Put `export FOO=bar` in `acme`'s `rc.zsh`
   (`tprofile edit acme`), re-open the profile, `echo $FOO` → `bar`.

8. **Current.** `tprofile current` inside `acme` → `acme`. Outside any profile →
   `(none)`.

9. **Completion.** `tprofile use <TAB>` → completes `acme`.

10. **Remove.** `tprofile remove acme` → asks for confirmation, then removes the
    directory and the `~/.zsh_history_acme` file.

11. **Colors switch (Terminal.app).** With a Terminal.app profile named exactly
    `acme` created by hand: `tprofile use acme` switches the window colors.
    Without a matching profile: nothing breaks, just no color change.

12. **New window.** `tprofile window acme` opens a **new** window already in the
    `acme` profile (Terminal.app or iTerm2, depending on where you run it).

13. **Colors switch (iTerm2).** With an iTerm2 profile named exactly `acme`:
    running `tprofile use acme` in iTerm2 switches the colors **without** any
    automation permission prompt (it uses iTerm2's escape sequence, not
    AppleScript). Confirm no "control Terminal" dialog appears.

14. **No cross-app prompt.** Running `tprofile use acme` in iTerm2 must never ask
    permission to control **Terminal.app** (the old bug). In Terminal.app it
    must never ask about iTerm2.
