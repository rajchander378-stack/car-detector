const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const https = require('https');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

const VDGL_API_KEY = 'D5D22850-71A0-4523-8DBA-7CE4B5361B3D';
const VDGL_BASE = 'https://uk.api.vehicledataglobal.com';

// Cost per package in GBP (what VDGL charges us)
const PACKAGE_COSTS = {
  DataPackage2: 0.50,
  ValuationDetails: 0.20,
  MotHistoryDetails: 0.06,
  VehicleDetails: 0.15,
  TyreDetails: 0.09,
};

function hashVrm(vrm) {
  return crypto.createHash('sha256').update(vrm.toUpperCase().replace(/\s/g, '')).digest('hex').substring(0, 12);
}

async function logVdglCall(packageName, vrm, success, statusCode, source) {
  try {
    const now = new Date();
    const dayKey = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const monthKey = dayKey.substring(0, 7);         // YYYY-MM
    const cost = PACKAGE_COSTS[packageName] || 0;

    // Log individual call
    await db.collection('vdgl_usage').add({
      vrm_hash: hashVrm(vrm),
      package: packageName,
      cost_gbp: cost,
      success: success,
      status_code: statusCode,
      source: source || 'proxy',
      day: dayKey,
      month: monthKey,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update daily aggregate counter
    const counterRef = db.collection('vdgl_counters').doc(dayKey);
    await counterRef.set({
      calls: admin.firestore.FieldValue.increment(1),
      cost_gbp: admin.firestore.FieldValue.increment(cost),
      success_count: admin.firestore.FieldValue.increment(success ? 1 : 0),
      error_count: admin.firestore.FieldValue.increment(success ? 0 : 1),
      month: monthKey,
      last_call: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Update package-level counter for the day
    const pkgField = 'pkg_' + packageName;
    await counterRef.set({
      [pkgField]: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  } catch (e) {
    console.error('Failed to log VDGL usage:', e);
    // Don't block the response if logging fails
  }
}

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
  const source = req.query.source || req.body?.source || 'web';

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
        const success = apiRes.statusCode === 200
          && json.ResponseInformation?.IsSuccessStatusCode !== false;
        // Log the call (fire-and-forget, don't delay response)
        logVdglCall(packageName, vrm, success, apiRes.statusCode, source);
        res.status(apiRes.statusCode).json(json);
      } catch (e) {
        logVdglCall(packageName, vrm, false, apiRes.statusCode, source);
        res.status(500).json({ error: 'Failed to parse VDGL response' });
      }
    });
  }).on('error', (err) => {
    logVdglCall(packageName, vrm, false, 0, source);
    res.status(500).json({ error: 'VDGL request failed: ' + err.message });
  });
});
