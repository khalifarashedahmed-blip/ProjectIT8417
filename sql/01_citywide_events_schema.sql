-- Schema 1: citywide_events  (normalised operational design)
-- Price lives only on ticket_type; an order points to a ticket_type and looks the price up.

CREATE SCHEMA IF NOT EXISTS citywide_events;
SET search_path TO citywide_events;

CREATE TABLE attendee (
    attendee_id      SERIAL PRIMARY KEY,
    first_name       VARCHAR(50)  NOT NULL,
    last_name        VARCHAR(50)  NOT NULL,
    email            VARCHAR(120) NOT NULL UNIQUE,
    phone            VARCHAR(20),                  -- not needed downstream (dropped in ETL)
    city             VARCHAR(50),
    marketing_opt_in BOOLEAN DEFAULT FALSE,        -- not needed downstream (dropped in ETL)
    created_at       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE event (
    event_id       SERIAL PRIMARY KEY,
    event_name     VARCHAR(120) NOT NULL,
    category       VARCHAR(40)  NOT NULL,          -- Music, Comedy, Sports, Theatre, ...
    description    TEXT         NOT NULL,          -- embedded later for pgvector search
    venue_name     VARCHAR(80)  NOT NULL,
    city           VARCHAR(50)  NOT NULL,
    event_date     DATE         NOT NULL,
    poster_url     VARCHAR(255),                   -- not needed downstream (dropped in ETL)
    internal_notes TEXT                            -- not needed downstream (dropped in ETL)
);

CREATE TABLE ticket_type (
    ticket_type_id      SERIAL PRIMARY KEY,
    event_id            INT          NOT NULL REFERENCES event(event_id) ON DELETE CASCADE,
    type_name           VARCHAR(30)  NOT NULL,     -- General, VIP, Student
    price               NUMERIC(8,2) NOT NULL CHECK (price >= 0),
    capacity            INT          NOT NULL CHECK (capacity > 0),
    print_template_code VARCHAR(20),               -- not needed downstream (dropped in ETL)
    sales_rep_code      VARCHAR(20),               -- not needed downstream (dropped in ETL)
    UNIQUE (event_id, type_name)
);

CREATE TABLE order_header (
    order_id               SERIAL PRIMARY KEY,
    attendee_id            INT       NOT NULL REFERENCES attendee(attendee_id),
    ticket_type_id         INT       NOT NULL REFERENCES ticket_type(ticket_type_id),
    quantity               INT       NOT NULL CHECK (quantity > 0),
    order_date             TIMESTAMP NOT NULL DEFAULT NOW(),
    payment_method         VARCHAR(20),            -- Card, Cash, BenefitPay
    box_office_terminal_id VARCHAR(20),            -- not needed downstream (dropped in ETL)
    payment_reference      VARCHAR(40)             -- not needed downstream (dropped in ETL)
);
