# Android ProGuard rules for grok2api
# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/google/buildbot/repositories/android_x86/appcompat/proguard-flags.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
# For a more detailed explanation, see
# http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# Preserve all native library classes
-keep class * extends java.lang.Object {
    native <methods>;
}

# Preserve all classes that might be used in reflection
-keep class com.grok2api.android.** { *; }

# Preserve all WebView related classes
-keep class android.webkit.** { *; }

# Keep R (resources) classes
-keep class **.R$* { *; }

# Keep all Activities, Services, and BroadcastReceivers
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

# Keep all Parcelable classes
-keep public class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
