# Headless NixOS VM test for Phase 0: proves the Enclave system boots to a
# working session (branding applied) and that a configuration change can be
# applied and rolled back via the system profile — the exact mechanism
# `nixos-rebuild switch` / `--rollback` uses.
#
# Run: nix build .#checks.x86_64-linux.phase0 -L
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "enclave-phase0";

  nodes.machine = { pkgs, ... }: {
    imports = [
      ../modules/common.nix
      ../modules/branding.nix
    ];
    # Plymouth isn't meaningful in a headless VM; keep boot simple.
    boot.plymouth.enable = pkgs.lib.mkForce false;

    # A second generation that differs only by adding htop. It inherits the
    # parent config (and the test's guest modules), so switching to it and back
    # never breaks the VM's command channel.
    specialisation.withHtop.configuration = {
      environment.systemPackages = [ pkgs.htop ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Task 5: boots to a working Enclave session.
    machine.succeed("grep '^NAME=Enclave' /etc/os-release")
    machine.succeed("grep '^ID=enclave' /etc/os-release")

    # Task 7: generation switch + rollback.
    # Generation 1 = the running base system (no htop).
    machine.fail("command -v htop")
    machine.succeed("nix-env -p /nix/var/nix/profiles/system --set /run/current-system")

    # Activate the htop specialisation and record it as generation 2.
    g2 = machine.succeed("readlink -f /run/current-system/specialisation/withHtop").strip()
    machine.succeed("/run/current-system/specialisation/withHtop/bin/switch-to-configuration test")
    machine.succeed(f"nix-env -p /nix/var/nix/profiles/system --set {g2}")
    machine.succeed("command -v htop")  # gen 2 active
    print(machine.succeed("nix-env -p /nix/var/nix/profiles/system --list-generations"))

    # Roll back to generation 1 and reactivate it.
    machine.succeed("nix-env -p /nix/var/nix/profiles/system --rollback")
    machine.succeed("$(readlink /nix/var/nix/profiles/system)/bin/switch-to-configuration test")
    machine.fail("command -v htop")  # htop gone -> rollback proven

    machine.succeed("echo ENCLAVE_PHASE0_OK")
  '';
}
