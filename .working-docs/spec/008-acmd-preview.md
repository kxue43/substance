# Add Preview to `acmd` command

The `acmd` shell function defined in @lib/acmd.sh is a `fzf`-based command (shell function or script) discovery and picker utility.

It currently discovers shell functions and scripts by the following mechanism:
- Shell functions from the @lib/commands.sh file by regexp (@lib/acmd.sh#L33)
- Shell aliases from the @lib/aliases.sh file by regex (@lib/acmd.sh#L35)
- Env-specific `.bashrc` file from @folder/profile/ by regex (@lib/acmd.sh#L41-44)
- Shell scripts under @folder/bin
- Items of the `_kxue43_commands_list` array variable (e.g. @lib/cplan.sh#253)

At the `fzf` picker terminal UI, I want to add a preview feature—when a certain command is highlighted,
use the `--preview` flag of `fzf` to show some "preview contents" of the command (e.g. @lib/cplan.sh#L108)

Here is my idea of building the "preview contents"—using a cache file.
- When `acmd -p` or `acmd -l` is invoked, it checks if the `$KXUE43_SUBSTANCE_DIR/_acmd_cache` file doesn't exist
  or was last modified more than 12 hours ago. (`KXUE43_SUBSTANCE_DIR` is guaranteed to exist and is the absolute path to this project folder.)
  If so, build a new `_acmd_cache` file in the following way.
  * Scan the @lib/commands.sh file using the regexp.
  * Using `use-role-profile` as an example, it corresponds to one line in the `_acmd_cache` file of the following format.

    ```
    use-role-profile|<absolute-path-to-lib/commands.sh>|32:41
    ```

    It's a line of three items separated by `|`. The first one being the command name.
    The second one is the absolute path of the file in which the command is defined.
    The third one being the line range of the function definition: 32 comes from the line of the `^use-role-profile() {$` pattern,
    and 41 comes from the line of the `^}$` pattern.

    **The idea is that the second and third item will be fed to `bat` in the following command to produce the "preview contents".**

    ```bash
    bat --color=always --line-range <3rd-item> <2nd-item>
    ```

    With each shell function in @lib/commands.sh, add one such line to `_acmd_cache`.

  * Scan the @lib/aliases.sh file using the regexp.
  * Using `gtemp` as an example, it corresponds to one line in `_acmd_cache` in the following format.

    ```
    gtemp|<absolute-path-to-lib/aliases.sh>|11:11
    ```

    The first two items are similar to the `use-role-profile` case, while the third item is just the line on which the alias is defined.

    With each alias in @lib/aliases.sh, add one such line to `_acmd_cache`.

  * With the env-specific `.bashrc` file, do the same thing with aliases and shell functions in it.
  * With each shell script under @folder/bin, scan it to produce a similar line in `_acmd_cache`.
  * Using the @bin/fnm-links as an example, it corresponds to one line like below.

    ```
    fnm-links|<absolute-path-to-bin/fnm-links>|46:54
    ```

    The third item is produced this way:
    - Locate the line of `^main() {$`. Call this line number A.
    - Searching forward from line A, locate the first line matching `<<'EOF'$`. This line number plus one, is 46.
    - Searching forward from line A, locate the first line matching `^EOF$`. This line number minus one, is 54.
    - **Fallback**: if no `<<'EOF'$` line is found, use a range of `A:(A+5)`.

  * With each item in `_kxue43_commands_list`, scan its corresponding file in @folder/lib to produce one line in `_acmd_cache`.
    An item named `cmd-name` has its corresponding file at `lib/cmd-name.sh`.
  * Using `cplan` as an example, it corresponds to one line like below.

    ```
    cplan|<absolute-path-to-lib/cplan.sh>|195:204
    ```

    The third item is produced this way:
    - Locate the line of `^cplan() {$`. Call this line number A.
    - Searching forward from line A, locate the first line matching `<<'EOF'$`. This line number plus one, is 195.
    - Searching forward from line A, locate the first line matching `^EOF$`. This line number minus one, is 204.
    - **Fallback**: if no `<<'EOF'$` line is found, use a range of `A:(A+5)`.
  * The `_acmd_cache` file is built by putting all such lines one after another.
- A new `-r` flag is added to `acmd`. It does nothing other than deleting the `_acmd_cache` file
  (if it exists). This forces a cache rebuild on the next `-p` invocation.

- Both the `-p` and `-l` branches use the cache: they trigger the same cache check and rebuild described
  above. The existing runtime scanning of `_kxue43_commands_list`, `lib/commands.sh`, `lib/aliases.sh`,
  etc. is no longer performed inside either branch.

- With the newly built or still-valid `_acmd_cache` file:
  * The `-l` branch prints the first field of each cache line (command name only), sorted, in columns —
    same visual output as before.
  * The `-p` branch opens the fzf picker. The command name list is taken **entirely from the cache**
    (first field of each line). Configure fzf as follows:
    - Use the `--delimiter` and `--with-nth` flags to display only the first field (command name).
      Search is scoped to the command name only.
    - Feed the 2nd and 3rd fields to the `--preview` flag like below.
      `fzf` must have a way of passing the second and third fields to the `bat` command in `--preview`.
      **If you are not sure, use web search to figure out.**

      ```
      --preview 'bat --color=always --line-range <3rd-field> <2nd-field>'
      ```

**IMPORTANT: When building the `_acmd_cache` file, you are free to use common POSIX shell utilities
such as `grep`, `awk`, `sed`, etc. In particular, you can also use `ripgrep`. Built for macOS first,
disregard compatibility on Linux for now.**
