#!/usr/bin/env node
/**
 * Fake amdl runner for testing.
 * Emits JSON AddedTrack[] when given valid URL or fails if --fail flag/url passed.
 */

const args = process.argv.slice(2);
const jsonFlag = args.includes('--json');
const url = args.find(a => !a.startsWith('--'));

const isSlow = args.includes('--slow') || (url && url.includes('cancel'));

if (isSlow) {
  setTimeout(() => {
    process.exit(0);
  }, 10000);
}

if (!url || url.includes('invalid') || url.includes('fail')) {
  console.error('Error: Failed to process URL');
  process.exit(1);
}

// Simulating progress output
console.log('Resolving catalog URL: ' + url);
console.log('Downloading track: Mock Track 1');
console.log('Transcoding to flac...');

if (jsonFlag) {
  const result = [
    {
      path: '/tmp/Music/Test/Track1.flac',
      artist: 'Test Artist',
      artist_id: '12345',
      album: 'Test Album',
      song: 'Mock Track 1'
    }
  ];
  console.log(JSON.stringify(result));
}

if (!isSlow) {
  process.exit(0);
}

