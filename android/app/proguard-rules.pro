# ONNX Runtime reaches native code through JNI.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Vendored KittenTTS FFI bridge.
-keep class com.kittenml.kittentts.** { *; }

# PDFium / pdfrx native bridge.
-keep class io.legend.pdfium.** { *; }
-keep class dev.pdfrx.** { *; }
-keep class com.pdfium.** { *; }
-dontwarn io.legend.pdfium.**
-dontwarn com.pdfium.**

# google_mobile_ads keeps its own consumer rules; avoid stripping callbacks.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# flutter_onnxruntime plugin bridge.
-keep class com.masicai.flutteronnxruntime.** { *; }

# jni/dartjni FFI bridge used by flutter_onnxruntime.
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn com.github.dart_lang.jni.**

# audio_service / just_audio.
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# AndroidX WorkManager + Room, pulled in by the Mobile Ads SDK. Room resolves
# generated database implementations reflectively, so R8 must not rename or
# remove them.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase$Callback { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# AndroidX Startup initialises WorkManager before Application.onCreate.
-keep class androidx.startup.** { *; }
