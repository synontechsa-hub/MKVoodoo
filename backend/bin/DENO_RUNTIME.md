# Bundled Deno runtime

- Version: 2.9.6
- Platform: Windows x86-64 (`deno-x86_64-pc-windows-msvc.zip`)
- Source: https://github.com/denoland/deno/releases/tag/v2.9.6
- Archive SHA-256: `15E5300B0BA3C3695A7621D90160A746EC9E710228CEE639AFA9D580F6E3CD11`
- License: MIT; see `DENO_LICENSE.md`

Run `scripts/fetch_deno.ps1` before compiling the Windows installer. The script
downloads the pinned official archive, verifies its SHA-256 checksum, validates
the reported runtime version, and materializes `backend/bin/deno.exe`.
