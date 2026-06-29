'use strict';

const path = require('path');

// Resolve the package root (the install location) relative to this module, so
// asset lookups are independent of the caller's cwd and survive `npm link`.
// lib/ sits directly under the package root, so one level up is the root.
const ASSET_ROOT = path.resolve(__dirname, '..');

module.exports = { ASSET_ROOT };
