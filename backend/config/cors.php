<?php

$configuredOrigins = array_filter(array_map(
    'trim',
    explode(',', (string) env(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173'
    ))
));

return [
    'paths' => ['api/*', 'public/api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    // The production web app calls the API from this origin. Keep it allowed even
    // when a deployment's CORS_ALLOWED_ORIGINS still lists the former web domain.
    'allowed_origins' => array_values(array_unique(array_merge(
        ['https://quiz.genziitian.in'],
        $configuredOrigins
    ))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => ['Authorization'],
    'max_age' => 0,
    'supports_credentials' => true,
];
