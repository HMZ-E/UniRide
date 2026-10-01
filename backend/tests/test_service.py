import concurrent.futures, hashlib, json, os, tempfile, time, unittest
from unittest.mock import patch
from backend.server import Service, Fault

class FlowTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.service=Service(self.temp.name+'/test.sqlite3')
        self.driver=self.signup('driver'); self.a=self.signup('a'); self.b=self.signup('b'); self.outsider=self.signup('outsider')
        self.call('PATCH','/profile',self.driver,dict(carModel='Dacia',carColor='White',plate='12345'))
        state=self.call('POST','/rides',self.driver,dict(fromId='station',toId='ista2',departureTime=time.time()+3600,price=6,totalSeats=1,pickupNote='Main station entrance',repeatWeekdays=[]))
        self.ride=state['rides'][0]['id']
    def signup(self,name): return self.service.handle('POST','/signup',dict(email=name+'@example.com',password='long-password-123',name=name,university='Hassan I'))
    def call(self,method,path,session,body=None): return self.service.handle(method,path,body,session['token'])
    def request(self,session): return self.call('POST','/rides/'+self.ride+'/request',session,dict(seats=1))['bookings'][-1]['id']
    def assertFault(self,status,method,path,session,body=None):
        with self.assertRaises(Fault) as error: self.call(method,path,session,body)
        self.assertEqual(error.exception.status,status)
    def test_password_and_session(self):
        self.assertFault(401,'POST','/login',self.a,dict(email='a@example.com',password='wrong-password-123'))
        result=self.service.handle('POST','/login',dict(email='a@example.com',password='long-password-123'))
        self.assertEqual(result['snapshot']['currentUser']['id'],self.a['snapshot']['currentUser']['id'])
        self.call('POST','/logout',result)
        self.assertFault(401,'GET','/snapshot',result)
        with self.service.connect() as db:
            secret=db.execute('SELECT password FROM users WHERE email=?',('a@example.com',)).fetchone()[0]
            self.assertNotEqual(secret,'long-password-123')
            self.assertFalse(db.execute('SELECT token FROM sessions WHERE token=?',(self.a['token'],)).fetchone())
    def test_no_fake_verification_and_private_email(self):
        state=self.call('GET','/snapshot',self.a)
        self.assertFalse(state['currentUser']['studentEmailVerified'])
        driver=next(u for u in state['users'] if u['id']==self.driver['snapshot']['currentUser']['id'])
        self.assertNotIn('email',driver); self.assertEqual(driver['reviewCount'],0)
    def test_repeat_departures_have_independent_seats(self):
        state=self.call('POST','/rides',self.driver,dict(fromId='ista2',toId='encg',departureTime=time.time()+7200,price=8,totalSeats=3,pickupNote='Gate',repeatWeekdays=[1,2,3,4,5]))
        repeats=[r for r in state['rides'] if r['seriesId']]
        self.assertEqual(len(repeats),10)
        self.assertEqual(len({r['id'] for r in repeats}),10)
        self.assertEqual(len({r['seriesId'] for r in repeats}),1)
        self.assertTrue(all(r['availableSeats']==3 for r in repeats))
    def test_two_accepts_cannot_oversell(self):
        one,two=self.request(self.a),self.request(self.b)
        def accept(identifier):
            try: self.call('POST','/bookings/'+identifier+'/accept',self.driver); return 200
            except Fault as e: return e.status
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(accept,[one,two]))
        self.assertEqual(sorted(results),[200,409])
        state=self.call('GET','/snapshot',self.driver)
        self.assertEqual(state['rides'][0]['availableSeats'],0)
    def test_cancel_releases_seat_and_rebooking(self):
        booking=self.request(self.a)
        self.call('POST','/bookings/'+booking+'/accept',self.driver)
        state=self.call('POST','/bookings/'+booking+'/cancel',self.a)
        self.assertEqual(state['rides'][0]['availableSeats'],1)
        self.assertNotEqual(booking,self.request(self.a))
    def test_duplicate_and_own_requests_rejected(self):
        self.request(self.a)
        self.assertFault(409,'POST','/rides/'+self.ride+'/request',self.a,dict(seats=1))
        self.assertFault(400,'POST','/rides/'+self.ride+'/request',self.driver,dict(seats=1))
    def test_driver_decision_authorization(self):
        booking=self.request(self.a)
        self.assertFault(403,'POST','/bookings/'+booking+'/accept',self.b)
        self.assertFault(403,'POST','/rides/'+self.ride+'/cancel',self.a)
        self.assertFault(403,'POST','/bookings/'+booking+'/cancel',self.b)
    def test_private_chat(self):
        booking=self.request(self.a)
        self.call('POST','/bookings/'+booking+'/message',self.a,dict(text='Meet by the entrance?'))
        state=self.call('POST','/bookings/'+booking+'/message',self.driver,dict(text='Yes, white Dacia.'))
        self.assertEqual(len(state['messages']),2)
        outside=self.call('GET','/snapshot',self.outsider)
        self.assertEqual(outside['messages'],[]); self.assertEqual(outside['bookings'],[])
        self.assertFault(403,'POST','/bookings/'+booking+'/message',self.outsider,dict(text='Intrusion'))
        self.call('POST','/bookings/'+booking+'/decline',self.driver)
        self.assertFault(409,'POST','/bookings/'+booking+'/message',self.a,dict(text='Closed chat'))
    def test_driver_cancel_and_notifications(self):
        booking=self.request(self.a)
        self.call('POST','/bookings/'+booking+'/accept',self.driver)
        self.call('POST','/rides/'+self.ride+'/cancel',self.driver)
        state=self.call('GET','/snapshot',self.a)
        self.assertEqual(state['bookings'][0]['status'],'cancelled')
        self.assertEqual(state['rides'][0]['status'],'cancelled')
        self.assertIn('cancelled',[n['kind'] for n in state['notifications']])
        self.assertFault(409,'POST','/rides/'+self.ride+'/request',self.b,dict(seats=1))
    def test_departure_change_notifies_passenger(self):
        self.request(self.a)
        changed=time.time()+5400
        state=self.call('PATCH','/rides/'+self.ride,self.driver,dict(departureTime=changed,pickupNote='Side entrance'))
        self.assertEqual(state['rides'][0]['departureTime'],changed)
        passenger=self.call('GET','/snapshot',self.a)
        self.assertEqual(passenger['notifications'][-1]['kind'],'changed')
    def test_start_declines_pending_requests(self):
        self.request(self.a)
        state=self.call('POST','/rides/'+self.ride+'/start',self.driver)
        self.assertEqual(state['bookings'][0]['status'],'declined')
        self.assertFault(409,'POST','/bookings/'+state['bookings'][0]['id']+'/accept',self.driver)
    def test_completed_trip_review(self):
        booking=self.request(self.a)
        self.call('POST','/bookings/'+booking+'/accept',self.driver)
        self.assertFault(403,'POST','/reviews',self.a,dict(rideId=self.ride,stars=5,comment='Too early'))
        self.call('POST','/rides/'+self.ride+'/start',self.driver)
        self.call('POST','/rides/'+self.ride+'/complete',self.driver)
        state=self.call('POST','/reviews',self.a,dict(rideId=self.ride,stars=4,comment='Good pickup'))
        driver=next(u for u in state['users'] if u['id']==self.driver['snapshot']['currentUser']['id'])
        self.assertEqual((driver['rating'],driver['reviewCount'],driver['totalRides']),(4,1,1))
        self.assertFault(409,'POST','/reviews',self.a,dict(rideId=self.ride,stars=5,comment='Duplicate'))
        self.assertFault(403,'POST','/reviews',self.outsider,dict(rideId=self.ride,stars=5,comment='Fake'))
    def test_favorites_are_private_and_persistent(self):
        prefs=dict(favoriteLocationIDs=['encg'],homeLocationId='station',savedCommutes=[dict(id='one',name='Morning commute',fromId='station',toId='encg')])
        self.call('PUT','/preferences',self.a,prefs)
        self.assertEqual(self.call('GET','/snapshot',self.a)['preferences'],prefs)
        self.assertEqual(self.call('GET','/snapshot',self.b)['preferences']['savedCommutes'],[])
    def test_missing_smtp_does_not_verify(self):
        with patch.dict(os.environ,{'UNIRIDE_SMTP_HOST':''}): self.assertFault(503,'POST','/verification/request',self.a)
        self.assertFalse(self.call('GET','/snapshot',self.a)['currentUser']['emailVerified'])
    def test_verification_attempts_and_domain_check(self):
        user=self.a['snapshot']['currentUser']['id']
        with self.service.connect() as db: db.execute('INSERT INTO verifications VALUES(?,?,?,0)',(user,hashlib.sha256(b'123456').hexdigest(),time.time()+600))
        for _ in range(5): self.assertFault(400,'POST','/verification/confirm',self.a,dict(code='654321'))
        self.assertFault(400,'POST','/verification/confirm',self.a,dict(code='123456'))
        with self.service.connect() as db: db.execute('UPDATE verifications SET attempts=0 WHERE user_id=?',(user,))
        with patch.dict(os.environ,{'UNIRIDE_STUDENT_DOMAINS':'approved.edu'}):
            state=self.call('POST','/verification/confirm',self.a,dict(code='123456'))
        self.assertTrue(state['currentUser']['emailVerified']); self.assertFalse(state['currentUser']['studentEmailVerified'])
    def test_invalid_offer(self):
        base=dict(fromId='ista2',toId='encg',departureTime=time.time()+3600,price=6,totalSeats=2,pickupNote='Gate',repeatWeekdays=[])
        for change in [dict(totalSeats=0),dict(price=-1),dict(price=float('nan')),dict(departureTime=time.time()-1),dict(toId='ista2'),dict(pickupNote='')]:
            self.assertFault(400,'POST','/rides',self.driver,dict(base,**change))
    def test_mark_notifications_read(self):
        self.request(self.a)
        state=self.call('POST','/notifications/read',self.driver)
        self.assertTrue(all(n['read'] for n in state['notifications']))

    def test_device_reassignment_and_logout_remove_old_pushes(self):
        device='ab'*32
        self.call('POST','/devices',self.driver,dict(token=device))
        self.request(self.a)
        with self.service.connect() as db:
            self.assertGreater(db.execute('SELECT count(*) FROM push_queue WHERE device_token=?',(device,)).fetchone()[0],0)
        self.call('POST','/devices',self.a,dict(token=device))
        with self.service.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM push_queue WHERE device_token=?',(device,)).fetchone()[0],0)
        self.call('POST','/logout',self.a,dict(deviceToken=device))
        with self.service.connect() as db:
            self.assertIsNone(db.execute('SELECT token FROM devices WHERE token=?',(device,)).fetchone())

    def test_password_spaces_are_preserved(self):
        password='  significant spaces  '
        self.service.handle('POST','/signup',dict(name='Space',university='Hassan I',email='spaces@example.test',password=password))
        self.service.handle('POST','/login',dict(email='spaces@example.test',password=password))
        with self.assertRaises(Fault):
            self.service.handle('POST','/login',dict(email='spaces@example.test',password=password.strip()))

if __name__=='__main__': unittest.main()
