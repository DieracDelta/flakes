{ lib, pkgset, self, utils, system, ... }:
inherit (pkgset) inputs;
inputs.mailserver.nixosModule
{
  mailserver = {
    enable = true;
    fqdn = <server-FQDN>;
    domains = [ <domains> ];

# A list of all login accounts. To create the password hashes, use
# nix run nixpkgs.apacheHttpd -c htpasswd -nbB "" "super secret password" | cut -d: -f2
    loginAccounts = {
      "user1@example.com" = {
        hashedPassword = "$6$/z4n8AQl6K$kiOkBTWlZfBd7PvF5GsJ8PmPgdZsFGN1jPGZufxxr60PoR0oUsrvzm2oQiflyz5ir9fFJ.d/zKm/NgLXNUsNX/";

        aliases = [
          "postmaster@example.com"
            "postmaster@example2.com"
        ];

# Make this user the catchAll address for domains example.com and
# example2.com
        catchAll = [
          "example.com"
            "example2.com"
        ];
      };

      "user2@example.com" = { ... };
    };

# Extra virtual aliases. These are email addresses that are forwarded to
# loginAccounts addresses.
    extraVirtualAliases = {
# address = forward address;
      "abuse@example.com" = "user1@example.com";
    };

# Use Let's Encrypt certificates. Note that this needs to set up a stripped
# down nginx and opens port 80.
    certificateScheme = 3;

# Enable IMAP and POP3
    enableImap = true;
    enablePop3 = true;
    enableImapSsl = true;
    enablePop3Ssl = true;

# Enable the ManageSieve protocol
    enableManageSieve = true;

# whether to scan inbound emails for viruses (note that this requires at least
# 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
    virusScanning = false;
  };
}
