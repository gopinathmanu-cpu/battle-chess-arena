# Open Source Policy

Battle Chess Arena is an open-source project licensed under
`GPL-3.0-or-later`. Source code required to build the distributed app, project
documentation, and original bundled visual assets must remain available under
that license.

## Dependency rule

New packages may be added only when all of these conditions are satisfied:

1. The package has a clearly stated OSI-approved open-source license.
2. Its license is compatible with GPL-3.0-or-later distribution.
3. Its source code is publicly available.
4. Its copyright and license notice is recorded in `THIRD_PARTY_NOTICES.md`.
5. It does not require a proprietary runtime SDK to provide core chess play.

Permissive licenses such as MIT, BSD, and Apache-2.0 are acceptable when their
notice requirements are preserved. GPL-compatible copyleft components are also
acceptable. Packages with missing, custom, source-available, non-commercial,
or field-of-use-restricted licenses must not be included.

## Art, animation, audio, and fonts

- Original project assets are released under GPL-3.0-or-later with the app.
- Contributions must be original or use a GPL-compatible open license.
- Every imported asset must record its creator, source URL, exact license, and
  any required attribution.
- No franchise characters, proprietary animation packs, unlicensed fonts, or
  closed sound libraries may be bundled.
- Project source files for production animations must be included whenever the
  license requires the preferred form for modification.

### Generated artwork safeguards

- Generate original project-directed designs, not copies of existing game,
  film, comic or television characters, branded costumes, actor likenesses,
  logos, stock pictures or museum photographs.
- Historical facts and traditional stories may inform descriptions. Do not
  reproduce a modern adaptation's distinctive visual expression or assume
  that an online image is reusable because its subject is ancient.
- Keep prompts, generator/mode, source sheets, selected outputs and local
  preparation records beside each asset family. Disclose unavailable records
  rather than inventing provenance.
- Review selected output for recognizable protected designs, signatures,
  watermarks and accidental likenesses; replace questionable output or obtain
  documented permission before shipping it.
- AI generation is not proof of non-infringement, public-domain status or
  copyright ownership. Our GPL notice applies only to rights we can grant; it
  does not clear third-party rights or establish copyright in AI-only material.
- See [artwork provenance and release review](docs/ARTWORK_PROVENANCE.md).

## Optional services

The mobile app may connect to independently operated services, but the client
must remain buildable and playable locally using open-source components. No
closed service may become mandatory for offline chess or access to owned game
records.

## Review gate

Before each release, review the dependency lockfile and every new asset against
this policy. A dependency or asset with unclear terms blocks the release until
its license is verified or it is removed.
