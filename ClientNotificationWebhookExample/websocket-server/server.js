'use strict';

require('dotenv').config();

const ngrok = require('@ngrok/ngrok');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const http = require('http');
const https = require('https');
const { twiml: { VoiceResponse } } = require('twilio');

const PORT = process.env.PORT || 3000;
const NGROK_AUTHTOKEN = process.env.NGROK_AUTHTOKEN;
const TWILIO_ACCOUNT_SID = process.env.TEST_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TEST_ACCOUNT_AUTH_TOKEN;
const TWILIO_PHONE_NUMBER_SID = process.env.TEST_ACCOUNT_PHONENUMBER_SID;

const app = express();
app.use(express.json());

const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

let publicBaseUrl = null;
let stirVerificationClientIdentity = null;

// Tracks active WebSocket connections keyed by connection ID.
const connections = new Map();

// Handle WebSocket upgrade requests on /ws/:id
server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const match = url.pathname.match(/^\/ws\/bob[0-9a-fA-F]{32}$/);
  if (!match) {
    console.warn(`[upgrade] rejected: invalid path "${url.pathname}". Expected /ws/<connectionId>`);
    socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
    socket.destroy();
    return;
  }

  const connectionIdMatch = match[0].match(/bob[0-9a-fA-F]{32}$/);
  if (!connectionIdMatch) {
    console.warn(`[upgrade] rejected: invalid connectionId "${match[0]}".`);
    socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
    socket.destroy();
    return;
  }
  
  const connectionId = connectionIdMatch[0]
  const keys = [...connections.keys()];
  if (!connections.has(connectionId)) {
    console.warn(`[upgrade] rejected: unknown connectionId ${connectionId}`);
    socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
    socket.destroy();
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    const entry = connections.get(connectionId);
    entry.ws = ws;

    ws.on('message', (data) => {
      console.log(`[connection ${connectionId}] received message:`, data.toString());
    });

    ws.on('close', () => {
      console.log(`[connection ${connectionId}] WebSocket closed`);
      connections.delete(connectionId);
    });

    ws.on('error', (err) => {
      console.error(`[connection ${connectionId}] WebSocket error:`, err.message);
    });

    console.log(`[connection ${connectionId}] WebSocket client connected`);
    wss.emit('connection', ws, request);
  });
});

/**
 * POST /connect
 * Sets up a new WebSocket connection slot.
 * Returns a connection ID and the WebSocket URL the client should connect to.
 *
 * Response: { "connectionId": <number>, "url": "ws://host:port/ws/<connectionId>" }
 */
app.post('/connect', (req, res) => {
  const { connectionId } = req.body;

  if (connectionId === undefined) {
    return res.status(400).json({ error: 'connectionId is required' });
  }

  connections.set(connectionId, { ws: null, id: connectionId });
  const keys = [...connections.keys()];

  const host = req.headers.host || `localhost:${PORT}`;
  // Return the localhost URL for the tests to connect to the websocket
  const wsUrl = `ws://localhost:${PORT}/ws/${connectionId}`;

  console.log(`[connection ${connectionId}] slot created, WebSocket URL: ${wsUrl}`);

  res.status(201).json({ connectionId, url: wsUrl });
});

/**
 * POST /disconnect
 * Tears down an existing WebSocket connection.
 *
 * Body: { "connectionId": <number> }
 */
app.post('/disconnect', (req, res) => {
  const { connectionId } = req.body;

  if (connectionId === undefined) {
    return res.status(400).json({ error: 'connectionId is required' });
  }

  const entry = connections.get(connectionId);
  if (!entry) {
    return res.status(404).json({ error: `Connection ${connectionId} not found` });
  }

  if (entry.ws && entry.ws.readyState === WebSocket.OPEN) {
    entry.ws.close();
  }

  connections.delete(connectionId);
  console.log(`[connection ${connectionId}] torn down`);

  res.status(200).json({ message: `Connection ${connectionId} disconnected` });
});

/**
 * POST /message
 * Receives an HTTP POST payload and forwards it to the specified WebSocket connection.
 *
 * Body: { "connectionId": <number>, "payload": <any> }
 */
app.post('/message', (req, res) => {
  const { connectionId, payload } = req.body;

  if (connectionId === undefined) {
    return res.status(400).json({ error: 'connectionId is required' });
  }

  if (payload === undefined) {
    return res.status(400).json({ error: 'payload is required' });
  }

  const entry = connections.get(connectionId);
  if (!entry) {
    return res.status(404).json({ error: `Connection ${connectionId} not found` });
  }

  if (!entry.ws || entry.ws.readyState !== WebSocket.OPEN) {
    return res.status(409).json({ error: `WebSocket for connection ${connectionId} is not open` });
  }

  const message = typeof payload === 'string' ? payload : JSON.stringify(payload);
  entry.ws.send(message);

  console.log(`[connection ${connectionId}] sent message:`, message);

  res.status(200).json({ message: 'Payload sent to WebSocket connection' });
});

/**
 * POST /callNotificationWebhook
 * 
 * Receives an HTTP POST from Twilio Programmable Voice with a payload of information
 * for the call recipient to accept and connect with the caller.
 * 
 * Body:
 * {
 *   "twi_account_sid": ACxxxx,
 *   "twi_bridge_token": "eyJraxxxx",
 *   "twi_call_sid": CAxxxx,
 *   "twi_from": "client:alice",
 *   "twi_message_id": WBxxxx,
 *   "twi_message_type": "twilio.voice.call",
 *   "twi_to": "client:bob"
 * }
 */
