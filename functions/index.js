const functions = require('firebase-functions/v1');
const https = require('https');

const VDGL_API_KEY = 'D5D22850-71A0-4523-8DBA-7CE4B5361B3D';
const VDGL_BASE = 'https://uk.api.vehicledataglobal.com';

exports.vdglProxy = functions.https.onRequest((req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const vrm = req.query.vrm || req.body?.vrm;
  const packageName = req.query.package || req.body?.package || 'DataPackage2';

  if (!vrm) {
    return res.status(400).json({ error: 'Missing vrm parameter' });
  }

  const params = new URLSearchParams({
    ApiKey: VDGL_API_KEY,
    PackageName: packageName,
    Vrm: vrm,
  });

  const url = VDGL_BASE + '/r2/lookup?' + params.toString();

  https.get(url, (apiRes) => {
    let data = '';
    apiRes.on('data', (chunk) => { data += chunk; });
    apiRes.on('end', () => {
      try {
        const json = JSON.parse(data);
        res.status(apiRes.statusCode).json(json);
      } catch (e) {
        res.status(500).json({ error: 'Failed to parse VDGL response' });
      }
    });
  }).on('error', (err) => {
    res.status(500).json({ error: 'VDGL request failed: ' + err.message });
  });
});
