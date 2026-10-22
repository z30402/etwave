// api/giftconfig.js
// 代理 WAVE 的 /api/v1/config，只回傳 gifts 區塊（禮物動畫設定，每週會換）

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  // 動畫設定變動不頻繁，CDN 快取 10 分鐘，減少打 WAVE 次數
  res.setHeader('Cache-Control', 's-maxage=600, stale-while-revalidate=1800');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const response = await fetch('https://api.wave.com.tw/api/v1/config', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    });
    if (!response.ok) throw new Error(`WAVE API error: ${response.status}`);
    const data = await response.json();
    // 只回禮物區塊，省流量（完整 config 約 530KB）
    res.status(200).json({ gifts: data.gifts });
  } catch (error) {
    console.error('Proxy error:', error);
    res.status(500).json({ error: error.message });
  }
}
