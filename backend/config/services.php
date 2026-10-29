<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
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

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('GOOGLE_REDIRECT_URI'),
    ],

    'piston' => [
        'url' => env('PISTON_API_URL', 'https://emkc.org/api/v2/piston'),
    ],

    'deepseek' => [
        'key' => env('DEEPSEEK_API_KEY'),
        'endpoint' => env('DEEPSEEK_API_URL', 'https://api.deepseek.com/chat/completions'),
        'model' => env('DEEPSEEK_MODEL', 'deepseek-chat'),
        'max_input_chars' => (int) env('DEEPSEEK_MAX_INPUT_CHARS', 60000),
        'max_questions' => (int) env('DEEPSEEK_MAX_QUESTIONS', 100),
    ],

    'student_paper_uploads' => [
        'max_pdf_pages' => (int) env('STUDENT_PAPER_MAX_PDF_PAGES', 30),
        'daily_ai_conversions' => (int) env('STUDENT_PAPER_DAILY_AI_CONVERSIONS', 10),
        // Pro members may upload `limit` papers in any rolling `window_days` days.
        'limit' => (int) env('STUDENT_PAPER_UPLOAD_LIMIT', 5),
        // Free (non-Pro) accounts get this many uploads per window.
        'free_limit' => (int) env('STUDENT_PAPER_FREE_UPLOAD_LIMIT', 1),
        'window_days' => (int) env('STUDENT_PAPER_UPLOAD_WINDOW_DAYS', 7),
    ],

    'razorpay' => [
        'key_id' => env('RAZORPAY_KEY_ID'),
        'key_secret' => env('RAZORPAY_KEY_SECRET'),
        'webhook_secret' => env('RAZORPAY_WEBHOOK_SECRET'),
    ],

    'pro' => ['annual_price_paise' => (int) env('PRO_ANNUAL_PRICE_PAISE', 99900)],

    'google_play' => [
        'package_name' => env('GOOGLE_PLAY_PACKAGE_NAME'),
        'subscription_product_id' => env('GOOGLE_PLAY_PRO_PRODUCT_ID'),
        // One-time in-app products priced per whole rupee: paper_49 sells a Rs 49 paper.
        'paper_product_prefix' => env('GOOGLE_PLAY_PAPER_PRODUCT_PREFIX', 'paper_'),
        'annual_base_plan_id' => env('GOOGLE_PLAY_PRO_ANNUAL_BASE_PLAN_ID', 'annual'),
        'subscription_base_plan_id' => env('GOOGLE_PLAY_PRO_BASE_PLAN_ID'),
        'regions_version' => env('GOOGLE_PLAY_REGIONS_VERSION', '2022/02'),
        'trial_offer_id' => env('GOOGLE_PLAY_PRO_TRIAL_OFFER_ID', 'trial-7-days'),
        'service_account_json' => env('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'),
        'rtdn_topic' => env('GOOGLE_PLAY_RTDN_TOPIC'),
        'rtdn_subscription' => env('GOOGLE_PLAY_RTDN_SUBSCRIPTION'),
        'rtdn_audience' => env('GOOGLE_PLAY_RTDN_AUDIENCE'),
        'rtdn_service_account_email' => env('GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL'),
    ],

    'genz' => [
        'url' => env('GENZ_API_URL'),
        'key' => env('GENZ_API_KEY'),
    ],

];
