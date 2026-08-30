# Landing hero. Uses demos/nginx.
# Render with: nix run .#demo
# Requires Docker or Podman.
#
# Wait /λ/ after deploy. The Status UI can finish before VHS sees
# "Deployed". Chromium opens the Ingress URL after this tape.
Output demos/out/nginx.mp4

Require deployah
Require zsh
Require starship
Require bat

Source demos/tapes/_common.tape
Source demos/tapes/_hero.tape
Source demos/tapes/_zsh.tape

# --- off camera: workdir + local cluster ---
Hide
Type "cd demos/nginx"
Enter
Sleep 300ms
Type `alias cat='bat --paging=never --style=numbers,grid --theme=Dracula --language=yaml'`
Enter
Sleep 200ms
Type "deployah cluster up"
Enter
Wait /λ/
Type "deployah delete nginx local --yes >/dev/null 2>&1 || true"
Enter
Wait /λ/
Type `export COLUMNS=160`
Enter
Wait /λ/
Type "clear"
Enter
Sleep 300ms
Show

# --- on camera ---
# Spec, platform, plan, deploy, cluster status, then Chromium.
# Clear off-camera between commands.
Type@70ms "cat deployah.yaml"
Enter
Wait /λ/
Sleep 4s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type@70ms "cat deployah.platform.yaml"
Enter
Wait /λ/
Sleep 3s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type "deployah plan local"
Enter
Wait /λ/
Sleep 4s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type "deployah deploy local --yes"
Enter
Wait /λ/
Sleep 3.5s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type "deployah cluster status"
Enter
Wait /λ/
Sleep 4s
