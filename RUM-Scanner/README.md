# RUM V10.9 — Packed Distribution

This folder contains the public **LZW + Base64** packaged release.

- Version: **10.9**.
- Original source length: **1,203,331 bytes**.
- Source SHA-256: `2b2a98c36f3698ece06e905fe91f8a2df764377d3729df8cf21837e9108e98ac`.
- 12 ordered data parts; `Loader.lua` downloads, decodes and executes them in a compatible authorized client.
- **LZW + Base64 is reversible encoding, not secure encryption.** Client-side source can be recovered. Never store credentials in client code.
- Source and packed data were compared offline. Client runtime testing remains pending.
- Publish all parts, manifest and Loader as a single commit.
