# Flutter and Dart optimizations
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Firebase optimizations
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Stripe optimizations  
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Nimbus JOSE + JWT and encryption dependencies
-keep class com.nimbusds.** { *; }
-dontwarn com.nimbusds.**

# Bouncy Castle cryptography
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Tink cryptography
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# OkHttp dependencies
-keep class com.squareup.okhttp.** { *; }
-dontwarn com.squareup.okhttp.**

# gRPC OkHttp
-keep class io.grpc.okhttp.** { *; }
-dontwarn io.grpc.okhttp.**

# Guava reflection utilities
-keep class com.google.common.reflect.** { *; }
-dontwarn com.google.common.reflect.**

# Remove debug information
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Optimize enums
-allowaccessmodification

# Remove unused code
-dontshrink
-dontoptimize
-dontobfuscate
