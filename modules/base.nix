# Shared by every machine: user, key-only SSH, keyboard, tools. Nothing here may
# be machine-specific or private (see README.md). Boot loader, hardware and
# platform live in ./x86_64.nix and ./asahi.nix.
{ pkgs, self, ... }:
{
  time.timeZone = "Australia/Sydney";

  # Keyboard: Colemak with Caps Lock as Ctrl. console.useXkbConfig applies it
  # to the text console too (where you type the login password), with no X
  # server involved.
  services.xserver.xkb = {
    layout = "us";
    variant = "colemak";
    options = "ctrl:nocaps";
  };
  console.useXkbConfig = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.networkmanager.enable = true;

  # SSH is key-only, so there is no password to leak or guess. Set a local
  # (console) password during install with: nixos-enter --root /mnt -c 'passwd adam'
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.adam = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPvLeOCzcw1An2n9WmWlDKG1SXMBKcOo1mLA9XFaH8nw"
    ];
  };

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.adopt-config
    pkgs.git
    pkgs.gh
    pkgs.vim
    pkgs.curl
  ];

  system.stateVersion = "26.05";
}
