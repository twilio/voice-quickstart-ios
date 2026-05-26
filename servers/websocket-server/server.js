'use strict';

require('dotenv').config();

const ngrok = require('@ngrok/ngrok');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const http = require('http');
const https = require('https');
const { twiml: { VoiceResponse } } = require('twilio');
const { Twilio, validateRequest } = require('twilio');

const PORT = process.env.PORT || 3000;
const NGROK_AUTHTOKEN = process.env.NGROK_AUTHTOKEN;
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;

const app = express();
app.use(express.json());

const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

let publicBaseUrl = null;

// Tracks active WebSocket connections keyed by connection ID.
const connections = new Map();

// Handle WebSocket upgrade requests on /ws/:id
server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const match = url.pathname.match(/^\/ws\/*/);
  if (!match) {
    console.warn(`[upgrade] rejected: invalid path "${url.pathname}". Expected /ws/<connectionId>`);
    socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
    socket.destroy();
    return;
  }

  const connectionIdMatch = url.pathname.match(/(?<=^\/ws\/).+$/);
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
  const wsUrl = `wss://${publicBaseUrl.replace(/^https?:\/\//, '')}/ws/${connectionId}`;

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
 * POST /triggerIncomingCall
 * Uses the Twilio Calls API to create a call whose TwiML <Dial><Client> verb
 * delivers an incoming call invite to the specified connection's identity.
 *
 * Body: { "connectionId": <string>, "to": <e.164>, "from": <e.164> }
 */
app.post('/triggerIncomingCall', (req, res) => {
  if (!publicBaseUrl) {
    return res.status(400).json({ error: 'ngrok tunnel not established — publicBaseUrl unavailable' });
  }

  const { connectionId, to, from } = req.body;
  if (connectionId === undefined) {
    return res.status(400).json({ error: 'connectionId is required' });
  }
  if (to === undefined) {
    return res.status(400).json({ error: 'to is required' });
  }
  if (from === undefined) {
    return res.status(400).json({ error: 'from is required' });
  }

  const entry = connections.get(connectionId);
  if (!entry) {
    return res.status(400).json({ error: `Connection ${connectionId} not found` });
  }

  const body = new URLSearchParams({
    To: to,
    From: from,
    ClientNotificationUrl: `${publicBaseUrl}/callNotificationWebhook`,
    Url: "http://demo.twilio.com/docs/voice.xml"
  }).toString();

  const options = {
    hostname: 'api.twilio.com',
    path: `/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Calls.json`,
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
        console.log(`[triggerIncomingCall] call created: ${parsed.sid}`);
        res.status(200).json({ callSid: parsed.sid });
      } else {
        console.error(`[triggerIncomingCall] Twilio error ${twilioRes.statusCode}:`, data);
        res.status(twilioRes.statusCode).json({ error: parsed.message || 'Twilio request failed' });
      }
    });
  });

  twilioReq.on('error', (err) => {
    console.error('[triggerIncomingCall] request error:', err.message);
    res.status(500).json({ error: err.message });
  });

  twilioReq.write(body);
  twilioReq.end();
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
  // Verify Twilio request signature
  const headers = req.headers;
  try {
    if (!headers['x-twilio-signature']) {
      throw new Error("Missing Twilio signature");
    }
    if (!TWILIO_AUTH_TOKEN) {
      throw new Error("Missing TWILIO_AUTH_TOKEN in environment variables");
    }
    if (!validateRequest( TWILIO_AUTH_TOKEN,
                          headers['x-twilio-signature'],
                          publicBaseUrl,
                          {})) {
       throw new Error("Invalid Twilio signature");
    }
  } catch (error) {
    console.log("Twilio request validation failed: " + error.message);
    return;
  }

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
