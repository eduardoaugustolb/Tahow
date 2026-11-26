import { execFileSync } from 'node:child_process';

const output = execFileSync('qs', ['-p', 'tests/fixtures/tray-startup/shell.qml'], {
  env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software' },
  encoding: 'utf8',
  timeout: 5000,
});
if (!output.includes('TRAY_STARTUP_OK')) throw new Error(output);
console.log('Tray strip startup geometry smoke check passed.');
