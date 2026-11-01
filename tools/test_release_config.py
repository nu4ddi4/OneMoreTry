import unittest
from release_config import plan, verify

PROJECT = 'config/version="0.5.0"\nconfig/release_channel="stable"\n'
PRESETS = 'application/file_version="0.5.0.0"\napplication/product_version="0.5.0.0"\n'


class ReleaseTests(unittest.TestCase):
    def test_channel_identity(self):
        stable = plan(PROJECT, PRESETS, 'main', 'abc')
        beta = plan(PROJECT, PRESETS, 'beta', 'abc')
        self.assertEqual(stable['tag'], 'v0.5.0')
        self.assertFalse(stable['prerelease'])
        self.assertEqual(beta['tag'], 'v0.5.0-beta')
        self.assertTrue(beta['prerelease'])
        verify(beta, beta, 'abc')
        with self.assertRaises(ValueError):
            verify(beta, stable, 'abc')
        with self.assertRaises(ValueError):
            verify(beta, beta, 'other-commit')

    def test_invalid_version_or_branch(self):
        for version in ['0.5.0-beta', '01.5.0', '../0.5.0', '0.5']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                plan(f'config/version="{version}"', PRESETS, 'beta', 'abc')
        with self.assertRaises(ValueError):
            plan(PROJECT, PRESETS, 'feature/test', 'abc')
        with self.assertRaises(ValueError):
            plan(PROJECT, PRESETS.replace('0.5.0.0', '0.4.9.0'), 'beta', 'abc')


if __name__ == '__main__':
    unittest.main()
