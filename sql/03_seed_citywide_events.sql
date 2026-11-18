-- Seed data for citywide_events: 30 events, ticket types, 120 attendees, 450 orders.
-- Safe to re-run: it empties the tables first and restarts the IDs at 1.

SET search_path TO citywide_events;
TRUNCATE order_header, ticket_type, event, attendee RESTART IDENTITY CASCADE;
SELECT setseed(0.42);   -- same "random" data on every run

-- 1) Events (hand-written descriptions: these get embedded for the pgvector search later)
INSERT INTO event (event_name, category, description, venue_name, city, event_date, poster_url, internal_notes) VALUES
('Summer Jazz Nights', 'Music', 'An outdoor jazz concert on the waterfront with a live saxophone quartet, smooth summer evening vibes and food trucks.', 'Bahrain Bay Waterfront', 'Manama', '2025-06-14', 'https://img.example.com/e1.jpg', 'Check generator fuel'),
('Desert Rock Festival', 'Music', 'A loud open-air rock festival under the stars featuring regional rock bands, electric guitars and a late-night headliner.', 'Al Dana Amphitheatre', 'Sakhir', '2025-11-22', 'https://img.example.com/e2.jpg', 'Partner venue also sells this'),
('Arabian Oud Evening', 'Music', 'An intimate traditional Arabic music night with oud and qanun players performing classic Gulf and Egyptian songs.', 'Cultural Hall', 'Manama', '2025-03-08', 'https://img.example.com/e3.jpg', NULL),
('Bahrain Philharmonic: Beethoven 9', 'Music', 'A full symphony orchestra and choir perform Beethoven''s Ninth Symphony in an elegant indoor concert hall.', 'Bahrain National Theatre', 'Manama', '2025-10-04', 'https://img.example.com/e4.jpg', 'Choir needs extra rehearsal room'),
('Electronic Beach Party', 'Music', 'A high-energy electronic dance music party on the beach with international DJs, light shows and dancing until midnight.', 'Bahrain Bay Waterfront', 'Manama', '2026-07-18', 'https://img.example.com/e5.jpg', NULL),
('Khaleeji Pop Night', 'Music', 'Popular Khaleeji pop singers perform their latest hits in a big outdoor arena concert for the whole family.', 'Al Dana Amphitheatre', 'Sakhir', '2026-03-27', 'https://img.example.com/e6.jpg', 'Partner venue also sells this'),
('Acoustic Sunset Sessions', 'Music', 'Relaxed acoustic guitar and singer-songwriter performances at sunset in a historic open-air market square.', 'Muharraq Souq Square', 'Muharraq', '2026-04-11', 'https://img.example.com/e7.jpg', NULL),
('Stand-Up Comedy Gala', 'Comedy', 'An evening of English stand-up comedy with five touring comedians telling jokes about everyday life and travel.', 'Cultural Hall', 'Manama', '2025-02-20', 'https://img.example.com/e8.jpg', 'Partner venue also sells this'),
('Arabic Comedy Night', 'Comedy', 'Local comedians perform hilarious Arabic stand-up about Gulf family life, weddings and traffic jams.', 'Cultural Hall', 'Manama', '2025-09-12', 'https://img.example.com/e9.jpg', 'Partner venue also sells this'),
('Improv Showdown', 'Comedy', 'Two improvisation teams compete live using audience suggestions in a fast, interactive and unscripted comedy battle.', 'Bahrain National Theatre', 'Manama', '2026-05-09', 'https://img.example.com/e10.jpg', NULL),
('Formula 1 Grand Prix Weekend', 'Sports', 'Three days of high-speed Formula 1 motor racing with practice sessions, qualifying and the main Grand Prix race.', 'Bahrain International Circuit', 'Sakhir', '2025-04-13', 'https://img.example.com/e11.jpg', 'VIP parking lot B'),
('Gulf Football Derby', 'Sports', 'A heated football derby match between two top Gulf clubs in a packed national stadium with passionate fans.', 'Bahrain National Stadium', 'Riffa', '2025-12-05', 'https://img.example.com/e12.jpg', NULL),
('Bahrain Night Marathon', 'Sports', 'A night-time running race through the city with 5K, 10K and full marathon distances along the bay.', 'Bahrain Bay Waterfront', 'Manama', '2026-02-06', 'https://img.example.com/e13.jpg', 'Road closures approved'),
('Basketball Championship Final', 'Sports', 'The national basketball league final, an indoor match deciding this season''s champions.', 'Bahrain National Stadium', 'Riffa', '2026-06-20', 'https://img.example.com/e14.jpg', NULL),
('Endurance Kart Race', 'Sports', 'A six-hour endurance go-kart race where amateur teams drive in shifts on a professional track.', 'Bahrain International Circuit', 'Sakhir', '2026-10-17', 'https://img.example.com/e15.jpg', NULL),
('Romeo and Juliet', 'Theatre', 'A classic Shakespeare tragedy about two young lovers, performed in English by a touring drama company.', 'Bahrain National Theatre', 'Manama', '2025-05-17', 'https://img.example.com/e16.jpg', NULL),
('The Pearl Diver''s Tale', 'Theatre', 'A dramatic Arabic play about Bahrain''s pearl diving history, the sea and the families who waited on shore.', 'Cultural Hall', 'Manama', '2025-12-16', 'https://img.example.com/e17.jpg', 'National Day special'),
('Lion King Musical Tribute', 'Theatre', 'A colourful musical theatre tribute with singing, dancing and costumes inspired by the famous animated story.', 'Bahrain National Theatre', 'Manama', '2026-01-23', 'https://img.example.com/e18.jpg', NULL),
('Kids Puppet Theatre', 'Family', 'A funny puppet show for young children with songs, animals and audience participation, perfect for ages 3 to 8.', 'Cultural Hall', 'Manama', '2025-07-26', 'https://img.example.com/e19.jpg', NULL),
('Science Fun Fair', 'Family', 'Hands-on science experiments, robots and planetarium shows for curious kids and their parents.', 'Exhibition World Bahrain', 'Sakhir', '2026-08-08', 'https://img.example.com/e20.jpg', NULL),
('Winter Family Carnival', 'Family', 'An outdoor winter carnival with rides, games, face painting and fireworks for families of all ages.', 'Bahrain Bay Waterfront', 'Manama', '2026-12-19', 'https://img.example.com/e21.jpg', 'Fireworks permit pending'),
('Bahrain Food Festival', 'Food', 'A large outdoor food festival with local Bahraini dishes, international street food and live cooking shows.', 'Bahrain Bay Waterfront', 'Manama', '2025-01-31', 'https://img.example.com/e22.jpg', NULL),
('Street Food & Coffee Fest', 'Food', 'Specialty coffee roasters and street food stalls fill the old souq with tastings, latte art and music.', 'Muharraq Souq Square', 'Muharraq', '2026-11-28', 'https://img.example.com/e23.jpg', NULL),
('Gulf Tech Summit', 'Conference', 'A technology conference about cloud computing, cybersecurity and startups with keynote talks and networking.', 'Exhibition World Bahrain', 'Sakhir', '2025-09-24', 'https://img.example.com/e24.jpg', 'Sponsor booths hall 2'),
('Data & AI Conference', 'Conference', 'Talks and workshops on data analytics, machine learning and artificial intelligence for students and professionals.', 'Exhibition World Bahrain', 'Sakhir', '2026-09-16', 'https://img.example.com/e25.jpg', NULL),
('Startup Pitch Night', 'Conference', 'Young entrepreneurs pitch their startup ideas to a panel of investors in a friendly competition.', 'Cultural Hall', 'Manama', '2026-02-26', 'https://img.example.com/e26.jpg', NULL),
('Contemporary Art Exhibition', 'Arts', 'A gallery exhibition of modern paintings, sculptures and digital art by emerging Gulf artists.', 'Muharraq Souq Square', 'Muharraq', '2025-04-25', 'https://img.example.com/e27.jpg', NULL),
('Calligraphy Workshop', 'Arts', 'A hands-on Arabic calligraphy class where beginners learn traditional scripts with ink and reed pens.', 'Cultural Hall', 'Manama', '2026-01-10', 'https://img.example.com/e28.jpg', 'Max 40 seats'),
('Open-Air Cinema: Classics', 'Film', 'Classic Hollywood movies screened outdoors on a giant screen by the sea, with blankets and popcorn.', 'Bahrain Bay Waterfront', 'Manama', '2025-11-07', 'https://img.example.com/e29.jpg', NULL),
('Horror Movie Marathon', 'Film', 'A scary all-night Halloween horror film marathon in a dark cinema hall, not for the faint-hearted.', 'Cultural Hall', 'Manama', '2026-10-31', 'https://img.example.com/e30.jpg', NULL);

