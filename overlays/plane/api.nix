{
  lib,
  stdenv,
  fetchFromGitHub,
  python312,
  makeWrapper,
  postgresql,
  libxslt,
  xmlsec,
  openssl,
}:

let
  python = python312;

  pythonEnv = python.withPackages (
    ps: with ps; [
      # django
      django_4
      djangorestframework
      # postgres
      psycopg
      psycopg-c
      dj-database-url
      # mongo
      pymongo
      # redis
      redis
      django-redis
      # cors
      django-cors-headers
      # celery
      celery
      django-celery-beat
      django-celery-results
      # file serve
      whitenoise
      # fake data
      faker
      # filters
      django-filter
      # json model
      jsonmodels
      # storage
      django-storages
      # user management
      django-crum
      # web server
      uvicorn
      # sockets
      channels
      # ai
      openai
      # slack
      slack-sdk
      # apm (scout-apm dropped: pins psutil<6, nixpkgs has 7.x)
      # xlsx generation
      openpyxl
      # logging
      python-json-logger
      # html parser
      beautifulsoup4
      # analytics
      posthog
      # crypto
      cryptography
      # html validator
      lxml
      # s3
      boto3
      # password validator
      zxcvbn
      # timezone
      pytz
      # jwt
      pyjwt
      # OpenTelemetry
      opentelemetry-api
      opentelemetry-sdk
      opentelemetry-instrumentation-django
      opentelemetry-exporter-otlp
      # OpenAPI Specification
      drf-spectacular
      # html sanitizer
      nh3
      # server
      gunicorn
    ]
  );
in
stdenv.mkDerivation {
  pname = "plane-api";
  version = "0-unstable-2026-04-28";

  src = fetchFromGitHub {
    owner = "makeplane";
    repo = "plane";
    rev = "a62fe8a781";
    hash = "sha256-jVr5UUDveUoV6E4t1yaD4EzZPejlOPbEpZAOe3CbtIE=";
  };

  patches = [ ./api-nix-compat.patch ];

  # Patch storage to use presigned PUT instead of POST (versitygw doesn't support POST)
  postPatch = ''
    cat > apps/api/plane/settings/storage_presigned.py << 'STORAGEPY'
# Presigned PUT replacement for generate_presigned_post
# versitygw (and many S3-compatible gateways) don't support S3 POST Object API
def _generate_presigned_put(self, object_name, file_type, file_size, expiration=None):
    from botocore.exceptions import ClientError
    if expiration is None:
        expiration = self.signed_url_expiration
    try:
        url = self.s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self.aws_storage_bucket_name,
                "Key": object_name,
                "ContentType": file_type,
            },
            ExpiresIn=expiration,
        )
    except ClientError as e:
        print(f"Error generating presigned PUT URL: {e}")
        return None
    return {"url": url, "fields": {}, "method": "PUT", "content_type": file_type}
STORAGEPY

    substituteInPlace apps/api/plane/settings/storage.py \
      --replace-fail \
        "from storages.backends.s3boto3 import S3Boto3Storage" \
        "from storages.backends.s3boto3 import S3Boto3Storage
from plane.settings.storage_presigned import _generate_presigned_put"

    substituteInPlace apps/api/plane/settings/storage.py \
      --replace-fail \
        "def generate_presigned_post(self, object_name, file_type, file_size, expiration=None):" \
        "def generate_presigned_post(self, object_name, file_type, file_size, expiration=None):
        return _generate_presigned_put(self, object_name, file_type, file_size, expiration)
    def _original_generate_presigned_post(self, object_name, file_type, file_size, expiration=None):"
  '';

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    pythonEnv
    postgresql.lib
    libxslt
    xmlsec
    openssl
  ];

  installPhase = ''
    runHook preInstall

    # Copy the Django application
    mkdir -p $out/share/plane-api
    cp -r apps/api/manage.py $out/share/plane-api/
    cp -r apps/api/plane $out/share/plane-api/
    cp -r apps/api/templates $out/share/plane-api/
    mkdir -p $out/share/plane-api/logs

    # Create wrapper scripts
    mkdir -p $out/bin

    makeWrapper ${pythonEnv}/bin/python $out/bin/plane-manage \
      --add-flags "$out/share/plane-api/manage.py" \
      --set DJANGO_SETTINGS_MODULE plane.settings.production \
      --set PYTHONPATH "$out/share/plane-api"

    makeWrapper ${pythonEnv}/bin/gunicorn $out/bin/plane-api \
      --set DJANGO_SETTINGS_MODULE plane.settings.production \
      --set PYTHONPATH "$out/share/plane-api" \
      --add-flags "-k uvicorn.workers.UvicornWorker" \
      --add-flags "plane.asgi:application"

    makeWrapper ${pythonEnv}/bin/celery $out/bin/plane-worker \
      --set DJANGO_SETTINGS_MODULE plane.settings.production \
      --set PYTHONPATH "$out/share/plane-api" \
      --add-flags "-A plane worker -l info -c 4"

    makeWrapper ${pythonEnv}/bin/celery $out/bin/plane-beat \
      --set DJANGO_SETTINGS_MODULE plane.settings.production \
      --set PYTHONPATH "$out/share/plane-api" \
      --add-flags "-A plane beat -l info"

    runHook postInstall
  '';

  meta = {
    description = "Plane project management - API server";
    homepage = "https://plane.so";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
