// See all configuration options: https://remotion.dev/docs/config
// Each option also is available as a CLI flag: https://remotion.dev/docs/cli

// Note: When using the Node.JS APIs, the config file doesn't apply. Instead, pass options directly to the APIs

import { Config } from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);

// This cloud environment has Chromium pre-installed; without these settings
// Remotion tries to download its own headless browser (and the full Chromium
// binary no longer supports the old headless mode Remotion defaults to).
Config.setBrowserExecutable("/opt/pw-browsers/chromium");
Config.setChromeMode("chrome-for-testing");