-- 2) Ticket types: General + VIP for every event, Student for some categories
INSERT INTO ticket_type (event_id, type_name, price, capacity, print_template_code, sales_rep_code)
SELECT e.event_id, t.type_name, ROUND(b.base * t.mult, 2), t.cap,
       'TPL-' || t.type_name, 'REP-' || (1 + e.event_id % 4)
FROM event e
CROSS JOIN LATERAL (
    SELECT CASE WHEN e.event_name LIKE 'Formula 1%' THEN 60
                ELSE CASE e.category WHEN 'Music' THEN 15 WHEN 'Comedy' THEN 12 WHEN 'Sports' THEN 20
                                     WHEN 'Theatre' THEN 18 WHEN 'Family' THEN 8 WHEN 'Food' THEN 5
                                     WHEN 'Conference' THEN 40 WHEN 'Arts' THEN 6 ELSE 7 END
           END + e.event_id % 5 AS base
) b
CROSS JOIN (VALUES ('General', 1.0, 500), ('VIP', 2.5, 80), ('Student', 0.6, 150)) AS t(type_name, mult, cap)
WHERE t.type_name <> 'Student' OR e.category IN ('Conference', 'Theatre', 'Arts', 'Film');

-- 3) Attendees: 120 generated people (city is sometimes missing on purpose)
INSERT INTO attendee (first_name, last_name, email, phone, city, marketing_opt_in, created_at)
SELECT fn, ln,
       lower(replace(fn || '.' || ln, ' ', '')) || i || '@example.com',
       '+973 3' || lpad(floor(random() * 9999999)::int::text, 7, '0'),
       city, random() < 0.4,
       TIMESTAMP '2024-06-01' + random() * INTERVAL '500 days'
