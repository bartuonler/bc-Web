const io = require('socket.io-client');
const fs = require('fs');
const path = require('path');

// ============================================================
// MySQL2 dogrudan baglanti (executeSQL icin - Lua C-boundary bypass)
// ============================================================
let mysql2;
try { mysql2 = require('mysql2/promise'); } catch(e) {
    console.log('[bc-Web] UYARI: mysql2 modulu bulunamadi. npm install calistirin.');
}

let _dbPool = null;
let _dbPoolFailed = false;

function parseConnectionString(str) {
    if (!str) return null;
    str = str.trim();
    if (/^(mysql|mariadb):\/\//i.test(str)) {
        try {
            const url = new URL(str);
            return {
                host: url.hostname || '127.0.0.1',
                port: parseInt(url.port) || 3306,
                user: decodeURIComponent(url.username),
                password: decodeURIComponent(url.password),
                database: url.pathname.replace(/^\/+/, ''),
            };
        } catch(e) {}
    }
    const p = {};
    str.split(';').forEach(part => {
        const eq = part.indexOf('=');
        if (eq > 0) {
            const k = part.slice(0, eq).trim().toLowerCase();
            const v = part.slice(eq + 1).trim();
            p[k] = v;
        }
    });
    if (p.server || p.host) {
        return {
            host: p.server || p.host || '127.0.0.1',
            port: parseInt(p.port) || 3306,
            user: p.uid || p.user || p.username || '',
            password: p.password || p.pass || '',
            database: p.database || p.db || '',
        };
    }
    return null;
}

async function getDbPool() {
    if (_dbPool) return _dbPool;
    if (_dbPoolFailed) throw new Error('MySQL pool daha once basarisiz oldu.');
    if (!mysql2) throw new Error('mysql2 modulu yuklu degil.');
    const connStr = (typeof GetConvar === 'function') ? GetConvar('mysql_connection_string', '') : '';
    if (!connStr) throw new Error('mysql_connection_string convar bos veya bulunamadi.');
    const cfg = parseConnectionString(connStr);
    if (!cfg) throw new Error('Gecersiz connection string: ' + connStr.slice(0, 60));
    if (!cfg.user) throw new Error('DB kullanici adi connection strinde bulunamadi.');
    if (!cfg.database) throw new Error('DB adi connection strinde bulunamadi.');
    try {
        _dbPool = mysql2.createPool({
            host: cfg.host,
            port: cfg.port,
            user: cfg.user,
            password: cfg.password,
            database: cfg.database,
            waitForConnections: true,
            connectionLimit: 5,
            queueLimit: 50,
            connectTimeout: 10000,
            timezone: 'local',
        });
        const conn = await _dbPool.getConnection();
        conn.release();
        console.log('[bc-Web] MySQL dogrudan baglanti hazir: ' + cfg.host + ':' + cfg.port + '/' + cfg.database);
        return _dbPool;
    } catch(err) {
        _dbPool = null;
        _dbPoolFailed = true;
        throw err;
    }
}

// ============================================================
// FS Yardimci Fonksiyonlar (Server CFG + Script Editor)
// ============================================================
function getServerRoot() {
    // socket.js konumu: resources/bc-Web/server/socket.js
    // __dirname fallback: server -> bc-Web -> resources -> sunucu koku
    const dirnameRoot = path.resolve(path.join(__dirname, '..', '..', '..'));
    try {
        const resourcePath = GetResourcePath(GetCurrentResourceName());
        // Yeni FiveM versiyonlarinda GetResourcePath hata atmak yerine hata mesaji string dondurur
        if (!resourcePath ||
            resourcePath.includes('Access to this API') ||
            resourcePath.includes('allow-fs-read') ||
            resourcePath.includes('restricted')) {
            return dirnameRoot;
        }
        return path.resolve(path.join(resourcePath, '..', '..'));
    } catch(e) { return dirnameRoot; }
}

function getServerCfgPath() {
    const root = getServerRoot();
    if (!root) return null;
    return path.join(root, 'server.cfg');
}

