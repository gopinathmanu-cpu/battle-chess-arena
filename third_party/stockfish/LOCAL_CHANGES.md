# Local Android compatibility changes

Based on stockfish 1.8.1 from pub.dev, upstream https://github.com/ArjanAswal/stockfish.
The upstream source and license are retained.

- Use the app's Android Gradle Plugin and repositories instead of AGP 3.5.0 and removed `jcenter()` calls.
- Declare the namespace explicitly, compile with Android SDK 36, and use NDK 28.2.13676358.
- Permit Dart 3 in the package SDK constraint.
- Build only the CPU architectures requested by Flutter; this avoids packaging unused native engines during emulator development.

These changes allow the native dependency to build with this project's Android tooling.
