# After-deploy well: component picker, then a real shell.
# Render with: nix run .#demo
# Requires Docker or Podman.
#
# Two running components, no --component flag, so huh lists them.
# After the picker appears, Down moves the highlight so the list is clearly
# selectable, then Enter, type hostname in the container, then exit.
# VHS Wait matches the last line (huh footer, then the Starship λ).
Output demos/out/shell.mp4

Require deployah
Require zsh
Require starship

Source demos/tapes/_common.tape
Source demos/tapes/_well.tape
Source demos/tapes/_zsh.tape

Hide
Type "cd demos/shell"
Enter
Sleep 300ms
Type "deployah cluster up"
Enter
Wait /λ/
Type "deployah delete app local --yes >/dev/null 2>&1 || true"
Enter
Wait /λ/
Type `export COLUMNS=80`
Enter
Wait /λ/
Type "deployah deploy local --yes"
Enter
Wait /λ/
Type "clear"
Enter
Sleep 300ms
Show

Type "deployah shell app -e local"
Enter
Wait /enter submit/
Sleep 1.5s
Down
Sleep 1.5s
Enter
Wait /root@/
Sleep 800ms
Type "hostname"
Enter
Sleep 2s
Type "exit"
Enter
Wait /λ/
Sleep 2s