function safePath(serverRoot, reqPath) {
    let resolved;
    if (path.isAbsolute(reqPath)) {
        resolved = path.resolve(reqPath);
    } else {
        resolved = path.resolve(path.join(serverRoot, reqPath));
    }
    const normalizedRoot = path.resolve(serverRoot);
    if (!resolved.startsWith(normalizedRoot + path.sep) && resolved !== normalizedRoot) {
        throw new Error('Guvenlik ihlali: sunucu dizini disina erisim yasak.');
    }
    return resolved;
}

// ============================================================
// Ana Socket.io baglantisi
// ============================================================
setTimeout(async () => {
    let SITE_URL = '';
    let API_KEY  = '';

    try {
        const resourceName = GetCurrentResourceName();
        if (global.exports[resourceName] && global.exports[resourceName].getPanelConfig) {
            const config = global.exports[resourceName].getPanelConfig();
            if (config && config.siteUrl) SITE_URL = config.siteUrl;
            if (config && config.apiKey)  API_KEY  = config.apiKey;
            console.log('[bc-Web] Config okundu: URL=' + SITE_URL);
        } else {
            console.log('[bc-Web] UYARI: getPanelConfig export bulunamadi.');
        }
    } catch (err) {
        console.log('[bc-Web] Config okuma hatasi:', err.message);
    }

    if (!SITE_URL) {
        try {
            const _resPath = GetResourcePath(GetCurrentResourceName());
        const _resolvedResPath = (_resPath && !_resPath.includes('restricted') && !_resPath.includes('allow-fs-read'))
            ? _resPath
            : path.resolve(path.join(__dirname, '..'));
        const settingsFile = path.join(_resolvedResPath, 'settings.json');
            if (fs.existsSync(settingsFile)) {
                const s = JSON.parse(fs.readFileSync(settingsFile, 'utf-8'));
                if (s.siteUrl) SITE_URL = s.siteUrl;
                if (s.apiKey)  API_KEY  = s.apiKey;
                console.log('[bc-Web] settings.json fallback: URL=' + SITE_URL);
            }
        } catch(e) {}
    }

    if (!SITE_URL) {
        console.log('[bc-Web] HATA: Site URL tanimlanamadi. config.lua icindeki BCPanel.webPanel degerini kontrol edin!');
        return;
    }

    if (!API_KEY || API_KEY.trim() === '') {
        console.log('[bc-Web] UYARI: API Key bos! config.lua icindeki BCPanel.WebAPIKey degerini kontrol edin.');
    }

    try { await getDbPool(); } catch(err) {
        console.log('[bc-Web] MySQL pool on-baslatma basarisiz (executeSQL calisirken tekrar denenecek): ' + err.message);
    }

    console.log('[bc-Web] SaaS Paneline baglaniliyor: ' + SITE_URL);

    const socket = io(SITE_URL, {
        path: '/ws',
        auth: { role: 'fivem-resource', apiKey: API_KEY },
        transports: ['polling', 'websocket'],
        timeout: 20000,
        reconnection: true,
        reconnectionDelay: 5000,
        reconnectionAttempts: 999,
    });

    socket.on('connect', () => { console.log('[bc-Web] SaaS Merkezine Basariyla Baglandi!'); });
    socket.on('connect_error', (err) => { console.log('[bc-Web] SaaS Baglanti Hatasi: ' + err.message); });
    socket.on('disconnect', (reason) => { console.log('[bc-Web] SaaS Merkezi ile Baglanti Koptu. Neden: ' + reason); });

    on('BC-Web:server:consoleLog', (channel, message) => {
        if (socket.connected) {
            socket.emit('consoleLine', { channel, message, timestamp: Date.now() });
        }
    });

    socket.on('executeCommand', async (data, callback) => {
        const { command, payload } = data;

        // ---- executeSQL: Node.js mysql2 ile dogrudan calistir ----
        if (command === 'executeSQL') {
            try {
                const pool = await getDbPool();
                const query  = payload && payload.query  ? payload.query  : null;
                const params = payload && payload.params ? payload.params : [];
                if (!query) { if (callback) callback({ success: false, message: 'SQL sorgusu bos.' }); return; }
                const [rows] = await pool.execute(query, params);
                if (callback) callback({ success: true, data: rows });
            } catch(err) {
                console.log('[bc-Web] executeSQL hatasi: ' + err.message);
                if (callback) callback({ success: false, message: 'SQL Hatasi: ' + err.message });
            }
            return;
        }

        // ---- Server CFG: Oku ----
        if (command === 'fs_readServerCfg') {
            try {
                const cfgPath = getServerCfgPath();
                if (!cfgPath) { if (callback) callback({ success: false, message: 'server.cfg yolu bulunamadi.' }); return; }
                if (!fs.existsSync(cfgPath)) { if (callback) callback({ success: false, message: 'server.cfg bulunamadi: ' + cfgPath }); return; }
                const content = fs.readFileSync(cfgPath, 'utf-8');
                if (callback) callback({ success: true, content, path: cfgPath });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Server CFG: Yaz ----
        if (command === 'fs_writeServerCfg') {
            try {
                const cfgPath = getServerCfgPath();
                if (!cfgPath) { if (callback) callback({ success: false, message: 'server.cfg yolu bulunamadi.' }); return; }
                const content = payload && payload.content !== undefined ? payload.content : '';
                if (fs.existsSync(cfgPath)) fs.copyFileSync(cfgPath, cfgPath + '.bak');
                fs.writeFileSync(cfgPath, content, 'utf-8');
                if (callback) callback({ success: true, message: 'server.cfg kaydedildi. (Yedek: server.cfg.bak)' });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Dizin Listele ----
        if (command === 'fs_listDir') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const reqPath = (payload && payload.path) ? payload.path : '/';
                const absPath = reqPath === '/' ? serverRoot : safePath(serverRoot, reqPath);
                if (!fs.existsSync(absPath)) { if (callback) callback({ success: false, message: 'Dizin bulunamadi.' }); return; }
                const stat = fs.statSync(absPath);
                if (!stat.isDirectory()) { if (callback) callback({ success: false, message: 'Belirtilen yol bir dizin degil.' }); return; }
                const entries = fs.readdirSync(absPath, { withFileTypes: true });
                const items = entries.map(e => {
                    const fullPath = path.join(absPath, e.name);
                    const relPath = ('/' + path.relative(serverRoot, fullPath).replace(/\\/g, '/')).replace('//', '/');
                    let size = 0;
                    try { if (!e.isDirectory()) size = fs.statSync(fullPath).size; } catch(ex) {}
                    return { name: e.name, isDir: e.isDirectory(), path: relPath, size };
                }).sort((a, b) => (b.isDir ? 1 : 0) - (a.isDir ? 1 : 0) || a.name.localeCompare(b.name));
                const currentPath = ('/' + path.relative(serverRoot, absPath).replace(/\\/g, '/')).replace('//', '/') || '/';
                if (callback) callback({ success: true, items, currentPath, serverRoot });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Dosya Oku ----
        if (command === 'fs_readFile') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const reqPath = payload && payload.path ? payload.path : '';
                if (!reqPath) { if (callback) callback({ success: false, message: 'Dosya yolu belirtilmedi.' }); return; }
                const absPath = safePath(serverRoot, reqPath);
                if (!fs.existsSync(absPath)) { if (callback) callback({ success: false, message: 'Dosya bulunamadi.' }); return; }
                const stat = fs.statSync(absPath);
                if (stat.isDirectory()) { if (callback) callback({ success: false, message: 'Belirtilen yol bir dosya degil.' }); return; }
                if (stat.size > 512 * 1024) { if (callback) callback({ success: false, message: 'Dosya cok buyuk (max 512KB).' }); return; }
                const content = fs.readFileSync(absPath, 'utf-8');
                if (callback) callback({ success: true, content, path: reqPath, size: stat.size });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Dosya Yaz ----
        if (command === 'fs_writeFile') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const reqPath = payload && payload.path ? payload.path : '';
                const content = payload && payload.content !== undefined ? payload.content : '';
                if (!reqPath) { if (callback) callback({ success: false, message: 'Dosya yolu belirtilmedi.' }); return; }
                const absPath = safePath(serverRoot, reqPath);
                if (fs.existsSync(absPath)) fs.copyFileSync(absPath, absPath + '.bak');
                fs.writeFileSync(absPath, content, 'utf-8');
                if (callback) callback({ success: true, message: 'Dosya kaydedildi.' });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Dosya/Dizin Kopyala ----
        if (command === 'fs_copyFile') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const srcPath = payload && payload.src ? payload.src : '';
                const dstPath = payload && payload.dst ? payload.dst : '';
                if (!srcPath || !dstPath) { if (callback) callback({ success: false, message: 'Kaynak (src) ve hedef (dst) yol gerekli.' }); return; }
                const absSrc = safePath(serverRoot, srcPath);
                const absDst = safePath(serverRoot, dstPath);
                if (!fs.existsSync(absSrc)) { if (callback) callback({ success: false, message: 'Kaynak dosya bulunamadi.' }); return; }
                fs.mkdirSync(path.dirname(absDst), { recursive: true });
                fs.copyFileSync(absSrc, absDst);
                if (callback) callback({ success: true, message: 'Dosya kopyalandi: ' + dstPath });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Sil ----
        if (command === 'fs_deleteFile') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const reqPath = payload && payload.path ? payload.path : '';
                if (!reqPath) { if (callback) callback({ success: false, message: 'Dosya yolu belirtilmedi.' }); return; }
                const absPath = safePath(serverRoot, reqPath);
                if (!fs.existsSync(absPath)) { if (callback) callback({ success: false, message: 'Dosya/dizin bulunamadi.' }); return; }
                const stat = fs.statSync(absPath);
                if (stat.isDirectory()) {
                    fs.rmSync(absPath, { recursive: true, force: true });
                } else {
                    fs.unlinkSync(absPath);
                }
                if (callback) callback({ success: true, message: 'Silindi.' });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Dizin Olustur ----
        if (command === 'fs_createDir') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const reqPath = payload && payload.path ? payload.path : '';
                if (!reqPath) { if (callback) callback({ success: false, message: 'Dizin yolu belirtilmedi.' }); return; }
                const absPath = safePath(serverRoot, reqPath);
                fs.mkdirSync(absPath, { recursive: true });
                if (callback) callback({ success: true, message: 'Dizin olusturuldu.' });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Script Editor: Yeniden Adlandir / Tasi ----
        if (command === 'fs_renameFile') {
            try {
                const serverRoot = getServerRoot();
                if (!serverRoot) { if (callback) callback({ success: false, message: 'Sunucu kok dizini bulunamadi.' }); return; }
                const srcPath = payload && payload.src ? payload.src : '';
                const dstPath = payload && payload.dst ? payload.dst : '';
                if (!srcPath || !dstPath) { if (callback) callback({ success: false, message: 'Kaynak (src) ve hedef (dst) yol gerekli.' }); return; }
                const absSrc = safePath(serverRoot, srcPath);
                const absDst = safePath(serverRoot, dstPath);
                if (!fs.existsSync(absSrc)) { if (callback) callback({ success: false, message: 'Kaynak bulunamadi.' }); return; }
                fs.mkdirSync(path.dirname(absDst), { recursive: true });
                fs.renameSync(absSrc, absDst);
                if (callback) callback({ success: true, message: 'Yeniden adlandirildi.' });
            } catch(e) { if (callback) callback({ success: false, message: e.message }); }
            return;
        }

        // ---- Diger komutlar Lua'ya ilet ----
        try {
            const resourceName = GetCurrentResourceName();
            if (global.exports[resourceName] && global.exports[resourceName].handlePanelCommand) {
                const luaResult = global.exports[resourceName].handlePanelCommand(command, payload);
                if (callback) callback(luaResult);
            } else {
                console.log('[bc-Web] HATA: handlePanelCommand export bulunamadi.');
                if (callback) callback({ success: false, message: 'Lua export bulunamadi.' });
            }
        } catch (err) {
            console.error('[bc-Web] Komut hatasi:', err);
            if (callback) callback({ success: false, message: 'JS hatasi: ' + err.message });
        }
    });

}, 3000);
