#!/usr/bin/env bash
# Imports every paper JSON under bulk_quizzes/ into its course.
# Safe to run again: papers whose title already exists in the course are skipped.
# Preview only:  bash tools/import_all_papers.sh --dry-run
cd "$(dirname "$0")/../backend" || exit 1

import() { # <course slug> <folder under bulk_quizzes>
  echo "=== $1"
  php artisan quizzes:import "$1" "../bulk_quizzes/$2" "${@:3}" | tail -n 1
}

EXTRA=("$@")
# Diploma subjects without a course yet (Deep Learning, Tools in Data Science) are created first.
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
echo "All done."
