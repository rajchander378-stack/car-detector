const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const https = require('https');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// VDGL_API_KEY is injected from Secret Manager at runtime via runWith({ secrets })
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

// Wraps the raw HTTPS call in a Promise so async/await callers can use it.
function callVdglHttpRequest(vrm, packageName, mileage) {
  return new Promise((resolve, reject) => {
    const params = new URLSearchParams({
      ApiKey: process.env.VDGL_API_KEY,
      PackageName: packageName,
      Vrm: vrm,
    });
    if (mileage) params.set('Mileage', mileage.toString());

    const url = VDGL_BASE + '/r2/lookup?' + params.toString();

    https.get(url, (apiRes) => {
      let data = '';
      apiRes.on('data', (chunk) => { data += chunk; });
      apiRes.on('end', () => resolve({ statusCode: apiRes.statusCode, body: data }));
    }).on('error', reject);
  });
}

// Logs an individual VDGL call and updates daily + per-user monthly counters.
// uid is optional — web proxy calls don't carry one.
async function logVdglCall(packageName, vrm, success, statusCode, source, uid) {
  try {
    const now = new Date();
    const dayKey = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const monthKey = dayKey.substring(0, 7);         // YYYY-MM
    const cost = PACKAGE_COSTS[packageName] || 0;

    // Individual call log
    await db.collection('vdgl_usage').add({
      vrm_hash: hashVrm(vrm),
      package: packageName,
      cost_gbp: cost,
      success: success,
      status_code: statusCode,
      source: source || 'proxy',
      uid: uid || null,
      day: dayKey,
      month: monthKey,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Daily aggregate counter
    const counterRef = db.collection('vdgl_counters').doc(dayKey);
    const pkgField = 'pkg_' + packageName;
    await counterRef.set({
      calls: admin.firestore.FieldValue.increment(1),
      cost_gbp: admin.firestore.FieldValue.increment(cost),
      success_count: admin.firestore.FieldValue.increment(success ? 1 : 0),
      error_count: admin.firestore.FieldValue.increment(success ? 0 : 1),
      [pkgField]: admin.firestore.FieldValue.increment(1),
      month: monthKey,
      last_call: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Per-user monthly counter (only when uid is known)
    if (uid) {
      const userCounterRef = db.collection('vdgl_user_counters').doc(monthKey + '_' + uid);
      await userCounterRef.set({
        uid: uid,
        month: monthKey,
        calls: admin.firestore.FieldValue.increment(1),
        cost_gbp: admin.firestore.FieldValue.increment(cost),
        last_call: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  } catch (e) {
    console.error('Failed to log VDGL usage:', e);
    // Don't block the response if logging fails
  }
}

// ─── Callable function for Flutter ────────────────────────────────────────────
// Requires Firebase Auth. Logs with uid so every Flutter call is attributed.
exports.vdglLookup = functions.runWith({ secrets: ['VDGL_API_KEY'] }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = context.auth.uid;
  const vrm = (data.vrm || '').trim().toUpperCase();
  const packageName = data.package || 'DataPackage2';
  const mileage = data.mileage || null;

  if (!vrm) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing vrm parameter');
  }

  try {
    const { statusCode, body } = await Promise.race([
      callVdglHttpRequest(vrm, packageName, mileage),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('timeout')), 15000)
      ),
    ]);

    if (statusCode === 401) {
      logVdglCall(packageName, vrm, false, statusCode, 'flutter', uid);
      throw new functions.https.HttpsError('unauthenticated', 'API authentication failed');
    }
    if (statusCode === 429) {
      logVdglCall(packageName, vrm, false, statusCode, 'flutter', uid);
      throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded — try again later');
    }
    if (statusCode !== 200) {
      logVdglCall(packageName, vrm, false, statusCode, 'flutter', uid);
      throw new functions.https.HttpsError('unavailable', 'API returned status ' + statusCode);
    }

    const json = JSON.parse(body);
    const responseInfo = json.ResponseInformation || {};
    const isSuccess = responseInfo.IsSuccessStatusCode !== false;
    const vdglStatus = responseInfo.StatusCode;
    const statusMsg = responseInfo.StatusMessage || 'Lookup failed';

    if (!isSuccess || (vdglStatus !== 0 && vdglStatus !== 1)) {
      logVdglCall(packageName, vrm, false, statusCode, 'flutter', uid);
      throw new functions.https.HttpsError('failed-precondition', statusMsg);
    }

    logVdglCall(packageName, vrm, true, statusCode, 'flutter', uid);
    return json;

  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    // Network error or timeout
    logVdglCall(packageName, vrm, false, 0, 'flutter', uid);
    const msg = e.message === 'timeout' ? 'Request timed out' : 'VDGL request failed';
    throw new functions.https.HttpsError('unavailable', msg);
  }
});

// ─── HTTP proxy for web app ────────────────────────────────────────────────────
// Kept unchanged for web compatibility. uid is null on these calls.
exports.vdglProxy = functions.runWith({ secrets: ['VDGL_API_KEY'] }).https.onRequest((req, res) => {
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
    ApiKey: process.env.VDGL_API_KEY,
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
        logVdglCall(packageName, vrm, success, apiRes.statusCode, source, null);
        res.status(apiRes.statusCode).json(json);
      } catch (e) {
        logVdglCall(packageName, vrm, false, apiRes.statusCode, source, null);
        res.status(500).json({ error: 'Failed to parse VDGL response' });
      }
    });
  }).on('error', (err) => {
    logVdglCall(packageName, vrm, false, 0, source, null);
    res.status(500).json({ error: 'VDGL request failed: ' + err.message });
  });
});
