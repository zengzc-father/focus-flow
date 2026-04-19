# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress warnings for Flutter Warnings
-dontwarn io.flutter.**
-dontwarn android.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep usage_stats plugin
-keep class com.csdn.usage_stats.** { *; }
