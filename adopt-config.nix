{ writeShellApplication, gh, git }:

# Signs in to GitHub, clones the private config and switches to it. Works on
# any NixOS machine, including one installed from the stock installer, so it is
# also exposed as `nix run github:<you>/nixos-bootstrap#adopt-config`.
# `sudo` and `nixos-rebuild` come from the system, not from here: the
# setuid sudo wrapper lives in /run/wrappers, not in the Nix store.
writeShellApplication {
  name = "adopt-config";
  runtimeInputs = [ gh git ];
  text = ''
    usage="usage: adopt-config OWNER/REPO [HOST]   (HOST defaults to server on x86_64, home on aarch64)"
    repo="''${1:?$usage}"
    case "$(uname -m)" in
      aarch64) default_host=home ;;
      *) default_host=server ;;
    esac
    host="''${2:-$default_host}"
    dest="$HOME/repos/me/$(basename "$repo")"

    if ! gh auth status >/dev/null 2>&1; then
      echo "Signing in to GitHub: open the URL it prints on any device and enter the code."
      gh auth login --hostname github.com --git-protocol https --web
    fi
    # Same as `gh auth setup-git`, except that git finds `gh` through PATH when
    # it needs a password. setup-git writes the Nix store path of this `gh`,
    # which breaks after a garbage collection or a generation change.
    git config --global --replace-all credential.https://github.com.helper ""
    git config --global --add credential.https://github.com.helper "!gh auth git-credential"

    if [ -d "$dest/.git" ]; then
      git -C "$dest" pull --ff-only || echo "warning: could not update $dest, using what is there"
    else
      mkdir -p "$(dirname "$dest")"
      gh repo clone "$repo" "$dest"
    fi
    cd "$dest"
    echo "Switching to $dest#$host ..."
    sudo nixos-rebuild switch --flake ".#$host" --impure
  '';
}
