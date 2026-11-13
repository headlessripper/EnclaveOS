{ ... }:
{
  # --- Identity: drives os-release NAME / ID / PRETTY_NAME ---
  system.nixos.distroName = "Enclave";
  system.nixos.distroId = "enclave";

  # --- Boot splash: Plymouth with the Enclave logo, clean quiet boot ---
  boot.plymouth = {
    enable = true;
    theme = "spinner";
    logo = ../../assets/branding/light-orange-dot/512x512.png;
  };
  boot.kernelParams = [ "quiet" "splash" ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # --- Console login banner ---
  environment.etc."issue".text = ''

    Enclave  \r  (\l)

  '';
}
