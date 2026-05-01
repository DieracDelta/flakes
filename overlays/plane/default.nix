# Plane project management overlay
final: prev: {
  plane-frontend = final.callPackage ./frontend.nix { };
  plane-api = final.callPackage ./api.nix { };
  plane-mcp-server = final.callPackage ./mcp-server.nix { };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (import ./python-deps.nix)
  ];
}
