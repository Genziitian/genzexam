#!/usr/bin/env bash
# Imports every paper JSON under bulk_quizzes/ into its course.
# Safe to run again: papers whose title already exists in the course are skipped.
# Preview only:  bash tools/import_all_papers.sh --dry-run
cd "$(dirname "$0")/../backend" || exit 1

DONE="|"
import() { # <course slug> <folder under bulk_quizzes>
  DONE="$DONE$2|"
  echo "=== $1"
  php artisan quizzes:import "$1" "../bulk_quizzes/$2" "${@:3}" | tail -n 1
}

EXTRA=("$@")
# Diploma subjects without a course yet, and the "Unknown" holding course, are created first.
[ "${EXTRA[0]}" = "--dry-run" ] || php artisan db:seed --class=ExtraDiplomaCoursesSeeder --force
import computational-thinking "Computational Thinking" "${EXTRA[@]}"
import mathematics-1 "Mathematics 1" "${EXTRA[@]}"
import mathematics-2 "Mathematics 2" "${EXTRA[@]}"
import statistics-1 "Statistics 1" "${EXTRA[@]}"
import statistics-2 "Statistics 2" "${EXTRA[@]}"
import python "Python" "${EXTRA[@]}"
import english-1 "English 1" "${EXTRA[@]}"
import english-2 "English 2" "${EXTRA[@]}"
import business-analytics "Diploma/Business Analytics" "${EXTRA[@]}"
import business-data-management "Diploma/Business Data Management" "${EXTRA[@]}"
import dbms "Diploma/DBMS" "${EXTRA[@]}"
import dlgenai "Diploma/Dlgenai" "${EXTRA[@]}"
import game-theory-strategy "Diploma/Game Theory And Strategy" "${EXTRA[@]}"
import machine-learning-foundations "Diploma/Machine Learning Foundations" "${EXTRA[@]}"
import machine-learning-practice "Diploma/Machine Learning Practice" "${EXTRA[@]}"
import machine-learning-techniques "Diploma/Machine Learning Techniques" "${EXTRA[@]}"
import modern-application-development-1 "Diploma/Modern Application Development 1" "${EXTRA[@]}"
import modern-application-development-2 "Diploma/Modern Application Development 2" "${EXTRA[@]}"
import pdsa "Diploma/PDSA" "${EXTRA[@]}"
import system-commands "Diploma/System Commands" "${EXTRA[@]}"
# Diploma folders that belong to the same courses as the Foundation ones
import computational-thinking "Diploma/Computational Thinking" "${EXTRA[@]}"
import mathematics-1 "Diploma/Mathematics 1" "${EXTRA[@]}"
import mathematics-1 "Diploma/Sem1 Maths1" "${EXTRA[@]}"
import mathematics-2 "Diploma/Mathematics 2" "${EXTRA[@]}"
import mathematics-2 "Diploma/Sem2 Maths2" "${EXTRA[@]}"
import statistics-1 "Diploma/Statistics 1" "${EXTRA[@]}"
import statistics-1 "Diploma/Sem1 Statistics1" "${EXTRA[@]}"
import statistics-2 "Diploma/Statistics 2" "${EXTRA[@]}"
import statistics-2 "Diploma/Sem2 Statistics2" "${EXTRA[@]}"
import python "Diploma/Python Programming" "${EXTRA[@]}"
import deep-learning "Diploma/Deep Learning" "${EXTRA[@]}"
import tools-in-data-science "Diploma/Tds" "${EXTRA[@]}"
import deep-learning-practice "Diploma/Dlp" "${EXTRA[@]}"
import large-language-models "Diploma/Llm" "${EXTRA[@]}"
import software-engineering "Diploma/Sw Engg" "${EXTRA[@]}"
import software-testing "Diploma/Sw Testing" "${EXTRA[@]}"
import managerial-economics "Diploma/Managerial Economics" "${EXTRA[@]}"
# Any folder with paper files that is not listed above goes to the "Unknown" course for sorting later.
find ../bulk_quizzes -mindepth 1 -maxdepth 2 -type d | sort | while IFS= read -r dir; do
  rel="${dir#../bulk_quizzes/}"
  case "$DONE" in *"|$rel|"*) continue ;; esac
  ls "$dir"/*.json >/dev/null 2>&1 || continue
  echo "(unlisted folder: $rel)"
  import unknown "$rel" "${EXTRA[@]}"
done
echo "All done."
