# After-deploy well: logs for two pods.
# Render with: nix run .#demo
# Requires Docker or Podman.
#
# Both workers print hostname in a loop. Follow never ends, so Sleep
# then Ctrl+C. Pass -e local to skip the kubeconfig-fallback warning.
Output demos/out/logs.mp4

Require deployah
Require zsh
Require starship

Source demos/tapes/_common.tape
Source demos/tapes/_well.tape
Source demos/tapes/_zsh.tape

Hide
Type "cd demos/logs"
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

Type "deployah logs app -e local"
Enter
Sleep 6s
Ctrl+C
Wait /λ/
Sleep 2s
