-- Seed data for partner_venue: 4 venues, 12 shows, 80 guests, 310 purchases.
-- This data is DIRTY ON PURPOSE so the Databricks ETL has real cleaning work to do.
-- Run 03_seed_citywide_events.sql first (25 guests are copied from citywide_events.attendee).

SET search_path TO partner_venue;
TRUNCATE purchase, show, guest, venue RESTART IDENTITY CASCADE;
SELECT setseed(0.7);

-- 1) Venues (V01 and V02 are the same places citywide_events uses; city casing is inconsistent)
INSERT INTO venue (venue_code, venue_name, city, seating_capacity, manager_contact, parking_notes) VALUES
('V01', 'Al Dana Amphitheatre', 'Sakhir', 10000, 'ops@aldana.example', 'Use gate 3 for buses'),
('V02', 'Cultural Hall', 'MANAMA', 1200, 'frontdesk@culturalhall.example', 'Street parking only'),
('V03', 'Seef Comedy Club', 'Seef', 300, 'bookings@seefcomedy.example', NULL),
('V04', 'Amwaj Beach Arena', 'amwaj', 2500, 'events@amwajarena.example', 'Valet after 7pm');

-- 2) Shows. PV-001..PV-004 are the SAME events as in citywide_events, but titles are typed
--    differently (upper case, trailing space, lower case) so the ETL must match them.
INSERT INTO show (show_code, show_title, genre, blurb, venue_code, show_datetime, promoter_notes, banner_image) VALUES
('PV-001', 'DESERT ROCK FESTIVAL', 'Music', 'Open-air rock festival with regional bands and a late-night headliner.', 'V01', '2025-11-22 20:00', 'Resold from citywide', 'banner1.png'),
('PV-002', 'Khaleeji Pop Night ', 'Music', 'Khaleeji pop stars perform their latest hits outdoors.', 'V01', '2026-03-27 21:00', 'Resold from citywide', 'banner2.png'),
('PV-003', 'stand-up comedy gala', 'comedy', 'Five touring comedians, one night of English stand-up.', 'V02', '2025-02-20 20:30', 'Resold from citywide', NULL),
('PV-004', 'Arabic Comedy Night', 'Comedy', 'Local comedians joke about Gulf family life.', 'V02', '2025-09-12 20:00', 'Resold from citywide', 'banner4.png'),
('PV-005', 'Seef Laugh Factory', 'Comedy', 'Weekly open-mic comedy with new local talent in a small club.', 'V03', '2025-06-05 21:00', NULL, NULL),
('PV-006', 'Late Night Roast Battle', 'Comedy', 'Comedians roast each other in a no-holds-barred late night show.', 'V03', '2026-04-24 22:00', 'Adults only', 'banner6.png'),
('PV-007', 'Beach Reggae Sundown', 'Music', 'Reggae and island beats on the sand as the sun goes down.', 'V04', '2025-08-15 18:00', NULL, 'banner7.png'),
('PV-008', 'Amwaj Sea Breeze Concert', 'Music', 'A light pop and soul concert by the sea with a cool evening breeze.', 'V04', '2026-05-22 19:00', NULL, 'banner8.png'),
('PV-009', 'Moonlight Yoga & Live Music', 'Wellness', 'Guided beach yoga under the moon with live ambient music.', 'V04', '2026-09-05 19:30', 'Bring own mat', NULL),
('PV-010', 'Poetry Under the Stars', 'arts', 'Arabic and English poets read their work in an open-air setting.', 'V01', '2025-12-12 20:00', NULL, 'banner10.png'),
('PV-011', 'Teen Talent Show', 'Family', NULL, 'V02', '2026-07-10 17:00', 'Blurb missing from promoter', NULL),
('PV-012', 'New Year Countdown Party', 'Music', 'Ring in the new year with DJs, fireworks and a beach countdown.', 'V04', '2026-12-31 21:00', NULL, 'banner12.png');

-- 3a) 25 guests who ALSO exist in citywide_events (same person, messier data: some emails in UPPER case)
INSERT INTO guest (full_name, email, mobile, loyalty_tier, referral_code)
SELECT first_name || ' ' || last_name,
       CASE WHEN attendee_id % 2 = 0 THEN upper(email) ELSE email END,
       replace(phone, ' ', ''),
       (ARRAY['Bronze','Silver','Gold',NULL])[1 + floor(random() * 4)::int],
       'REF-' || attendee_id
FROM citywide_events.attendee
WHERE attendee_id <= 25
ORDER BY attendee_id;

