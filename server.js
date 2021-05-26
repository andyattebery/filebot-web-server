'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const express = require('express');

// Config
const HOST = '0.0.0.0';
const PORT = process.env.PORT;
const FILEBOT_OUTPUT_DIR = process.env.FILEBOT_OUTPUT_DIR;
const FILEBOT_LOGS_DIR = process.env.FILEBOT_LOGS_DIR;
const FILEBOT_SUBTITLE_LANGUAGES = process.env.FILEBOT_SUBTITLE_LANGUAGES;
const PLEX_HOST = process.env.PLEX_HOST;
const PLEX_TOKEN = process.env.PLEX_TOKEN;
const PUSHOVER_TOKEN = process.env.PUSHOVER_TOKEN;

// App
const app = express();
app.get('/amc', (req, res) => {
  const result = runFilebotAmc(req.query.dir, req.query.title, req.query.label)

  const responseText = `\n \
  status: ${result.status}\n\n \
  stdout: ${result.stdout.toString()}\n \
  stderr: ${result.stderr.toString()}\n \
  error: ${result.result}\n \
  `;
  res.set('Content-Type', 'text/plain')
  res.send(responseText);
});

function runFilebotAmc(dir, title, label) {
  var args = [
    '-script', 'fn:amc',
    '--output', FILEBOT_OUTPUT_DIR,
    '--log-file', path.join(FILEBOT_LOGS_DIR, 'amc.log'),
    '--action', 'copy',
    '--conflict', 'override',
    '-non-strict',
    '--def',
    'clean=y',
    'ut_kind=multi',
    `ut_dir=${dir}`,
    `ut_title=${title}`,
    `ut_label=${label}`,
    'movieFormat=Movies/{n} ({y})/{fn}',
    "seriesFormat=TV Shows/{n}/{episode.special ? 'Special' : 'Season '+s.pad(2)}/{fn}"
  ];

  if (FILEBOT_SUBTITLE_LANGUAGES) {
    args.push(`subtitles=${FILEBOT_SUBTITLE_LANGUAGES}`);
  }
  if (PLEX_HOST && PLEX_TOKEN) {
    args.push(`plex=${PLEX_HOST}:${PLEX_TOKEN}`);
  }
  if (PUSHOVER_TOKEN) {
    args.push(`pushover=${PUSHOVER_TOKEN}`);
  }

  return spawnSync('/opt/filebot/filebot.sh', args);
}

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);