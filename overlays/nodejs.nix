final: prev: {
  nodejs-slim_24 = prev.nodejs-slim_24.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (final.fetchpatch2 {
        # Node.js 24.18.1 predates this upstream fix for a test that races a
        # fixed timeout against libuv worker-pool scheduling under load.
        url = "https://github.com/nodejs/node/commit/2adaeeee9cb7449062ca1c04526b680255bbaa73.patch?full_index=1";
        hash = "sha256-k4JtmXeOBIrLccT3VitJvuotQRXxtIE88aGK3MnpDjM=";
      })
    ];
  });
}
