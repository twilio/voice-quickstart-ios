import os
from flask import Flask, request
from twilio.jwt.access_token import AccessToken
from twilio.jwt.access_token.grants import VoiceGrant
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse

ACCOUNT_SID = 'AC74106c2961d347363690a64d07b837d0'
API_KEY = 'SK12bdc6cea016ebfa225f6cb2151ee71f'
API_KEY_SECRET = '2a5NA8YCZRz7kMUw0fk8nt6hNAZKpmU0'
PUSH_CREDENTIAL_SID = 'CR***'
APP_SID = 'AP88056829d5656363e30182069a867da2'

"""
Use a valid Twilio number by adding to your account via https://www.twilio.com/console/phone-numbers/verified
"""
CALLER_NUMBER = '1234567890'

"""
The caller id used when a client is dialed.
"""
CALLER_ID = 'client:quick_start'
IDENTITY = 'alice'


app = Flask(__name__)

"""
Creates an access token with VoiceGrant using your Twilio credentials.
"""
@app.route('/accessToken', methods=['GET', 'POST'])
def token():
  account_sid = os.environ.get("ACCOUNT_SID", ACCOUNT_SID)
  api_key = os.environ.get("API_KEY", API_KEY)
  api_key_secret = os.environ.get("API_KEY_SECRET", API_KEY_SECRET)
  push_credential_sid = os.environ.get("PUSH_CREDENTIAL_SID", PUSH_CREDENTIAL_SID)
  app_sid = os.environ.get("APP_SID", APP_SID)

  grant = VoiceGrant(
    push_credential_sid=push_credential_sid,
    outgoing_application_sid=app_sid
  )

  identity = request.values["identity"] \
          if request.values and request.values["identity"] else IDENTITY
  token = AccessToken(account_sid, api_key, api_key_secret, identity=identity)
  token.add_grant(grant)

  return token.to_jwt()

"""
Creates an endpoint that plays back a greeting.
"""
@app.route('/incoming', methods=['GET', 'POST'])
def incoming():
  resp = VoiceResponse()
  resp.say("Congratulations! You have received your first inbound call! Good bye.")
  return str(resp)

"""
Makes a call to the specified client using the Twilio REST API.
"""
@app.route('/placeCall', methods=['GET', 'POST'])
def placeCall():
  account_sid = os.environ.get("ACCOUNT_SID", ACCOUNT_SID)
  api_key = os.environ.get("API_KEY", API_KEY)
  api_key_secret = os.environ.get("API_KEY_SECRET", API_KEY_SECRET)

  client = Client(api_key, api_key_secret, account_sid)
  to = request.values.get("to")
  call = None

  if to is None or len(to) == 0:
    call = client.calls.create(url=request.url_root + 'incoming', to='client:' + IDENTITY, from_=CALLER_ID)
  elif to[0] in "+1234567890" and (len(to) == 1 or to[1:].isdigit()):
    call = client.calls.create(url=request.url_root + 'incoming', to=to, from_=CALLER_NUMBER)
  else:
    call = client.calls.create(url=request.url_root + 'incoming', to='client:' + to, from_=CALLER_ID)
  return str(call)

"""
Creates an endpoint that can be used in your TwiML App as the Voice Request Url.

In order to make an outgoing call using Twilio Voice SDK, you need to provide a
TwiML App SID in the Access Token. You can run your server, make it publicly
accessible and use `/makeCall` endpoint as the Voice Request Url in your TwiML App.
"""
@app.route('/makeCall', methods=['GET', 'POST'])
def makeCall():
  resp = VoiceResponse()
  to = request.values.get("to")

  if to is None or len(to) == 0:
    resp.say("Congratulations! You have just made your first call! Good bye.")
  elif to[0] in "+1234567890" and (len(to) == 1 or to[1:].isdigit()):
    resp.dial(callerId=CALLER_NUMBER).number(to)
  else:
    resp.dial(callerId=CALLER_ID).client(to)
  return str(resp)

@app.route('/', methods=['GET', 'POST'])
def welcome():
  resp = VoiceResponse()
  resp.say("Welcome to Twilio")
  return str(resp)

if __name__ == "__main__":
  port = int(os.environ.get("PORT", 5000))
  app.run(host='0.0.0.0', port=port, debug=True)
