#!/usr/bin/env bash
set -euo pipefail
umask 077

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
backend_dir=${1:-"$HOME/domains/labapi.genziitian.in/public_html/backend"}
backend_dir=$(CDPATH= cd -- "$backend_dir" && pwd)
private_dir=$(dirname -- "$(dirname -- "$backend_dir")")/private
billing_file="$private_dir/teaching-lms-4e59e7438b03.json"

fail() { printf '%s\n' "$1" >&2; exit 1; }
[[ -r "$backend_dir/.env" && -f "$backend_dir/artisan" && -f "$backend_dir/routes/api.php" ]] || fail 'Expected Laravel backend files are missing. No changes made.'
[[ -d "$private_dir" && -r "$billing_file" ]] || fail 'Private billing JSON is not readable at the expected path. No changes made.'
[[ ! -L "$backend_dir/.env" && ! -L "$backend_dir/routes/api.php" ]] || fail 'Environment or routes are symlinked. No changes made; inspect their real targets first.'
for payload in StudentRewardController.php rewards-routes.php; do
    [[ -f "$package_dir/$payload" ]] || fail "Package file missing: $payload"
    php -n -l "$package_dir/$payload"
done
grep -Fq '?>' "$backend_dir/routes/api.php" && fail 'api.php has a closing PHP tag. No changes made; the include must be added inside PHP.'

backup_dir=$(mktemp -d "$private_dir/quizlab-recovery-XXXXXXXX")
chmod 700 "$backup_dir"
cp -p "$backend_dir/.env" "$backup_dir/env.original"
chmod 600 "$backup_dir/env.original"
cp -p "$backend_dir/routes/api.php" "$backup_dir/api.original.php"
for relative in app/Http/Controllers/StudentRewardController.php routes/quizlab-rewards-recovery.php; do
    if [[ -f "$backend_dir/$relative" ]]; then
        cp -p "$backend_dir/$relative" "$backup_dir/$(basename -- "$relative").original"
    fi
done

# Strip all old assignments for these six keys, then write exactly one of each.
# Other environment entries, including Razorpay, DB, APP_KEY and RTDN, are kept.
awk -v billing_file="$billing_file" '
BEGIN {
    values["GOOGLE_PLAY_PACKAGE_NAME"] = "in.genziitian.quizlab"
    values["GOOGLE_PLAY_PRO_PRODUCT_ID"] = "quiz_lab_pro_monthly"
    values["GOOGLE_PLAY_PRO_BASE_PLAN_ID"] = "monthly"
    values["GOOGLE_PLAY_PRO_ANNUAL_BASE_PLAN_ID"] = "annual"
    values["GOOGLE_PLAY_PRO_TRIAL_OFFER_ID"] = "trial-7-days"
    values["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"] = billing_file
}
{
    probe = $0
    sub(/\r$/, "", probe)
    sub(/^[ \t]*/, "", probe)
    sub(/^export[ \t]+/, "", probe)
    if (probe ~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) {
        key = probe
        sub(/[ \t]*=.*/, "", key)
        if (key in values) next
    }
    print $0
}
END { for (key in values) print key "=" values[key] }
' "$backend_dir/.env" > "$backup_dir/env.next"

cp -p "$backend_dir/routes/api.php" "$backup_dir/api.next.php"
include_line="require_once __DIR__.'/quizlab-rewards-recovery.php';"
if ! grep -Fq "$include_line" "$backup_dir/api.next.php"; then
    printf '\n%s\n' "$include_line" >> "$backup_dir/api.next.php"
fi
php -n -l "$backup_dir/api.next.php"

cp "$package_dir/StudentRewardController.php" "$backup_dir/controller.next.php"
cp "$package_dir/rewards-routes.php" "$backup_dir/rewards.next.php"
chmod 644 "$backup_dir/controller.next.php" "$backup_dir/rewards.next.php"
mv "$backup_dir/controller.next.php" "$backend_dir/app/Http/Controllers/StudentRewardController.php"
mv "$backup_dir/rewards.next.php" "$backend_dir/routes/quizlab-rewards-recovery.php"
mv "$backup_dir/api.next.php" "$backend_dir/routes/api.php"
mv "$backup_dir/env.next" "$backend_dir/.env"

cd -- "$backend_dir"
php artisan config:clear
php artisan route:clear
# Do not run cache:clear or optimize:clear: rewards and daily quotas use cache.
php artisan tinker --execute='
$ready = true;
foreach (["package_name", "subscription_product_id", "service_account_json"] as $key) {
    $loaded = (bool) config("services.google_play.".$key);
    $ready = $ready && $loaded;
    dump([$key => $loaded]);
}
$p = config("services.google_play.service_account_json");
$readable = is_string($p) && is_file($p) && is_readable($p);
dump(["billing_file_readable" => $readable, "checkout_ready" => $ready]);
if (! $ready || ! $readable) { throw new RuntimeException("Billing configuration is still incomplete."); }
'
php artisan route:list --path=student/rewards
printf '\nRecovery installed. Private backups: %s\n' "$backup_dir"
printf 'Reopen the app and test rewards plus checkout. Provider authorization and a real purchase still need verification.\n'
