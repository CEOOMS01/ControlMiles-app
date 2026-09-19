# Olympus Mont Systems LLC - ControlMiles
# android/app/proguard-rules.pro
#
# BUG FIX (found live, 2026-09-19, first real `flutter build appbundle
# --release` ever run for this app): R8 failed the build entirely --
# google_mlkit_text_recognition's TextRecognizer.initialize() references
# the Chinese/Devanagari/Japanese/Korean script recognizer classes, but
# this app only depends on the default (Latin) text-recognition module
# (see pubspec.yaml -- odometer OCR only needs Latin digits/letters).
# Those other four script modules were never added as dependencies, so
# R8 can't find their classes and refuses to produce an APK/AAB.
#
# This is Google's own documented fix for this exact situation (ML Kit's
# samples ship the same rule): the app never calls into these script
# recognizers at runtime, so the missing classes are dead code paths --
# safe to tell R8 to stop erroring, not a real behavior change.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
