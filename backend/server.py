"""UniRide API. Python 3.11+, SQLite transactions, bearer sessions, no runtime dependencies."""
from __future__ import annotations
import argparse, hashlib, hmac, json, os, re, secrets, smtplib, sqlite3, threading, time, uuid
from datetime import datetime, timedelta
from contextlib import contextmanager
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from zoneinfo import ZoneInfo

PLACES = [
    dict(id='ista2', name='ISTA 2', address='Quartier Administratif, Settat', latitude=33.014, longitude=-7.611, isUniversityLocation=True),
    dict(id='encg', name='ENCG Settat', address='Campus universitaire, Settat', latitude=33.004, longitude=-7.621, isUniversityLocation=True),
    dict(id='station', name='Gare de Settat', address='Gare ferroviaire, Settat', latitude=32.990, longitude=-7.622, isUniversityLocation=False),
    dict(id='bus', name='Gare Routière Settat', address='Gare routière, Settat', latitude=33.007, longitude=-7.619, isUniversityLocation=False),
    dict(id='science', name='Faculté des Sciences', address='Campus universitaire, Settat', latitude=33.001, longitude=-7.619, isUniversityLocation=True),
    dict(id='health', name='Institut de Santé', address='Settat', latitude=33.008, longitude=-7.609, isUniversityLocation=True),
]
# These are suggested landmarks, not surveyed entrances; each offer includes its own meeting note.

def uid(): return str(uuid.uuid4())
def digest(value): return hashlib.sha256(value.encode()).hexdigest()
def password_hash(password, salt): return hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 600_000).hex()
def text(value, maximum=200):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum: raise Fault(400, 'Please check the required fields.')
    return value.strip()
def integer(value, minimum, maximum):
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum: raise Fault(400, 'Invalid number.')
    return value
class Fault(Exception):
    def __init__(self, status, message): self.status, self.message = status, message

