{ pkgs, ... }:
{
  security.sudo-rs.enable = true;
  security.sudo-rs.extraRules = [
    {
      users = [ "jrestivo" ];
      commands = [
        {
          command = "${pkgs.coreutils-full}/bin/nice";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.util-linux}/bin/ionice";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.util-linux}/bin/renice";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
