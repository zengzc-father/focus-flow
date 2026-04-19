# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress warnings for Flutter
-dontwarn io.flutter.**
-dontwarn android.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep usage_stats plugin
-keep class com.csdn.usage_stats.** { *; }

# ==================== Flutter Plugin ProGuard Rules ====================

# flutter_local_notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# workmanager
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-dontwarn androidx.work.**

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# audio players
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audio.** { *; }

# android_alarm_manager_plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# flutter_foreground_task
-keep class com.pravera.flutter_foreground_task.** { *; }

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# General Android Support
-keep class androidx.** { *; }
-dontwarn androidx.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-keepclassmembers class **$WhenMappings { *; }

# Gson (if used)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Prevent obfuscation of model classes
-keep class **.model.** { *; }
-keep class **.models.** { *; }

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Disable R8 full mode strictness
-dontwarn java.lang.invoke.StringConcatFactory
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
