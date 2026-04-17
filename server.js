const express = require('express');
const path = require('path');
const os = require('os');
const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// STATE
// ============================================
let portalActive = true;
const connectedDevices = [];
const startTime = Date.now();

// Helper: get local IP
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

// Middleware: track connected devices
app.use((req, res, next) => {
  const ip = req.ip || req.connection?.remoteAddress || 'unknown';
  const userAgent = req.headers['user-agent'] || 'unknown';
  
  // Don't track admin panel requests
  if (req.path.startsWith('/admin') || req.path.startsWith('/api/')) {
    return next();
  }

  const existing = connectedDevices.find(d => d.ip === ip);
  if (existing) {
    existing.lastSeen = new Date().toLocaleTimeString('uz-UZ');
    existing.hits++;
  } else {
    connectedDevices.push({
      ip,
      device: parseDevice(userAgent),
      firstSeen: new Date().toLocaleTimeString('uz-UZ'),
      lastSeen: new Date().toLocaleTimeString('uz-UZ'),
      hits: 1
    });
  }
  next();
});

function parseDevice(ua) {
  if (/iPhone/.test(ua)) return '📱 iPhone';
  if (/iPad/.test(ua)) return '📱 iPad';
  if (/Android/.test(ua)) {
    const match = ua.match(/;\s*(.*?)\s*Build/);
    return '📱 ' + (match ? match[1] : 'Android');
  }
  if (/Mac/.test(ua)) return '💻 MacBook';
  if (/Windows/.test(ua)) return '💻 Windows';
  if (/Linux/.test(ua)) return '🐧 Linux';
  return '❓ Noma\'lum';
}

// ============================================
// API ENDPOINTS
// ============================================
app.get('/api/status', (req, res) => {
  res.json({
    active: portalActive,
    devices: connectedDevices,
    uptime: Math.floor((Date.now() - startTime) / 1000),
    ip: getLocalIP(),
    port: PORT
  });
});

app.post('/api/toggle', express.json(), (req, res) => {
  portalActive = !portalActive;
  res.json({ active: portalActive });
});

app.post('/api/clear-devices', (req, res) => {
  connectedDevices.length = 0;
  res.json({ ok: true });
});

// ============================================
// ADMIN PANEL
// ============================================
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// ============================================
// CAPTIVE PORTAL
// ============================================
// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Captive portal detection endpoints
// Apple devices
app.get('/hotspot-detect.html', (req, res) => {
  if (portalActive) return res.redirect('/');
  res.send('Success');
});

// Android devices
app.get('/generate_204', (req, res) => {
  if (portalActive) return res.redirect('/');
  res.status(204).send();
});

app.get('/gen_204', (req, res) => {
  if (portalActive) return res.redirect('/');
  res.status(204).send();
});

// Windows devices
app.get('/ncsi.txt', (req, res) => {
  if (portalActive) return res.redirect('/');
  res.send('Microsoft NCSI');
});

app.get('/connecttest.txt', (req, res) => {
  if (portalActive) return res.redirect('/');
  res.send('Microsoft Connect Test');
});

// Catch all — redirect everything to portal
app.get('/{*splat}', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ============================================
// START
// ============================================
app.listen(PORT, '0.0.0.0', () => {
  const localIP = getLocalIP();
  console.log('');
  console.log('╔═══════════════════════════════════════════╗');
  console.log('║   🔥 WiFi Prank Portal ishga tushdi!      ║');
  console.log('╚═══════════════════════════════════════════╝');
  console.log('');
  console.log(`📡 Portal:  http://${localIP}:${PORT}`);
  console.log(`📱 Admin:   http://${localIP}:${PORT}/admin`);
  console.log('');
  console.log('📋 Telefondan boshqarish:');
  console.log(`   1. Mac va telefoningiz bir WiFi da bo'lsin`);
  console.log(`   2. Telefonda brauzer oching`);
  console.log(`   3. http://${localIP}:${PORT}/admin ga kiring`);
  console.log('');
  console.log('📋 Hotspot qilish:');
  console.log('   1. macOS → System Settings → Internet Sharing');
  console.log('   2. WiFi hotspot yoqing');
  console.log(`   3. sudo bash setup.sh - ishga tushiring`);
  console.log('');
});
