# Keep Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Keep video player code
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Keep url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep permission_handler
-keep class com.baseflow.permissionhandler.** { *; }