app.post('/callNotificationWebhook', (req, res) => {
  const payload = JSON.stringify(req.body, null, 2);
  const { twi_account_sid, twi_bridge_token, twi_call_sid, twi_from, twi_to, twi_message_id, twi_message_type } = JSON.parse(payload);

  if (twi_account_sid === undefined) {
    return res.status(400).json({ error: 'twi_account_sid missing' });
  }

  if (twi_to === undefined) {
    return res.status(400).json({ error: 'twi_to missing' });
  }

  const connectionId = twi_to.split("client:")[1];
  console.log(`connectionId: ${connectionId}`);
  const entry = connections.get(connectionId);
  if (!entry) {
    return res.status(404).json({ error: `Connection ${connectionId} not found` });
  }

  if (!entry.ws || entry.ws.readyState !== WebSocket.OPEN) {
    return res.status(409).json({ error: `WebSocket for connection ${connectionId} is not open` });
  }

  const message = typeof payload === 'string' ? payload : JSON.stringify(payload);
  console.log('Sending message');
  entry.ws.send(message);

  console.log(`[connection ${connectionId}] sent message:`, message);

  res.status(200).json({ message: 'Payload sent to WebSocket connection' });
});

app.get('/publicUrl', (req, res) => {
  res.status(200).json({ publicUrl: `${publicBaseUrl}`});
});

/**
 * POST /updateStirNumberVoiceUrl
 * Updates the VoiceUrl of the Twilio Incoming Phone Number to the public ngrok URL
 * of this server's /stirVerificationTwiml endpoint.
 */
app.post('/updateStirNumberVoiceUrl', (req, res) => {
  if (!publicBaseUrl) {
    return res.status(400).json({ error: 'ngrok tunnel not established — publicBaseUrl unavailable' });
  }

  const { connectionId } = req.body;
  if (connectionId === undefined) {
    return res.status(400).json({ error: 'connectionId is required' });
  }
  const entry = connections.get(connectionId);
  if (!entry) {
    return res.status(400).json({ error: `Connection ${connectionId} not found` });
  }

  stirVerificationClientIdentity = connectionId;

  const voiceUrl = `${publicBaseUrl}/stirVerificationTwiml`;
  const body = `VoiceUrl=${encodeURIComponent(voiceUrl)}`;

  const options = {
    hostname: 'api.twilio.com',
    path: `/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/IncomingPhoneNumbers/${TWILIO_PHONE_NUMBER_SID}.json`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
      'Authorization': `Basic ${Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64')}`,
    },
  };

  const twilioReq = https.request(options, (twilioRes) => {
    let data = '';
    twilioRes.on('data', (chunk) => { data += chunk; });
    twilioRes.on('end', () => {
      const parsed = JSON.parse(data);
      if (twilioRes.statusCode >= 200 && twilioRes.statusCode < 300) {
        console.log(`[updateStirNumberVoiceUrl] VoiceUrl updated to ${voiceUrl}`);
        res.status(200).json({ voiceUrl: parsed.voice_url });
      } else {
        console.error(`[updateStirNumberVoiceUrl] Twilio error ${twilioRes.statusCode}:`, data);
        res.status(twilioRes.statusCode).json({ error: parsed.message || 'Twilio request failed' });
      }
    });
  });

  twilioReq.on('error', (err) => {
    console.error('[updateStirNumberVoiceUrl] request error:', err.message);
    res.status(500).json({ error: err.message });
  });

  twilioReq.write(body);
  twilioReq.end();
});

/**
 * POST /stirVerificationTwiml
 * Returns TwiML that dials a Twilio Client identity.
 * The <Client> verb includes a notification URL pointing to /callNotificationWebhook
 * so Twilio can push call info to the recipient before they answer.
 */
app.post('/stirVerificationTwiml', (req, res) => {
  if (!publicBaseUrl) {
    return res.status(400).json({ error: 'ngrok tunnel not established — publicBaseUrl unavailable' });
  }
  if (!stirVerificationClientIdentity) {
    return res.status(400).json({ error: 'Callee identity not available' });
  }

  const response = new VoiceResponse();
  const dial = response.dial();
  const client = dial.client({
    clientNotificationUrl: `${publicBaseUrl}/callNotificationWebhook`,
  });
  client.identity(stirVerificationClientIdentity);

  res.type('text/xml');
  res.send(response.toString());
});

/**
 * Starts the HTTP server and establishes an ngrok tunnel.
 */
async function start() {
  server.listen(PORT, async () => {
    console.log(`WebSocket server listening on port ${PORT}`);

    if (!NGROK_AUTHTOKEN) {
      console.warn('[ngrok] NGROK_AUTHTOKEN not set — skipping tunnel. Server is local-only.');
      return;
    }

    try {
      const listener = await ngrok.forward({
        addr: PORT,
        authtoken: NGROK_AUTHTOKEN,
      });
      publicBaseUrl = listener.url(); // e.g. "https://xxxx.ngrok-free.app"
      console.log(`[ngrok] tunnel established: ${publicBaseUrl}`);
    } catch (err) {
      console.error('[ngrok] failed to establish tunnel:', err.message);
    }
  });
}

start();

module.exports = { app, server, connections };
