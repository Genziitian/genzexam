Quiz LAB: Hostinger billing environment and missing rewards routes recovery

1. Upload quizlab-billing-rewards-recovery.zip into the API domain's private
   directory: /home/u404320264/domains/labapi.genziitian.in/private
2. Extract it there. It creates quizlab-billing-rewards-recovery/.
3. In Hostinger SSH run:

bash ~/domains/labapi.genziitian.in/private/quizlab-billing-rewards-recovery/install.sh

The installer uses shell/awk for environment updates; it does not run PHP source
from stdin. PHP is used only for syntax checking and the existing artisan CLI.
If syntax checking crashes, it stops before changing the application files.

It backs up the original .env, routes/api.php, and any existing rewards controller
and recovery routes under a fresh private/quizlab-recovery-* directory. .env
backups have private permissions. Do not copy these backups into public_html or
paste their contents into a chat.

It updates six Google Play environment entries, copies the rewards controller,
adds routes/quizlab-rewards-recovery.php, and appends one guarded require_once to
api.php. It does not replace the API route file. Existing matching routes win;
rerunning the installer does not add duplicate route includes or env assignments.
Other settings, including APP_KEY, DB, Razorpay and RTDN, are preserved.

Only configuration and route caches are cleared. Application cache is preserved
because existing reward records, quotas and bonus passes are stored there.
The existing cache/cache_locks and Pro subscription tables are prerequisites.
No migration, service-account key, .env, vendor folder, APK or AAB is packaged.

Rewards routes require authentication. The manager log additionally requires a
manager. Claims require an owned, valid, unclaimed Pro reward. A per-user lock
serializes spin/scratch/claim requests and an existing subscription reference
prevents a stale cache from re-granting an already claimed Pro reward.

Expected output: the three configuration flags and billing_file_readable are
true, followed by four student rewards routes. Then reopen the app. Prices,
server configuration presence and registered routes do not establish successful
Google authorization, purchase verification, or redeemed coupon/payment flows.

Rollback (if needed): use the private backup directory printed by the installer.
Restore env.original to backend/.env and api.original.php to backend/routes/api.php;
restore controller/recovery-route originals if present. Clear config and routes
again. Do not clear application cache. Keep the backups private.