class Service:
    def __init__(self, path):
        self.path = str(path)
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,email TEXT UNIQUE,salt TEXT,password TEXT,data TEXT,preferences TEXT);
            CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id TEXT,expires REAL);
            CREATE TABLE IF NOT EXISTS rides(id TEXT PRIMARY KEY,driver_id TEXT,data TEXT);
            CREATE TABLE IF NOT EXISTS bookings(id TEXT PRIMARY KEY,ride_id TEXT,passenger_id TEXT,seats INTEGER,status TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS messages(id TEXT PRIMARY KEY,booking_id TEXT,sender_id TEXT,text TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS notifications(id TEXT PRIMARY KEY,user_id TEXT,data TEXT);
            CREATE TABLE IF NOT EXISTS reviews(id TEXT PRIMARY KEY,ride_id TEXT,author_id TEXT,subject_id TEXT,data TEXT,UNIQUE(ride_id,author_id));
            CREATE TABLE IF NOT EXISTS verifications(user_id TEXT PRIMARY KEY,code_hash TEXT,expires REAL,attempts INTEGER);
            CREATE TABLE IF NOT EXISTS devices(token TEXT PRIMARY KEY,user_id TEXT);
            CREATE TABLE IF NOT EXISTS push_queue(notification_id TEXT,device_token TEXT,data TEXT,attempts INTEGER,retry_at REAL,PRIMARY KEY(notification_id,device_token));
            CREATE INDEX IF NOT EXISTS bookings_ride ON bookings(ride_id,status);
            CREATE INDEX IF NOT EXISTS messages_booking ON messages(booking_id,created);
            ''')
        os.chmod(self.path, 0o600)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def notification(self, db, user, kind, ride, booking=None):
        n = dict(id=uid(), kind=kind, rideId=ride, bookingId=booking, createdAt=time.time(), read=False)
        db.execute('INSERT INTO notifications VALUES(?,?,?)', (n['id'], user, json.dumps(n)))
        for device in db.execute('SELECT token FROM devices WHERE user_id=?',(user,)).fetchall():
            db.execute('INSERT OR IGNORE INTO push_queue VALUES(?,?,?,0,0)',(n['id'],device['token'],json.dumps(n)))
        return n

    def ride(self, db, identifier):
        row = db.execute('SELECT data FROM rides WHERE id=?', (identifier,)).fetchone()
        if not row: raise Fault(404, 'Ride not found.')
        ride = json.loads(row['data'])
        used = db.execute("SELECT COALESCE(SUM(seats),0) FROM bookings WHERE ride_id=? AND status='confirmed'", (identifier,)).fetchone()[0]
        ride['availableSeats'] = ride['totalSeats'] - used
        return ride

    def save_ride(self, db, ride):
        data = dict(ride)
        data.pop('availableSeats', None)
        db.execute('INSERT OR REPLACE INTO rides VALUES(?,?,?)', (ride['id'], ride['driverId'], json.dumps(data)))

    def user_id(self, db, token):
        row = db.execute('SELECT user_id FROM sessions WHERE token=? AND expires>?', (digest(token), time.time())).fetchone()
        if not row: raise Fault(401, 'Please sign in again.')
        return row['user_id']

    def snapshot(self, db, user):
        own = db.execute('SELECT data,preferences FROM users WHERE id=?', (user,)).fetchone()
        profiles = []
        for row in db.execute('SELECT id,data FROM users'):
            p = json.loads(row['data'])
            if row['id'] != user: p.pop('email', None); p.pop('phone', None)
            ratings = [json.loads(r['data'])['stars'] for r in db.execute('SELECT data FROM reviews WHERE subject_id=?', (row['id'],))]
            p['reviewCount'] = len(ratings)
            p['rating'] = sum(ratings) / len(ratings) if ratings else 0
            p['totalRides'] = db.execute("SELECT COUNT(*) FROM rides WHERE driver_id=? AND json_extract(data,'$.status')='completed'", (row['id'],)).fetchone()[0]
            profiles.append(p)
        rides = [self.ride(db, r['id']) for r in db.execute('SELECT id FROM rides')]
        bookings = [dict(r) for r in db.execute('''SELECT b.* FROM bookings b JOIN rides r ON r.id=b.ride_id WHERE b.passenger_id=? OR r.driver_id=?''', (user,user))]
        translated = [dict(id=b['id'],rideId=b['ride_id'],passengerId=b['passenger_id'],seats=b['seats'],status=b['status'],createdAt=b['created']) for b in bookings]
        ids = {b['id'] for b in bookings}
        messages = [dict(id=r['id'],bookingId=r['booking_id'],senderId=r['sender_id'],text=r['text'],createdAt=r['created']) for r in db.execute('SELECT * FROM messages ORDER BY created') if r['booking_id'] in ids]
        notes = [json.loads(r['data']) for r in db.execute('SELECT data FROM notifications WHERE user_id=?', (user,))]
        reviews = [json.loads(r['data']) for r in db.execute('SELECT data FROM reviews')]
        visible = [r for r in rides if r['driverId']==user or any(b['rideId']==r['id'] for b in translated) or (r['status']=='scheduled' and r['departureTime']>time.time())]
        return dict(currentUser=next(p for p in profiles if p['id']==user),users=profiles,rides=visible,bookings=translated,messages=messages,notifications=notes,reviews=reviews,preferences=json.loads(own['preferences']))

    def handle(self, method, path, body=None, token=''):
        body = body or {}
        if not isinstance(body, dict): raise Fault(400, 'Expected an object.')
        path = path.strip('/').split('/')
        if method=='GET' and path==['health']: return dict(status='ok',smtpConfigured=bool(os.getenv('UNIRIDE_SMTP_HOST')))
        if method=='GET' and path==['places']: return PLACES
        with self.connect() as db:
            # Serialize decisions so two concurrent accepts cannot oversell the last seat.
            db.execute('BEGIN IMMEDIATE')
            if method=='POST' and path in (['signup'],['login']):
                email = text(body.get('email'),254).lower()
                if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email): raise Fault(400,'Enter a valid email address.')
                password = body.get('password')
                if not isinstance(password,str) or not 10<=len(password)<=128: raise Fault(400,'Use at least 10 characters for your password.')
                row = db.execute('SELECT * FROM users WHERE email=?',(email,)).fetchone()
                if path==['signup']:
                    if row: raise Fault(409,'An account already exists for this email.')
                    user, salt = uid(), secrets.token_hex(16)
                    profile = dict(id=user,name=text(body.get('name'),80),email=email,university=text(body.get('university'),120),carModel='',carColor='',plate='',bio='',emailVerified=False,studentEmailVerified=False,rating=0,reviewCount=0,totalRides=0)
                    prefs = dict(favoriteLocationIDs=[],homeLocationId=None,savedCommutes=[])
                    db.execute('INSERT INTO users VALUES(?,?,?,?,?,?)',(user,email,salt,password_hash(password,salt),json.dumps(profile),json.dumps(prefs)))
                else:
                    if not row or not hmac.compare_digest(row['password'], password_hash(password,row['salt'])): raise Fault(401,'Email or password is incorrect.')
                    user = row['id']
                token = secrets.token_urlsafe(32)
                db.execute('INSERT INTO sessions VALUES(?,?,?)',(digest(token),user,time.time()+30*86400))
                return dict(token=token,snapshot=self.snapshot(db,user))
            user = self.user_id(db, token)
            if method=='GET' and path==['snapshot']: return self.snapshot(db,user)
            if method=='POST' and path==['logout']:
                db.execute('DELETE FROM sessions WHERE token=?',(digest(token),))
                device=body.get('deviceToken')
                if isinstance(device,str) and db.execute('SELECT 1 FROM devices WHERE token=? AND user_id=?',(device,user)).fetchone():
                    db.execute('DELETE FROM push_queue WHERE device_token=?',(device,))
                    db.execute('DELETE FROM devices WHERE token=?',(device,))
                return dict(ok=True)
            if method=='PATCH' and path==['profile']:
                p = json.loads(db.execute('SELECT data FROM users WHERE id=?',(user,)).fetchone()[0])
                for key in ('name','university','carModel','carColor','plate','bio'):
                    if key in body:
                        value = body[key]
                        if not isinstance(value,str) or len(value)>200: raise Fault(400,'Invalid profile field.')
                        if key in ('name','university') and not value.strip(): raise Fault(400,'Name and university are required.')
                        p[key]=value.strip()
                db.execute('UPDATE users SET data=? WHERE id=?',(json.dumps(p),user))
            elif method=='PUT' and path==['preferences']:
                favorite = body.get('favoriteLocationIDs',[])
                home = body.get('homeLocationId')
                commutes = body.get('savedCommutes',[])
                place_ids={p['id'] for p in PLACES}
                if not isinstance(favorite,list) or len(favorite)>20 or any(x not in place_ids for x in favorite): raise Fault(400,'Invalid favorite locations.')
                if home is not None and home not in place_ids: raise Fault(400,'Invalid home meeting point.')
                if not isinstance(commutes,list) or len(commutes)>20: raise Fault(400,'Too many saved commutes.')
                for c in commutes:
                    if not isinstance(c,dict) or c.get('fromId') not in place_ids or c.get('toId') not in place_ids or c['fromId']==c['toId']: raise Fault(400,'Invalid commute.')
                    c['name']=text(c.get('name'),80); c['id']=text(c.get('id'),80)
                db.execute('UPDATE users SET preferences=? WHERE id=?',(json.dumps(dict(favoriteLocationIDs=favorite,homeLocationId=home,savedCommutes=commutes)),user))
            elif method=='POST' and path==['rides']:
                places = {p['id']:p for p in PLACES}
                source,target = body.get('fromId'),body.get('toId')
                if source not in places or target not in places or source==target: raise Fault(400,'Choose two different locations.')
                departure = body.get('departureTime')
                price=body.get('price')
                if isinstance(price,bool) or not isinstance(price,(float,int)) or not 1<=price<=200: raise Fault(400,'Price must be between 1 and 200 Dhs.')
                if isinstance(departure,bool) or not isinstance(departure,(float,int)) or not time.time()+30<=departure<=time.time()+90*86400: raise Fault(400,'Choose a future departure within 90 days.')
                seats=integer(body.get('totalSeats'),1,6)
                meeting=text(body.get('pickupNote'),300)
                days=body.get('repeatWeekdays',[])
                if not isinstance(days,list) or len(set(days))!=len(days): raise Fault(400,'Invalid repeat days.')
                for day in days: integer(day,1,7)
                profile=json.loads(db.execute('SELECT data FROM users WHERE id=?',(user,)).fetchone()[0])
                if not all(profile[k] for k in ('carModel','carColor','plate')): raise Fault(400,'Add your car details in Profile before offering a ride.')
                start = datetime.fromtimestamp(departure,ZoneInfo('Africa/Casablanca'))
                dates = [departure] if not days else [(start+timedelta(days=i)).timestamp() for i in range(14) if (start+timedelta(days=i)).isoweekday() in days]
                series=uid() if days else None
                for date in dates:
                    ride=dict(id=uid(),driverId=user,fromLocation=places[source],toLocation=places[target],departureTime=date,price=float(price),totalSeats=seats,status='scheduled',pickupNote=meeting,repeatWeekdays=days,seriesId=series,createdAt=time.time())
                    self.save_ride(db,ride)
            elif len(path)>=2 and path[0]=='rides':
                ride=self.ride(db,path[1])
                if method=='POST' and len(path)==3 and path[2]=='request':
                    if ride['driverId']==user: raise Fault(400,'You cannot request your own ride.')
                    if ride['status']!='scheduled' or ride['departureTime']<=time.time(): raise Fault(409,'This ride is no longer available.')
                    seats=integer(body.get('seats'),1,6)
                    if seats>ride['availableSeats']: raise Fault(409,'There are not enough seats.')
                    if db.execute("SELECT id FROM bookings WHERE ride_id=? AND passenger_id=? AND status IN ('requested','confirmed')",(ride['id'],user)).fetchone(): raise Fault(409,'You already have a request for this ride.')
                    booking=uid()
                    db.execute('INSERT INTO bookings VALUES(?,?,?,?,?,?)',(booking,ride['id'],user,seats,'requested',time.time()))
                    self.notification(db,ride['driverId'],'request',ride['id'],booking)
                else:
                    if ride['driverId']!=user: raise Fault(403,'Only the driver can change this ride.')
                    participants=db.execute("SELECT * FROM bookings WHERE ride_id=? AND status IN ('requested','confirmed')",(ride['id'],)).fetchall()
                    if method=='PATCH' and len(path)==2:
                        if ride['status']!='scheduled': raise Fault(409,'Only scheduled rides can be edited.')
                        new_time=body.get('departureTime',ride['departureTime'])
                        if not isinstance(new_time,(int,float)) or isinstance(new_time,bool) or not time.time()+30<new_time<time.time()+90*86400: raise Fault(400,'Choose a future departure within 90 days.')
                        ride['departureTime']=new_time
                        ride['pickupNote']=text(body.get('pickupNote',ride['pickupNote']),300)
                        kind='changed'
                    elif method=='POST' and len(path)==3:
                        action=path[2]
                        if action=='start' and ride['status']=='scheduled':
                            ride['status']='inProgress'; kind='started'
                            for b in participants:
                                if b['status']=='requested':
                                    db.execute("UPDATE bookings SET status='declined' WHERE id=?",(b['id'],))
                                    self.notification(db,b['passenger_id'],'declined',ride['id'],b['id'])
                            participants=[b for b in participants if b['status']=='confirmed']
                        elif action=='complete' and ride['status']=='inProgress': ride['status']='completed'; kind='completed'
                        elif action=='cancel' and ride['status'] in ('scheduled','inProgress'):
                            ride['status']='cancelled'; kind='cancelled'
                            db.execute("UPDATE bookings SET status='cancelled' WHERE ride_id=? AND status IN ('requested','confirmed')",(ride['id'],))
                        else: raise Fault(409,'This transition is not available.')
                    else: raise Fault(404,'Route not found.')
                    self.save_ride(db,ride)
                    for b in participants: self.notification(db,b['passenger_id'],kind,ride['id'],b['id'])
            elif len(path)==3 and path[0]=='bookings' and method=='POST':
                b=db.execute('SELECT * FROM bookings WHERE id=?',(path[1],)).fetchone()
                if not b: raise Fault(404,'Booking not found.')
                ride=self.ride(db,b['ride_id'])
                action=path[2]
                if action in ('accept','decline'):
                    if ride['driverId']!=user: raise Fault(403,'Only the driver can decide.')
                    if b['status']!='requested' or ride['status']!='scheduled' or ride['departureTime']<=time.time(): raise Fault(409,'This request is no longer available.')
                    if action=='accept' and b['seats']>ride['availableSeats']: raise Fault(409,'There are not enough seats. Another request may have been accepted.')
                    status='confirmed' if action=='accept' else 'declined'
                    receiver=b['passenger_id']; kind=status
                elif action=='cancel':
                    if user!=b['passenger_id']: raise Fault(403,'Only the passenger can cancel this request.')
                    if b['status'] not in ('requested','confirmed') or ride['status'] not in ('scheduled','inProgress'): raise Fault(409,'This request cannot be cancelled.')
                    status='cancelled'; receiver=ride['driverId']; kind='passengerCancelled'
                elif action=='message':
                    if user not in (b['passenger_id'],ride['driverId']): raise Fault(403,'This conversation is private.')
                    if b['status'] not in ('requested','confirmed'): raise Fault(409,'This conversation is closed.')
                    content=text(body.get('text'),2000)
                    db.execute('INSERT INTO messages VALUES(?,?,?,?,?)',(uid(),b['id'],user,content,time.time()))
                    receiver=ride['driverId'] if user==b['passenger_id'] else b['passenger_id']
                    self.notification(db,receiver,'message',ride['id'],b['id'])
                    return self.snapshot(db,user)
                else: raise Fault(404,'Route not found.')
                db.execute('UPDATE bookings SET status=? WHERE id=?',(status,b['id']))
                self.notification(db,receiver,kind,ride['id'],b['id'])
            elif method=='POST' and path==['reviews']:
                ride=self.ride(db,text(body.get('rideId')))
                b=db.execute("SELECT id FROM bookings WHERE ride_id=? AND passenger_id=? AND status='confirmed'",(ride['id'],user)).fetchone()
                if not b or ride['status']!='completed': raise Fault(403,'Review a completed trip you joined.')
                stars=integer(body.get('stars'),1,5)
                comment=body.get('comment','')
                if not isinstance(comment,str): raise Fault(400,'Invalid review.')
                comment=comment.strip()
                if len(comment)>500: raise Fault(400,'Keep the review under 500 characters.')
                review=dict(id=uid(),rideId=ride['id'],authorId=user,subjectId=ride['driverId'],stars=stars,comment=comment,createdAt=time.time())
                try: db.execute('INSERT INTO reviews VALUES(?,?,?,?,?)',(review['id'],ride['id'],user,ride['driverId'],json.dumps(review)))
                except sqlite3.IntegrityError: raise Fault(409,'You already reviewed this trip.')
            elif method=='POST' and path==['notifications','read']:
                for row in db.execute('SELECT id,data FROM notifications WHERE user_id=?',(user,)).fetchall():
                    note=json.loads(row['data']); note['read']=True
                    db.execute('UPDATE notifications SET data=? WHERE id=?',(json.dumps(note),row['id']))
            elif method=='POST' and path==['verification','request']:
                if not os.getenv('UNIRIDE_SMTP_HOST'): raise Fault(503,'Email delivery is not configured on this server yet.')
                email=db.execute('SELECT email FROM users WHERE id=?',(user,)).fetchone()[0]
                previous=db.execute('SELECT expires FROM verifications WHERE user_id=?',(user,)).fetchone()
                if previous and previous['expires']>time.time()+540: raise Fault(429,'Please wait a minute before requesting another code.')
                code=f'{secrets.randbelow(1_000_000):06d}'
                msg=EmailMessage(); msg['Subject']='UniRide email verification'; msg['From']=os.environ['UNIRIDE_SMTP_FROM']; msg['To']=email
                msg.set_content(f'Your UniRide verification code is {code}. It expires in 10 minutes.')
                try:
                    with smtplib.SMTP(os.environ['UNIRIDE_SMTP_HOST'],int(os.getenv('UNIRIDE_SMTP_PORT','587')),timeout=10) as smtp:
                        smtp.starttls()
                        if os.getenv('UNIRIDE_SMTP_USER'): smtp.login(os.environ['UNIRIDE_SMTP_USER'],os.environ['UNIRIDE_SMTP_PASSWORD'])
                        smtp.send_message(msg)
                except (OSError,smtplib.SMTPException): raise Fault(503,'Unable to deliver the code. Please try later.')
                db.execute('INSERT OR REPLACE INTO verifications VALUES(?,?,?,0)',(user,digest(code),time.time()+600))
            elif method=='POST' and path==['verification','confirm']:
                row=db.execute('SELECT * FROM verifications WHERE user_id=?',(user,)).fetchone()
                if not row or row['expires']<time.time() or row['attempts']>=5: raise Fault(400,'Request a new verification code.')
                if not hmac.compare_digest(row['code_hash'],digest(text(body.get('code'),6))):
                    db.execute('UPDATE verifications SET attempts=attempts+1 WHERE user_id=?',(user,))
                    db.commit() # Persist the failed attempt even though the request returns an error.
                    raise Fault(400,'The code is incorrect.')
                p=json.loads(db.execute('SELECT data FROM users WHERE id=?',(user,)).fetchone()[0]); p['emailVerified']=True
                allowed={d.strip().lower() for d in os.getenv('UNIRIDE_STUDENT_DOMAINS','').split(',') if d.strip()}
                p['studentEmailVerified']=p['email'].split('@')[1] in allowed
                db.execute('UPDATE users SET data=? WHERE id=?',(json.dumps(p),user)); db.execute('DELETE FROM verifications WHERE user_id=?',(user,))
            elif method=='POST' and path==['devices']:
                device=text(body.get('token'),256)
                if len(device)<32 or not all(c in '0123456789abcdefABCDEF' for c in device): raise Fault(400,'Invalid device token.')
                owner=db.execute('SELECT user_id FROM devices WHERE token=?',(device,)).fetchone()
                if owner and owner['user_id']!=user: db.execute('DELETE FROM push_queue WHERE device_token=?',(device,))
                db.execute('INSERT OR REPLACE INTO devices VALUES(?,?)',(device,user))
            else: raise Fault(404,'Route not found.')
            return self.snapshot(db,user)

class Handler(BaseHTTPRequestHandler):
    service: Service
    attempts = {}
    lock=threading.Lock()
    def log_message(self, format, *args): pass # Do not log tokens, passwords, messages, or verification codes.
    def do_GET(self): self.dispatch()
    def do_POST(self): self.dispatch()
    def do_PATCH(self): self.dispatch()
    def do_PUT(self): self.dispatch()
    def dispatch(self):
        try:
            key=(self.client_address[0],self.path if self.path in ('/login','/signup') else 'api')
            with self.lock:
                now=time.time(); times=[t for t in self.attempts.get(key,[]) if t>now-60]
                if len(times)>=(10 if key[1]!='api' else 180): raise Fault(429,'Too many requests. Please wait a minute.')
                self.attempts[key]=times+[now]
            length=int(self.headers.get('Content-Length','0'))
            if length<0 or length>32_768: raise Fault(413,'Request is too large.')
            body=json.loads(self.rfile.read(length)) if length else {}
            token=self.headers.get('Authorization','').removeprefix('Bearer ')
            result=self.service.handle(self.command,self.path.split('?')[0],body,token)
            self.respond(200,result)
        except Fault as e: self.respond(e.status,dict(error=e.message))
        except (ValueError,TypeError,KeyError): self.respond(400,dict(error='Invalid request.'))
        except Exception: self.respond(500,dict(error='Unable to process this request.'))
    def respond(self,status,data):
        encoded=json.dumps(data,ensure_ascii=False,allow_nan=False).encode()
        self.send_response(status); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(encoded))); self.end_headers()
        self.wfile.write(encoded)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--host',default='127.0.0.1'); parser.add_argument('--port',type=int,default=8787); parser.add_argument('--database',default=str(Path(__file__).parent/'data/uniride.sqlite3')); args=parser.parse_args()
    Handler.service=Service(args.database)
    try:
        from .push import worker
    except ImportError:
        from push import worker
    threading.Thread(target=worker,args=(Handler.service,),daemon=True).start()
    server=ThreadingHTTPServer((args.host,args.port),Handler)
    print(f'UniRide API listening on {args.host}:{args.port}',flush=True)
    server.serve_forever()
if __name__=='__main__': main()
