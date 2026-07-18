{ octo-fiesta-src }:
final: prev: {
  octo-fiesta = final.dotnetCorePackages.buildDotnetModule {
    pname = "octo-fiesta";
    version = "0.0.0-dev";

    src = octo-fiesta-src;

    projectFile = "octo-fiesta/octo-fiesta.csproj";
    nugetDeps = ./octo-fiesta-deps.json;

    dotnet-sdk = final.dotnetCorePackages.sdk_9_0-bin;
    dotnet-runtime = final.dotnetCorePackages.aspnetcore_9_0-bin;

    executables = [ "octo-fiesta" ];

    meta = {
      description = "Subsonic API proxy that fetches missing music into a Navidrome library";
      homepage = "https://github.com/V1ck3s/octo-fiesta";
      license = final.lib.licenses.gpl3Only;
      mainProgram = "octo-fiesta";
      platforms = final.lib.platforms.linux;
    };
  };
}
