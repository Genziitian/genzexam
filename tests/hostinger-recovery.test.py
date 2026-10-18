"""Exercise the installer in a temporary host layout, never a real .env."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'docs' / 'hostinger-recovery'


class HostingerRecoveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='quizlab-recovery-test-')
        self.root = Path(self.temp.name)
        self.backend = self.root / 'domain' / 'public_html' / 'backend'
        self.private = self.root / 'domain' / 'private'
        self.package = self.private / 'package'
        self.package.mkdir(parents=True)
        (self.backend / 'routes').mkdir(parents=True)
        (self.backend / 'app/Http/Controllers').mkdir(parents=True)
        (self.backend / 'artisan').touch()
        self.original_env = (
            'APP_KEY=fixture-only-key\nDB_PASSWORD="fixture-only password"\n'
            '# GOOGLE_PLAY_PACKAGE_NAME=comment\n'
            'GOOGLE_PLAY_PACKAGE_NAME=old\n'
            ' export GOOGLE_PLAY_PACKAGE_NAME =duplicate\n'
            'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=old\nRAZORPAY_KEY_ID=fixture-only'
        )
        (self.backend / '.env').write_text(self.original_env)
        (self.backend / 'routes/api.php').write_text('<?php\n// Existing API routes retained.\n')
        (self.private / 'teaching-lms-4e59e7438b03.json').write_text('{}')
        for filename in ('install.sh', 'rewards-routes.php'):
            shutil.copyfile(PACKAGE / filename, self.package / filename)
        shutil.copyfile(ROOT / 'backend/app/Http/Controllers/StudentRewardController.php',
                        self.package / 'StudentRewardController.php')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fake_php = self.bin / 'php'
        fake_php.write_text('#!/bin/sh\nif [ "$1" = "-n" ] && [ "${FAIL_LINT:-}" = 1 ]; then exit 139; fi\nexit 0\n')
        fake_php.chmod(0o755)
        self.environment = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH']}

    def tearDown(self):
        self.temp.cleanup()

    def run_installer(self, **variables):
        return subprocess.run(['bash', str(self.package / 'install.sh'), str(self.backend)],
                              env={**self.environment, **variables}, text=True, capture_output=True)

    def test_update_preserves_other_settings_backups_and_is_idempotent(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = (self.backend / '.env').read_text()
        self.assertIn('APP_KEY=fixture-only-key\nDB_PASSWORD="fixture-only password"', text)
        self.assertIn('RAZORPAY_KEY_ID=fixture-only\n', text)
        self.assertEqual(text.count('\nGOOGLE_PLAY_PACKAGE_NAME='), 1)
        self.assertIn('GOOGLE_PLAY_PACKAGE_NAME=in.genziitian.quizlab\n', text)
        self.assertNotIn('=duplicate', text)
        self.assertEqual((self.backend / '.env').stat().st_mode & 0o777, 0o600)
        backups = list(self.private.glob('quizlab-recovery-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'env.original').read_text(), self.original_env)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o700)
        self.assertNotIn('fixture-only', result.stdout + result.stderr)
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.backend / '.env').read_text(), text)
        routes = (self.backend / 'routes/api.php').read_text()
        self.assertIn('// Existing API routes retained.', routes)
        self.assertEqual(routes.count("require_once __DIR__.'/quizlab-rewards-recovery.php';"), 1)

    def test_missing_billing_file_does_not_change_environment_or_routes(self):
        (self.private / 'teaching-lms-4e59e7438b03.json').unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.backend / '.env').read_text(), self.original_env)
        self.assertFalse((self.backend / 'routes/quizlab-rewards-recovery.php').exists())

    def test_linter_crash_does_not_change_environment_or_routes(self):
        result = self.run_installer(FAIL_LINT='1')
        self.assertEqual(result.returncode, 139)
        self.assertEqual((self.backend / '.env').read_text(), self.original_env)
        self.assertFalse((self.backend / 'routes/quizlab-rewards-recovery.php').exists())

    def test_closing_php_tag_is_rejected_before_modifying_the_route_file(self):
        original = '<?php\n?>\n'
        (self.backend / 'routes/api.php').write_text(original)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.backend / 'routes/api.php').read_text(), original)
        self.assertEqual((self.backend / '.env').read_text(), self.original_env)


if __name__ == '__main__':
    unittest.main()
