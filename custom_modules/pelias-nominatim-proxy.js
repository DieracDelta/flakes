#!/usr/bin/env node
// Simple Pelias-to-Nominatim proxy for Digitransit geocoding
// Translates Pelias API format to Nominatim and back

const http = require('http');
const https = require('https');
const url = require('url');

const PORT = process.env.PORT || 3200;
const NOMINATIM_URL = process.env.NOMINATIM_URL || 'https://nominatim.openstreetmap.org';

// Helper to make requests to either http or https
function makeRequest(requestUrl, onResponse, onError) {
  const protocol = requestUrl.startsWith('https') ? https : http;
  protocol.get(requestUrl, {
    headers: { 'User-Agent': 'Digitransit-LocalProxy/1.0' }
  }, onResponse).on('error', onError);
}

function nominatimToFeature(item) {
  return {
    type: 'Feature',
    geometry: {
      type: 'Point',
      coordinates: [parseFloat(item.lon), parseFloat(item.lat)]
    },
    properties: {
      id: item.place_id?.toString() || item.osm_id?.toString(),
      gid: `osm:${item.osm_type}:${item.osm_id}`,
      layer: item.type || 'address',
      source: 'openstreetmap',
      source_id: item.osm_id?.toString(),
      name: item.display_name?.split(',')[0] || item.name,
      housenumber: item.address?.house_number,
      street: item.address?.road,
      postalcode: item.address?.postcode,
      confidence: item.importance || 0.5,
      country: item.address?.country,
      country_a: item.address?.country_code?.toUpperCase(),
      region: item.address?.state,
      county: item.address?.county,
      locality: item.address?.city || item.address?.town || item.address?.village,
      neighbourhood: item.address?.suburb || item.address?.neighbourhood,
      label: item.display_name
    }
  };
}

function handleSearch(req, res) {
  const parsed = url.parse(req.url, true);
  const query = parsed.query;

  // Build Nominatim URL
  const nominatimParams = new URLSearchParams({
    q: query.text || '',
    format: 'json',
    addressdetails: '1',
    limit: query.size || '10',
  });

  // Add bounding box if provided
  if (query['boundary.rect.min_lat']) {
    nominatimParams.set('viewbox',
      `${query['boundary.rect.min_lon']},${query['boundary.rect.min_lat']},${query['boundary.rect.max_lon']},${query['boundary.rect.max_lat']}`
    );
    nominatimParams.set('bounded', '1');
  }

  const nominatimUrl = `${NOMINATIM_URL}/search?${nominatimParams}`;

  makeRequest(nominatimUrl, (nominatimRes) => {
    let data = '';
    nominatimRes.on('data', chunk => data += chunk);
    nominatimRes.on('end', () => {
      try {
        const results = JSON.parse(data);
        const peliasResponse = {
          geocoding: {
            version: '0.2',
            attribution: 'https://nominatim.openstreetmap.org',
            query: { text: query.text },
            engine: { name: 'Nominatim', author: 'OpenStreetMap', version: '1.0' }
          },
          type: 'FeatureCollection',
          features: results.map(nominatimToFeature)
        };

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': '*'
        });
        res.end(JSON.stringify(peliasResponse));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
  }, (e) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  });
}

function handleReverse(req, res) {
  const parsed = url.parse(req.url, true);
  const query = parsed.query;

  const nominatimParams = new URLSearchParams({
    lat: query['point.lat'],
    lon: query['point.lon'],
    format: 'json',
    addressdetails: '1',
  });

  const nominatimUrl = `${NOMINATIM_URL}/reverse?${nominatimParams}`;

  makeRequest(nominatimUrl, (nominatimRes) => {
    let data = '';
    nominatimRes.on('data', chunk => data += chunk);
    nominatimRes.on('end', () => {
      try {
        const result = JSON.parse(data);
        const peliasResponse = {
          geocoding: {
            version: '0.2',
            attribution: 'https://nominatim.openstreetmap.org'
          },
          type: 'FeatureCollection',
          features: result.error ? [] : [nominatimToFeature(result)]
        };

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': '*'
        });
        res.end(JSON.stringify(peliasResponse));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
  }, (e) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  });
}

function handlePlace(req, res) {
  const parsed = url.parse(req.url, true);
  const query = parsed.query;

  // Convert Pelias IDs (osm:way:123) to Nominatim format (W123)
  const ids = (query.ids || '').split(',').map(id => {
    const match = id.match(/osm:(\w+):(\d+)/);
    if (match) {
      const typeMap = { node: 'N', way: 'W', relation: 'R' };
      return (typeMap[match[1]] || 'N') + match[2];
    }
    return null;
  }).filter(Boolean).join(',');

  if (!ids) {
    res.writeHead(400, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({ error: 'No valid IDs provided' }));
    return;
  }

  const nominatimParams = new URLSearchParams({
    osm_ids: ids,
    format: 'json',
    addressdetails: '1',
  });

  const nominatimUrl = `${NOMINATIM_URL}/lookup?${nominatimParams}`;

  makeRequest(nominatimUrl, (nominatimRes) => {
    let data = '';
    nominatimRes.on('data', chunk => data += chunk);
    nominatimRes.on('end', () => {
      try {
        const results = JSON.parse(data);
        const peliasResponse = {
          geocoding: {
            version: '0.2',
            attribution: 'https://nominatim.openstreetmap.org',
            query: { ids: query.ids }
          },
          type: 'FeatureCollection',
          features: Array.isArray(results) ? results.map(nominatimToFeature) : []
        };

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': '*'
        });
        res.end(JSON.stringify(peliasResponse));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
  }, (e) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  });
}

const server = http.createServer((req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': '*'
    });
    res.end();
    return;
  }

  const pathname = url.parse(req.url).pathname;

  if (pathname === '/search' || pathname === '/v1/search') {
    handleSearch(req, res);
  } else if (pathname === '/reverse' || pathname === '/v1/reverse') {
    handleReverse(req, res);
  } else if (pathname === '/place' || pathname === '/v1/place') {
    handlePlace(req, res);
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(PORT, () => {
  console.log(`Pelias-Nominatim proxy running on port ${PORT}`);
});
