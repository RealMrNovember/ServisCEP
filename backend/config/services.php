<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Web (Filament tenant panel) Google Sign-In — bkz. docs/09 § 0.
    // ⚠️ Mobil tarafta ayrı bir "Android" tipi OAuth client kullanılır,
    // bu web client'tan farklıdır. Client ID/secret asla repoya commit
    // edilmez, yalnızca sunucu .env dosyasında tutulur.
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('GOOGLE_REDIRECT_URI'),
    ],

    // Firebase Cloud Messaging (push bildirimleri) — bkz. FcmService.
    // Anahtar dosyası repoda DEĞİLDİR; yalnızca sunucuda 600 izinle durur.
    // Tanımlı değilse push sessizce devre dışı kalır (yerel/CI ortamları).
    'fcm' => [
        'credentials' => env('FIREBASE_CREDENTIALS'),
        'project_id' => env('FIREBASE_PROJECT_ID', 'serviscep'),
    ],

    // Barkod sorgusu sağlayıcıları — bkz. GlobalBarcodeLookup.
    //
    // Open*Facts anahtar istemiyor ama GIDA/kozmetik kapsıyor. Bu
    // uygulamanın kullanıcıları elektronik ve teknik malzeme stokluyor
    // (güvenlik kamerası, switch, kablo); onlar için genel ticari ürün
    // kapsayan bir kaynak şart.
    //
    // upcitemdb: anahtarsız "trial" ucu günde 100 sorgu (IP başına).
    // Anahtar tanımlanırsa ücretli uca geçilir ve sınır kalkar.
    //
    // barcodelookup: anahtar YOKSA hiç denenmez. Elektronikte kapsamı
    // belirgin biçimde daha iyi ama ücretli.
    'barcode' => [
        'upcitemdb_key' => env('UPCITEMDB_KEY', ''),
        'barcodelookup_key' => env('BARCODELOOKUP_KEY', ''),
    ],

    // Sürüm hattının yayındaki sürümü sunucuya bildirmesi için paylaşılan
    // jeton. Boşsa uç 503 döner — parolasız açık kalmasındansa kapalı
    // olması yeğdir.
    'app_version' => [
        'publish_token' => env('APP_VERSION_PUBLISH_TOKEN', ''),
    ],

];
