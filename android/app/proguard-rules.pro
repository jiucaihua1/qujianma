# Unused optional ML Kit text recognition scripts (we bundle Chinese only)
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep ML Kit Chinese OCR & ComponentRegistrar classes loaded via reflection in Release builds
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }

# Keep Shizuku UserService and AIDL stub instantiated via reflection by Shizuku
-keep class com.qujianma.qujianma.ShizukuUserService { *; }
-keep class com.qujianma.qujianma.IShizukuKeepAliveService** { *; }
