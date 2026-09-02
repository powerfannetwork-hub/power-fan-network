# POWER FAN NETWORK
# AppLovin MAX / IAB OMID R8 rules

# Amazon Privacy Pass classes referenced by AppLovin OMID.
-dontwarn com.amazon.privacypass.**
-keep class com.amazon.privacypass.** { *; }

# AppLovin OMID
-dontwarn com.iab.omid.library.applovin.**
-keep class com.iab.omid.library.applovin.** { *; }

# AppLovin SDK
-dontwarn com.applovin.**
-keep class com.applovin.** { *; }
