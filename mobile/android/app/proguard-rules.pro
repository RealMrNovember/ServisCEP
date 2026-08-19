# Google Sign-In / Play Services Auth / Credential Manager, reflection ile
# calisan siniflar icerdiginden R8 tam mod + kod karartma altinda kirilabilir
# (yayin derlemesinde sessizce "Google ile giris basarisiz oldu" hatasina yol
# acar, debug derlemede R8 kapali oldugu icin fark edilmez).
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }

-keepattributes Signature
-keepattributes *Annotation*
