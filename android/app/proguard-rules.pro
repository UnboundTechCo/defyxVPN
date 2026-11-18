# App-specific R8 rules. Flutter, Firebase, OkHttp and DXcore ship their own
# consumer rules (DXcore keeps go.** and android.** for the gomobile JNI
# bridge), so only what they don't cover belongs here.

# Readable Crashlytics stack traces: keep line numbers, hide real file names.
# The Crashlytics plugin uploads mapping.txt so traces are deobfuscated.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-keep public class * extends java.lang.Exception
