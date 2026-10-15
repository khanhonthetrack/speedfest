'use strict';
// Tiny timestamped logger. LOG_LEVEL=silent (or createServer({quiet:true})) mutes it.

let quiet = process.env.LOG_LEVEL === 'silent';

function stamp() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

function log(...args) {
  if (!quiet) console.log(stamp(), ...args);
}

function warn(...args) {
  if (!quiet) console.warn(stamp(), 'WARN', ...args);
}

function setQuiet(q) {
  quiet = !!q;
}

module.exports = { log, warn, setQuiet };
