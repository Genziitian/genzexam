<?php

use Illuminate\Support\Facades\Route;

// Public legal pages: these routes intentionally have no authentication middleware.
Route::get('/privacy-policy', fn () => response()->file(public_path('privacy.html'), ['Content-Type' => 'text/html; charset=UTF-8']));
Route::get('/terms-and-conditions', fn () => response()->file(public_path('terms.html'), ['Content-Type' => 'text/html; charset=UTF-8']));
Route::get('/refund-policy', fn () => response()->file(public_path('refund-policy.html'), ['Content-Type' => 'text/html; charset=UTF-8']));
Route::get('/delete-account', fn () => response()->file(public_path('delete-account.html'), ['Content-Type' => 'text/html; charset=UTF-8']));

Route::get('/', function () {
    return view('welcome');
});
