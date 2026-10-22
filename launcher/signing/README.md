`sideload.keystore` signs every launcher build of this fork (debug and release), so each new APK from
the "Build launcher APK" workflow installs over the previous one. Passwords: `android`, alias
`androiddebugkey`. It is a sideload key, not a store key: installing an update signed with it still
needs ADB access to the TV.