FROM (
    SELECT i,
           (ARRAY['Ahmed','Fatima','Mohammed','Maryam','Ali','Zainab','Hassan','Noor','Yousif','Sara',
                  'Khalid','Aisha','Omar','Layla','Hamad','Huda','Abdulla','Reem','Jassim','Dana'])[1 + floor(random() * 20)::int] AS fn,
           (ARRAY['Al Hashimi','Hasan','Al Mahmood','Juma','Al Sayed','Ebrahim','Al Doseri','Mansoor',
                  'Al Ansari','Salman','Al Noaimi','Abdulla','Al Ghanim','Rashid','Isa'])[1 + floor(random() * 15)::int] AS ln,
           (ARRAY['Manama','Riffa','Muharraq','Isa Town','Hamad Town','Sitra','Budaiya',NULL])[1 + floor(random() * 8)::int] AS city
    FROM generate_series(1, 120) AS i
) x;

-- 4) Orders: 450 random orders, placed 1-45 days before the event (never after today)
WITH a AS (SELECT array_agg(attendee_id) AS ids FROM attendee),
     t AS (SELECT array_agg(ticket_type_id) AS ids FROM ticket_type)
INSERT INTO order_header (attendee_id, ticket_type_id, quantity, order_date, payment_method, box_office_terminal_id, payment_reference)
SELECT x.attendee_id, x.ticket_type_id, x.qty,
       LEAST(e.event_date - (1 + floor(x.r * 45))::int + INTERVAL '8 hours' + random() * INTERVAL '12 hours',
             TIMESTAMP '2026-11-18 12:00'),
       (ARRAY['Card','Cash','BenefitPay'])[1 + floor(random() * 3)::int],
       'BOX-' || (1 + floor(random() * 6))::int,
       'PAY-' || substr(md5(random()::text), 1, 12)
FROM (
    SELECT a.ids[1 + floor(random() * array_length(a.ids, 1))::int] AS attendee_id,
           t.ids[1 + floor(random() * array_length(t.ids, 1))::int] AS ticket_type_id,
           1 + floor(random() * 4)::int AS qty,
           random() AS r
    FROM generate_series(1, 450), a, t
) x
JOIN ticket_type tt ON tt.ticket_type_id = x.ticket_type_id
JOIN event e        ON e.event_id = tt.event_id;

-- Check: row counts per table
SELECT 'event' AS table_name, COUNT(*) FROM event
UNION ALL SELECT 'ticket_type', COUNT(*) FROM ticket_type
UNION ALL SELECT 'attendee', COUNT(*) FROM attendee
UNION ALL SELECT 'order_header', COUNT(*) FROM order_header;
