# App-specific R8 rules. Flutter, Firebase, OkHttp and DXcore ship their own
# consumer rules (DXcore keeps go.** and android.** for the gomobile JNI
# bridge), so only what they don't cover belongs here.

# Readable Crashlytics stack traces: keep line numbers, hide real file names.
# The Crashlytics plugin uploads mapping.txt so traces are deobfuscated.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-keep public class * extends java.lang.Exception

# WorkManager 2.7.0 (pulled in by play-services-ads) brings Room 2.2.5, whose
# rule "-keep class * extends androidx.room.RoomDatabase" keeps no
# constructors. R8 full mode (default since AGP 8) then drops
# WorkDatabase_Impl's no-arg constructor, which Room calls by reflection, and
# every release build crashes at start in androidx.startup with "Failed to
# create an instance of androidx.work.impl.WorkDatabase". Newer Room ships
# this exact rule; keep it until WorkManager is on Room 2.6+.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
