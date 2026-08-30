{
  pkgs,
  deployah,
}:

let
  # Landing sans. libass reads this via fontsdir; do not rely on fontconfig.
  inter = pkgs.inter;
  # Default ffmpeg is headless (no x11grab). ffmpeg-full is Hydra-cached.
  ffmpeg = pkgs.ffmpeg-full;

  demoTools = [
    deployah
    pkgs.kubernetes-helm
    pkgs.yq-go
    pkgs.gawk
    pkgs.vhs
    ffmpeg
    pkgs.gifsicle
    pkgs.bat
    pkgs.nano
    pkgs.jq
    pkgs.zsh
    pkgs.starship
    pkgs.zsh-syntax-highlighting
    pkgs.xvfb-run
    pkgs.chromium
    pkgs.openbox
    pkgs.xdotool
    pkgs.dbus
  ];

  mkApp =
    {
      name,
      description,
      script,
      runtimeInputs ? [ ],
      runtimeEnv ? null,
    }:
    let
      package = pkgs.writeShellApplication {
        inherit
          name
          runtimeInputs
          runtimeEnv
          ;
        text = script;
        meta = {
          mainProgram = name;
          inherit description;
        };
      };
    in
    {
      inherit package;
      app = {
        type = "app";
        program = pkgs.lib.getExe package;
        meta = {
          mainProgram = name;
          inherit description;
        };
      };
    };

  demo = mkApp {
    name = "demo";
    description = "Render demos/tapes/*/demo.tape to demos/out/ (mp4; hero also captions and gif). Needs Docker or Podman.";
    runtimeInputs = demoTools;
    runtimeEnv = {
      INTER_FONTDIR = "${inter}/share/fonts";
      ZSH_SYNTAX_HIGHLIGHTING = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
    };
    script = builtins.readFile ./demo.sh;
  };

  publish-demo = mkApp {
    name = "publish-demo";
    description = "Sync demos/out/ to R2 (R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT_URL, R2_BUCKET, R2_DEST_PATH)";
    runtimeInputs = [ pkgs.awscli2 ];
    script = ''
      set -euo pipefail

      : "''${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is required}"
      : "''${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is required}"
      : "''${R2_ENDPOINT_URL:?R2_ENDPOINT_URL is required}"
      : "''${R2_BUCKET:?R2_BUCKET is required}"
      : "''${R2_DEST_PATH:?R2_DEST_PATH is required}"

      root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      if [ -z "$root" ] || [ ! -d "$root/demos/out" ]; then
        echo "demos/out/ missing; run nix run .#demo first" >&2
        exit 1
      fi

      export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
      export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
      export AWS_DEFAULT_REGION="auto"

      exec aws s3 sync "$root/demos/out/" \
        "s3://$R2_BUCKET/$R2_DEST_PATH" \
        --endpoint-url "$R2_ENDPOINT_URL" \
        --exclude ".gitkeep" \
        --exclude "*.srt" \
        --exclude "*.ass" \
        --exclude "*-vhs.mp4"
    '';
  };

  preview = mkApp {
    name = "preview";
    description = "Vite landing preview (npm run preview)";
    runtimeInputs = [ pkgs.nodejs_22 ];
    script = ''
      set -euo pipefail
      root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      cd "$root"
      export PATH="$root/node_modules/.bin:$PATH"
      exec npm run preview
    '';
  };
in
{
  inherit demoTools;

  apps = {
    demo = demo.app;
    publish-demo = publish-demo.app;
    preview = preview.app;
  };

  packages = {
    demo = demo.package;
    publish-demo = publish-demo.package;
    preview = preview.package;
  };
}
