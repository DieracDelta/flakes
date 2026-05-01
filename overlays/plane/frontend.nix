{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_22,
  pnpm_10,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "plane-frontend";
  version = "0-unstable-2026-04-28";

  src = fetchFromGitHub {
    owner = "makeplane";
    repo = "plane";
    rev = "a62fe8a781";
    hash = "sha256-jVr5UUDveUoV6E4t1yaD4EzZPejlOPbEpZAOe3CbtIE=";
  };

  patches = [ ./web-base-path.patch ];

  pnpmDeps = pnpm_10.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-bFfoHOoSrsIg8QuHlXvixMYwL5DeraIjix35IcqPXfA=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_10.configHook
    pnpm_10
    makeWrapper
  ];

  buildInputs = [ nodejs_22 ];

  # Build-time environment variables for Vite
  env = {
    VITE_API_BASE_URL = "";
    VITE_ADMIN_BASE_URL = "";
    VITE_ADMIN_BASE_PATH = "/god-mode";
    VITE_LIVE_BASE_URL = "";
    VITE_LIVE_BASE_PATH = "/live";
    VITE_SPACE_BASE_URL = "";
    VITE_SPACE_BASE_PATH = "/spaces";
    VITE_WEB_BASE_URL = "";
    VITE_WEB_BASE_PATH = "";
    TURBO_TELEMETRY_DISABLED = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    CI = "true";
  };

  buildPhase = ''
    runHook preBuild

    # Patch frontend to support presigned PUT uploads (versitygw doesn't support S3 POST)
    substituteInPlace packages/services/src/file/file-upload.service.ts \
      --replace-fail \
        'async uploadFile(url: string, data: FormData): Promise<void> {' \
        'async uploadFile(url: string, data: FormData | File, ...args: any[]): Promise<void> {'

    substituteInPlace packages/services/src/file/file-upload.service.ts \
      --replace-fail \
        'return this.post(url, data, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
      cancelToken: this.cancelSource.token,
      withCredentials: false,
    })' \
        'const isPut = !(data instanceof FormData);
    return this.request({
      method: isPut ? "put" : "post",
      url,
      data,
      headers: isPut ? { "Content-Type": (data as any).type || "application/octet-stream" } : { "Content-Type": "multipart/form-data" },
      cancelToken: this.cancelSource.token,
      withCredentials: false,
    })'

    substituteInPlace packages/services/src/file/helper.ts \
      --replace-fail \
        'export const generateFileUploadPayload = (signedURLResponse: TFileSignedURLResponse, file: File): FormData => {
  const formData = new FormData();
  Object.entries(signedURLResponse.upload_data.fields).forEach(([key, value]) => formData.append(key, value));
  formData.append("file", file);
  return formData;
};' \
        'export const generateFileUploadPayload = (signedURLResponse: TFileSignedURLResponse, file: File): FormData | File => {
  const uploadData = signedURLResponse.upload_data;
  if ((uploadData as any).method === "PUT") {
    // Use the content_type from the presigned URL so Content-Type matches the signature
    return new File([file], file.name, { type: (uploadData as any).content_type || file.type });
  }
  const formData = new FormData();
  Object.entries(uploadData.fields).forEach(([key, value]) => formData.append(key, value));
  formData.append("file", file);
  return formData;
};'

    # Also patch the web app's own FileUploadService (separate copy from @plane/services)
    substituteInPlace apps/web/core/services/file-upload.service.ts \
      --replace-fail \
        'data: FormData,' \
        'data: FormData | File,'

    substituteInPlace apps/web/core/services/file-upload.service.ts \
      --replace-fail \
        'return this.post(url, data, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
      cancelToken: this.cancelSource.token,
      withCredentials: false,
      onUploadProgress: uploadProgressHandler,
    })' \
        'const isPut = !(data instanceof FormData);
    return this.request({
      method: isPut ? "put" : "post",
      url,
      data,
      headers: isPut ? { "Content-Type": (data as any).type || "application/octet-stream" } : { "Content-Type": "multipart/form-data" },
      cancelToken: this.cancelSource.token,
      withCredentials: false,
      onUploadProgress: uploadProgressHandler,
    })'

    # Clear turbo cache so patched sources get recompiled
    rm -rf node_modules/.cache/turbo .turbo

    pnpm turbo run build --filter=web --filter=admin --filter=space --filter=live --force

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Preserve the monorepo layout so pnpm's symlink structure stays intact.
    # ESM resolution depends on the virtual store (.pnpm/) being in the right
    # relative position — splitting into separate dirs breaks it.
    mkdir -p $out/lib/plane

    # Root node_modules (pnpm virtual store + hoisted deps)
    cp -r node_modules $out/lib/plane/node_modules

    # Space app (SSR)
    mkdir -p $out/lib/plane/apps/space
    cp -r apps/space/build $out/lib/plane/apps/space/build
    cp -r apps/space/node_modules $out/lib/plane/apps/space/node_modules
    cp apps/space/package.json $out/lib/plane/apps/space/

    # Live app
    mkdir -p $out/lib/plane/apps/live
    cp -r apps/live/dist $out/lib/plane/apps/live/dist
    cp -r apps/live/node_modules $out/lib/plane/apps/live/node_modules
    cp apps/live/package.json $out/lib/plane/apps/live/

    # Shared packages (workspace symlink targets)
    cp -r packages $out/lib/plane/packages

    # Remove broken symlinks (workspace links to apps we didn't copy)
    find $out/lib/plane/node_modules -xtype l -delete 2>/dev/null || true

    # Static apps (web, admin) — just the built HTML/JS/CSS
    mkdir -p $out/share/plane/web
    cp -r apps/web/build/client/* $out/share/plane/web/

    mkdir -p $out/share/plane/admin
    cp -r apps/admin/build/client/* $out/share/plane/admin/

    # === Wrapper scripts ===
    mkdir -p $out/bin

    # Space: SSR server via react-router-serve
    makeWrapper ${nodejs_22}/bin/node $out/bin/plane-space \
      --chdir "$out/lib/plane/apps/space" \
      --add-flags "$out/lib/plane/apps/space/node_modules/@react-router/serve/bin.js" \
      --add-flags "./build/server/index.js"

    # Live: collaboration server
    makeWrapper ${nodejs_22}/bin/node $out/bin/plane-live \
      --add-flags "$out/lib/plane/apps/live/dist/start.mjs"

    runHook postInstall
  '';

  # Skip slow/unnecessary fixup for large node_modules
  dontStrip = true;
  dontPatchELF = true;

  meta = {
    description = "Plane project management - frontend applications";
    homepage = "https://plane.so";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
})
