# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Prevent obfuscation of Pigeon generated code
-keep class dev.flutter.pigeon.** { *; }
-keep public class dev.flutter.pigeon.** { *; }
-keep class dev.flutter.pigeon.path_provider_android.** { *; }
-keep interface dev.flutter.pigeon.** { *; }

# Keep your app's code that might be called via reflection or platform channels
-keep class com.example.download_videos.** { *; }

# Explicitly keep PathProvider and its dependencies
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Keep annotations and other attributes often used by plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Keep generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Allow missing Play Store classes (used for Deferred Components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
