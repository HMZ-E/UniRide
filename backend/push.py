"""Optional APNs transport using macOS/Linux curl (HTTP/2) and openssl.
Keys stay outside the repository. No third-party Python packages are required.
"""
import base64, json, os, subprocess, time

def b64(data): return base64.urlsafe_b64encode(data).rstrip(b'=').decode()
def configured(): return all(os.getenv(key) for key in ('UNIRIDE_APNS_KEY_FILE','UNIRIDE_APNS_KEY_ID','UNIRIDE_APNS_TEAM_ID'))

def jwt():
    header=b64(json.dumps(dict(alg='ES256',kid=os.environ['UNIRIDE_APNS_KEY_ID']),separators=(',',':')).encode())
    payload=b64(json.dumps(dict(iss=os.environ['UNIRIDE_APNS_TEAM_ID'],iat=int(time.time())),separators=(',',':')).encode())
    content=(header+'.'+payload).encode()
    signed=subprocess.run(['openssl','dgst','-sha256','-sign',os.environ['UNIRIDE_APNS_KEY_FILE']],input=content,capture_output=True,check=True,timeout=5).stdout
    # Convert the DER ECDSA pair to the JWT ES256 fixed-width signature.
    if signed[0]!=0x30 or signed[2]!=0x02: raise ValueError('Invalid ECDSA signature')
    size=signed[3]; r=signed[4:4+size]; offset=4+size
    if signed[offset]!=0x02: raise ValueError('Invalid ECDSA signature')
    size=signed[offset+1]; s=signed[offset+2:offset+2+size]
    signature=r.lstrip(b'\x00').rjust(32,b'\x00')+s.lstrip(b'\x00').rjust(32,b'\x00')
    if len(signature)!=64: raise ValueError('Use an ES256 APNs signing key')
    return content.decode()+'.'+b64(signature)

TITLES=dict(request='New seat request',confirmed='Your seat is confirmed',declined='Seat request declined',changed='Departure updated',cancelled='Ride cancelled',passengerCancelled='Ride cancelled',started='Your ride has started',completed='Trip completed',message='New message')
def send(device,note):
    if not all(c in '0123456789abcdefABCDEF' for c in device) or len(device)>256: return 400
    host='api.sandbox.push.apple.com' if os.getenv('UNIRIDE_APNS_ENV','development')=='development' else 'api.push.apple.com'
    payload=json.dumps(dict(aps=dict(alert=dict(title=TITLES.get(note['kind'],'Ride update'),body='Open UniRide to view your trip update.'),sound='default'),rideId=note['rideId']))
    # curl reads the authorization header through stdin, keeping JWTs out of process arguments.
    config='\n'.join([
        'http2', 'silent', 'show-error', 'max-time = 10', 'request = "POST"',
        'url = '+json.dumps('https://'+host+'/3/device/'+device),
        'header = '+json.dumps('authorization: bearer '+jwt()),
        'header = '+json.dumps('apns-topic: '+os.getenv('UNIRIDE_APNS_TOPIC','HMZ.UniRide')),
        'header = "apns-push-type: alert"', 'header = "apns-priority: 10"',
        'data = '+json.dumps(payload), 'write-out = "%{http_code}"'
    ])
    result=subprocess.run(['curl','--config','-'],input=config.encode(),capture_output=True,check=True,timeout=15)
    return int(result.stdout[-3:])

def worker(service):
    while True:
        try:
            if configured():
                with service.connect() as db:
                    batch=db.execute('SELECT * FROM push_queue WHERE retry_at<? AND attempts<5 LIMIT 20',(time.time(),)).fetchall()
                for item in batch:
                    try: status=send(item['device_token'],json.loads(item['data']))
                    except (OSError,ValueError,subprocess.SubprocessError): status=503
                    with service.connect() as db:
                        if status in (200,400,403,410):
                            db.execute('DELETE FROM push_queue WHERE notification_id=? AND device_token=?',(item['notification_id'],item['device_token']))
                            if status in (400,410): db.execute('DELETE FROM devices WHERE token=?',(item['device_token'],))
                        else: db.execute('UPDATE push_queue SET attempts=attempts+1,retry_at=? WHERE notification_id=? AND device_token=?',(time.time()+60,item['notification_id'],item['device_token']))
        except Exception: pass # A provider outage cannot block seat decisions.
        time.sleep(5)
