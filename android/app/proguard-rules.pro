# General Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.runtime.** { *; }

# Flutter Play Store Split compatibility (R8 fixes)
-dontwarn com.google.android.play.core.**

# Isar rules
-keep class io.isar.** { *; }
-keepnames class io.isar.** { *; }
-keep class * extends io.isar.IsarCollection { *; }
-keep class * extends io.isar.IsarLink { *; }

# Media3 / ExoPlayer rules (if needed for shrinking)
-keep class androidx.media3.exoplayer.** { *; }
-keep class androidx.media3.common.** { *; }
-keep class androidx.media3.ui.** { *; }
