{
  lib,
  python312,
  fetchPypi ? python312.pkgs.fetchPypi,
}:

let
  python = python312;

  plane-sdk = python.pkgs.buildPythonPackage rec {
    pname = "plane-sdk";
    version = "0.2.8";
    pyproject = true;

    src = python.pkgs.fetchPypi {
      pname = "plane_sdk";
      inherit version;
      hash = "sha256-qMSKvwV6yiSPtpE/5ucmPbMsFrXqwyjS2LnZvio+ots=";
    };

    build-system = [ python.pkgs.setuptools ];

    dependencies = with python.pkgs; [
      requests
      pydantic
    ];

    doCheck = false;
    pythonImportsCheck = [ "plane_sdk" ];
  };

in
python.pkgs.buildPythonApplication rec {
  pname = "plane-mcp-server";
  version = "0.2.8";
  pyproject = true;

  src = python.pkgs.fetchPypi {
    pname = "plane_mcp_server";
    inherit version;
    hash = "sha256-iPdLzJ6e8MN6DQ1QKr+pXZS3Pgk6R+kzJa6Jt0/BhNI=";
  };

  build-system = [ python.pkgs.setuptools ];

  dependencies = with python.pkgs; [
    fastmcp
    plane-sdk
    mcp
    py-key-value-aio
    pyjwt
    authlib
    fakeredis
  ];

  # Relax exact version pins (e.g. fastmcp==2.14.4 vs nixpkgs' 2.14.5)
  pythonRelaxDeps = true;

  doCheck = false;
  pythonImportsCheck = [ "plane_mcp" ];

  meta = {
    description = "Plane MCP server - AI integration for Plane project management";
    homepage = "https://github.com/makeplane/plane-mcp-server";
    license = lib.licenses.asl20;
    mainProgram = "plane-mcp-server";
  };
}
