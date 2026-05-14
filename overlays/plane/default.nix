{ plane-mcp-server-src }:

# Plane project management overlay
final: prev: {
  plane-frontend = final.callPackage ./frontend.nix { };
  plane-api = final.callPackage ./api.nix { };
  plane-mcp-server = final.callPackage ./mcp-server.nix {
    inherit plane-mcp-server-src;
  };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (import ./python-deps.nix)
  ];
}