-- 3b) 50 partner-only guests (every 10th has no email, every 7th has an ALL CAPS name)
INSERT INTO guest (full_name, email, mobile, loyalty_tier, referral_code)
SELECT CASE WHEN i % 7 = 0 THEN upper(fn || ' ' || ln) ELSE fn || ' ' || ln END,
       CASE WHEN i % 10 = 0 THEN NULL ELSE lower(fn) || '_' || lower(replace(ln, ' ', '')) || i || '@mail.example.com' END,
       '+9733' || lpad(floor(random() * 9999999)::int::text, 7, '0'),
       (ARRAY['Bronze','Silver','Gold',NULL])[1 + floor(random() * 4)::int],
       NULL
FROM (
    SELECT i,
           (ARRAY['Salman','Mariam','Isa','Latifa','Faisal','Amal','Nasser','Hessa','Saleh','Muneera'])[1 + floor(random() * 10)::int] AS fn,
           (ARRAY['Al Jalahma','Bukhammas','Al Zayani','Kanoo','Fakhro','Al Moayyed','Janahi','Al Arrayed'])[1 + floor(random() * 8)::int] AS ln
    FROM generate_series(1, 50) AS i
) x;

-- 3c) 5 accidental duplicate guests (the same person registered twice)
INSERT INTO guest (full_name, email, mobile, loyalty_tier, referral_code)
SELECT full_name, email, mobile, loyalty_tier, referral_code
FROM guest WHERE guest_no IN (5030, 5035, 5040, 5045, 5050);

-- 4) 300 purchases with messy seat_class text, some missing prices and lower-case show names
WITH g  AS (SELECT array_agg(guest_no) AS ids FROM guest),
     s  AS (SELECT array_agg(show_code) AS codes FROM show),
     bp AS (SELECT * FROM (VALUES ('PV-001', 17), ('PV-002', 16), ('PV-003', 15), ('PV-004', 16),
                                  ('PV-005', 10), ('PV-006', 12), ('PV-007', 14), ('PV-008', 18),
                                  ('PV-009', 9),  ('PV-010', 8),  ('PV-011', 5),  ('PV-012', 25)) v(show_code, base))
INSERT INTO purchase (guest_no, show_code, show_name, seat_class, seat_price, qty, purchased_on, comp_code, till_receipt_no)
SELECT p.guest_no, p.show_code,
       CASE WHEN p.r2 < 0.3 THEN lower(sh.show_title) ELSE sh.show_title END,
       p.seat_class,
       CASE WHEN p.r3 < 0.08 THEN NULL      -- about 8% of prices are missing
            ELSE ROUND(bp.base * CASE WHEN lower(replace(p.seat_class, '.', '')) = 'vip' THEN 2.5
                                      WHEN lower(p.seat_class) = 'student' THEN 0.6
                                      ELSE 1.0 END, 2) END,
       p.qty,
       LEAST(sh.show_datetime - (1 + floor(p.r1 * 40))::int * INTERVAL '1 day' - random() * INTERVAL '10 hours',
             TIMESTAMP '2026-11-18 12:00'),
       CASE WHEN p.r3 > 0.95 THEN 'COMP-' || floor(random() * 1000)::int END,
       'TR-' || lpad(floor(random() * 999999)::int::text, 6, '0')
FROM (
    SELECT g.ids[1 + floor(random() * array_length(g.ids, 1))::int] AS guest_no,
           s.codes[1 + floor(random() * array_length(s.codes, 1))::int] AS show_code,
           (ARRAY['VIP','vip','V.I.P','General','general','General Admission','GA','Student',NULL])[1 + floor(random() * 9)::int] AS seat_class,
           1 + floor(random() * 4)::int AS qty,
           random() AS r1, random() AS r2, random() AS r3
    FROM generate_series(1, 300), g, s
) p
JOIN show sh ON sh.show_code = p.show_code
JOIN bp      ON bp.show_code = p.show_code;

-- 5) 10 duplicate purchases (the till submitted the same sale twice)
INSERT INTO purchase (guest_no, show_code, show_name, seat_class, seat_price, qty, purchased_on, comp_code, till_receipt_no)
SELECT guest_no, show_code, show_name, seat_class, seat_price, qty, purchased_on, comp_code, till_receipt_no
FROM purchase WHERE purchase_no % 30 = 0;

-- Check: row counts per table
SELECT 'venue' AS table_name, COUNT(*) FROM venue
UNION ALL SELECT 'show', COUNT(*) FROM show
UNION ALL SELECT 'guest', COUNT(*) FROM guest
UNION ALL SELECT 'purchase', COUNT(*) FROM purchase;
