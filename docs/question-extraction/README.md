# Question extraction handoff

Reports retain original source paths on the extraction Mac. The completed release package is local under output/deployment/quizlab-image-support-2026-10-19/ and is intentionally not committed. OCR models and caches are local under output/ocr-tools/ and output/question-extraction-2026-10-19/.

The verified-batch-manifest.json records the last fully packaged batch: 910 questions in 115 papers. Later Computational Thinking exports (115 questions) need final combined verification. Statistics 1 native exports (120 questions) are drafts awaiting final visual/diagram review; do not bulk-publish them yet. Mathematics 1 and Statistics 1 raster recovery remain unfinished. Missing source content and exclusions are recorded in subject reports.

Recovery scripts in tools/question-extraction/ are preserved for continuation. They were run from output/question-extraction-2026-10-19/ with local caches beside them; copy them back there or adjust their ROOT before rerunning. Do not rerun blindly: some scripts overwrite existing papers.

Crop images are versioned under assets/exam-examples/question-crops/. JSON links use those same site-relative paths. Deploy assets alongside the papers. Website/backend/app image-support changes are locally tested but are not evidence of hosting or Play Store publication.
