# Gradle Wrapper

This directory contains the Gradle Wrapper files.

## Files

- `gradle-wrapper.properties`: Wrapper configuration
- `gradlew` / `gradlew.bat`: Wrapper scripts (Linux/Mac/Windows)

## Note

The `gradle-wrapper.jar` file should be downloaded by running:

```bash
flutter build apk
```

Or manually download from:
https://raw.githubusercontent.com/gradle/gradle/v8.2.0/gradle/wrapper/gradle-wrapper.jar

Place it in this directory (`android/gradle/wrapper/`).

## Alternative

If you have Gradle installed locally, you can use:

```bash
gradle wrapper --gradle-version 8.2
```
