# R8/ProGuard 유지 규칙
#
# ⚠️ 이 파일이 없어서 **프로덕션 앱이 켤 때마다 죽었다**(2026-08-29, 1.0.6+20260830).
#     java.lang.RuntimeException: Missing type parameter.
#       at FlutterLocalNotificationsPlugin.loadScheduledNotifications
#       at ScheduledNotificationBootReceiver.onReceive
#
# 원인: flutter_local_notifications 가 예약 알림을 Gson 으로 읽으면서
# `TypeToken<ArrayList<NotificationDetails>>` 같은 **제네릭 타입 정보**를 쓴다.
# R8 은 기본으로 `Signature` 속성을 지운다 → Gson 이 타입 파라미터를 못 찾고 던진다.
# 앱 프로세스가 뜨자마자 부팅 리시버가 돌기 때문에 **실행 자체가 불가능**해진다.
#
# 그래서 아래 둘은 세트다: 클래스를 남기는 것(-keep)만으로는 부족하고
# **제네릭 서명(-keepattributes Signature)** 을 남겨야 한다.

# ── flutter_local_notifications (+ Gson 모델) ──
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Gson 이 리플렉션으로 읽는 필드는 R8 이 "안 쓰인다"고 판단해 지운다.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# ── Play Core (Flutter 의 지연 컴포넌트) ──
# 쓰지 않지만 Flutter 가 참조해 R8 경고가 뜬다. 없는 클래스는 무시한다.
-dontwarn com.google.android.play.core.**
