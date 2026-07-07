import fs from 'fs';
import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);

// Claude Code on the web blocks downloads from remotion.media, but the
// container ships Playwright's Chromium headless shell — use it when present.
const pwBrowsers = '/opt/pw-browsers';
if (fs.existsSync(pwBrowsers)) {
  const shellDir = fs
    .readdirSync(pwBrowsers)
    .find((d) => d.startsWith('chromium_headless_shell-'));
  if (shellDir) {
    const shell = `${pwBrowsers}/${shellDir}/chrome-linux/headless_shell`;
    if (fs.existsSync(shell)) {
      Config.setBrowserExecutable(shell);
    }
  }
}
