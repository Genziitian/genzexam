#!/usr/bin/env bash
# Imports ONLY the reviewed papers listed in docs/question-extraction/verified-batch-manifest.json,
# each into the course that matches its subject. Papers already in the course (same title) are skipped,
# so existing questions and attempts are never touched. Run from anywhere after `git pull` on the API server.
# Preview only:  bash tools/sync_verified_papers.sh --dry-run
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend" || exit 1
php -r '
$map = ["English 1"=>"english-1","English 2"=>"english-2","Mathematics 1"=>"mathematics-1","Mathematics 2"=>"mathematics-2",
        "Computational Thinking"=>"computational-thinking","Python"=>"python","Statistics 1"=>"statistics-1","Statistics 2"=>"statistics-2"];
$m = json_decode(file_get_contents("../docs/question-extraction/verified-batch-manifest.json"), true);
foreach ($m["files"] as $f) {
    if (!isset($map[$f["subject"]])) { fwrite(STDERR, "UNKNOWN SUBJECT: {$f["subject"]}\n"); exit(1); }
    echo $map[$f["subject"]], "\t", $f["path"], "\n";
}' > /tmp/verified_papers.tsv || exit 1
created=0; skipped=0; failed=0
while IFS=$'\t' read -r slug file; do
  out=$(php artisan quizzes:import "$slug" "../$file" "$@" 2>&1 | tail -n 1)
  echo "$slug  $(basename "$file")  ->  $out"
done < /tmp/verified_papers.tsv
echo "Done: $(wc -l < /tmp/verified_papers.tsv) verified papers checked."
