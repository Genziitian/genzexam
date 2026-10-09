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
    ],

    'razorpay' => [
        'key_id' => env('RAZORPAY_KEY_ID'),
        'key_secret' => env('RAZORPAY_KEY_SECRET'),
        'webhook_secret' => env('RAZORPAY_WEBHOOK_SECRET'),
    ],

    'google_play' => [
        'package_name' => env('GOOGLE_PLAY_PACKAGE_NAME'),
        'subscription_product_id' => env('GOOGLE_PLAY_PRO_PRODUCT_ID'),
        'subscription_base_plan_id' => env('GOOGLE_PLAY_PRO_BASE_PLAN_ID'),
        'regions_version' => env('GOOGLE_PLAY_REGIONS_VERSION', '2022/02'),
        'trial_offer_id' => env('GOOGLE_PLAY_PRO_TRIAL_OFFER_ID'),
        'service_account_json' => env('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'),
        'rtdn_topic' => env('GOOGLE_PLAY_RTDN_TOPIC'),
    ],

];
