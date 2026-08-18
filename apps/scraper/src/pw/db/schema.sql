-- Property Agent Workspace -- V1 schema
--
-- Two halves:
--   the book  : contacts, properties under mandate, relationships, interactions
--   the feed  : scraped market listings (properties with acquisition='scraped')
--
-- Conventions:
--   * timestamps are TEXT, ISO-8601, ALWAYS UTC. Render in local time at the edge.
--   * phone numbers are stored NORMALISED (digits only, country code, no '+'):
--     "012-345 6789" -> "60123456789". Normalisation happens in Python before insert;
--     the UNIQUE constraint here is what makes dedup reliable.

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------- contacts --
-- One row per person. A landlord on one deal is a buyer on the next, so role
-- deliberately does NOT live here; it lives on contact_properties.
CREATE TABLE IF NOT EXISTS contacts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT,                        -- nullable: scraped listings often have only a phone
  phone         TEXT UNIQUE,                 -- normalised; the dedup key
  email         TEXT,
  company       TEXT,                        -- agency, for co-agents
  ren_number    TEXT,                        -- MY agent registration (REN/E number)
  notes         TEXT,
  source        TEXT NOT NULL DEFAULT 'manual'
                CHECK (source IN ('manual','scraped','referral','import')),
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_contacts_phone  ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_source ON contacts(source);
CREATE INDEX IF NOT EXISTS idx_contacts_name   ON contacts(name);

-- -------------------------------------------------------------- properties --
-- One row per real unit, whether it came from a portal or from your own mandate.
-- `acquisition` keeps 10 real mandates from drowning in 5,000 scraped rows.
CREATE TABLE IF NOT EXISTS properties (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  acquisition    TEXT NOT NULL DEFAULT 'scraped'
                 CHECK (acquisition IN ('own_mandate','scraped')),
  listing_type   TEXT NOT NULL DEFAULT 'rent'
                 CHECK (listing_type IN ('rent','sale')),
  title          TEXT,
  property_type  TEXT,                       -- Condominium, Terrace, Apartment, ...
  price          REAL,
  price_per_sqft REAL,
  size_sqft      REAL,
  bedrooms       INTEGER,
  bathrooms      INTEGER,
  car_parks      INTEGER,
  floor          INTEGER,                    -- NB: old schema said `floors`, code wrote `floor`
  furnishing     TEXT,
  tenure         TEXT,
  facilities     TEXT CHECK (facilities IS NULL OR json_valid(facilities)),
  full_address   TEXT,
  area           TEXT,
  latitude       REAL,
  longitude      REAL,
  status         TEXT NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active','under_offer','closed','withdrawn','expired')),
  scam_score     INTEGER,                    -- 0-100, populated in V2
  summary        TEXT,
  first_seen_at  TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at   TEXT NOT NULL DEFAULT (datetime('now')),
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_properties_acq    ON properties(acquisition, status);
CREATE INDEX IF NOT EXISTS idx_properties_area   ON properties(area);
CREATE INDEX IF NOT EXISTS idx_properties_price  ON properties(listing_type, price);
CREATE INDEX IF NOT EXISTS idx_properties_seen   ON properties(last_seen_at);
-- dedup candidate lookup: narrow by area+beds before doing fuzzy work in Python
CREATE INDEX IF NOT EXISTS idx_properties_dedup  ON properties(area, bedrooms, size_sqft);

-- --------------------------------------------------------- property_sources --
-- One row per portal appearance. A unit cross-listed on mudah + PropertyGuru has
-- two rows here and ONE row in properties. This is what makes cross-portal dedup
-- and price history possible.
CREATE TABLE IF NOT EXISTS property_sources (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id       INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  website           TEXT NOT NULL,           -- mudah | propertyguru | iproperty | edgeprop
  advertisement_id  TEXT NOT NULL,
  listing_url       TEXT,
  listed_at         TEXT,                    -- portal's own posting date, if given
  price_at_scrape   REAL,
  first_seen_at     TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (website, advertisement_id)         -- the exact-match dedup key
);
CREATE INDEX IF NOT EXISTS idx_sources_property ON property_sources(property_id);

-- ------------------------------------------------------- contact_properties --
-- THE "owner <-> property they want to rent/sell" table.
-- Role lives on the relationship because the same person plays different roles.
CREATE TABLE IF NOT EXISTS contact_properties (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id   INTEGER NOT NULL REFERENCES contacts(id)   ON DELETE CASCADE,
  property_id  INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  role         TEXT NOT NULL
               CHECK (role IN ('owner','interested_buyer','interested_tenant',
                               'current_tenant','co_agent','listing_agent')),
  notes        TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (contact_id, property_id, role)
);
CREATE INDEX IF NOT EXISTS idx_cp_contact  ON contact_properties(contact_id);
CREATE INDEX IF NOT EXISTS idx_cp_property ON contact_properties(property_id);

-- ------------------------------------------------------------ interactions --
-- Every touch. `direction` is what powers the follow-up inbox:
--   inbound  = they contacted you
--   outbound = you contacted them
CREATE TABLE IF NOT EXISTS interactions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id   INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  property_id  INTEGER REFERENCES properties(id) ON DELETE SET NULL,
  channel      TEXT NOT NULL
               CHECK (channel IN ('whatsapp','call','sms','email','in_person','viewing','other')),
  direction    TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
  occurred_at  TEXT NOT NULL DEFAULT (datetime('now')),
  summary      TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_interactions_contact  ON interactions(contact_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_property ON interactions(property_id);

-- ----------------------------------------------------------- price_history --
-- Unused until V2 (price-drop alerts) but seeded from V1 day one: cheap now,
-- impossible to backfill later.
CREATE TABLE IF NOT EXISTS price_history (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  property_id  INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  price        REAL NOT NULL,
  observed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  website      TEXT
);
CREATE INDEX IF NOT EXISTS idx_price_history ON price_history(property_id, observed_at DESC);

-- ------------------------------------------------------------- scrape_runs --
CREATE TABLE IF NOT EXISTS scrape_runs (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  website        TEXT NOT NULL,
  started_at     TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at    TEXT,
  status         TEXT NOT NULL DEFAULT 'running'
                 CHECK (status IN ('running','ok','partial','failed')),
  pages_fetched  INTEGER NOT NULL DEFAULT 0,
  listings_found INTEGER NOT NULL DEFAULT 0,
  new_count      INTEGER NOT NULL DEFAULT 0,
  duplicate_count INTEGER NOT NULL DEFAULT 0,
  error_count    INTEGER NOT NULL DEFAULT 0,
  notes          TEXT
);
CREATE INDEX IF NOT EXISTS idx_scrape_runs ON scrape_runs(website, started_at DESC);

-- ------------------------------------------------------- follow-up inbox ----
-- The two alerts, from one view:
--   owed_reply     -> they messaged last; YOU have not replied. Ordered by staleness.
--   awaiting_them  -> you messaged last; THEY have gone quiet.
--   never_contacted-> a contact with no interactions at all.
-- `stale_hours` is how long the ball has been in that court.
CREATE VIEW IF NOT EXISTS follow_up_inbox AS
WITH latest AS (
  SELECT
    contact_id,
    MAX(CASE WHEN direction = 'inbound'  THEN occurred_at END) AS last_inbound_at,
    MAX(CASE WHEN direction = 'outbound' THEN occurred_at END) AS last_outbound_at
  FROM interactions
  GROUP BY contact_id
)
SELECT
  c.id            AS contact_id,
  c.name,
  c.phone,
  c.source,
  l.last_inbound_at,
  l.last_outbound_at,
  CASE
    WHEN l.contact_id IS NULL                              THEN 'never_contacted'
    WHEN l.last_inbound_at IS NOT NULL
     AND (l.last_outbound_at IS NULL
          OR l.last_inbound_at > l.last_outbound_at)       THEN 'owed_reply'
    ELSE 'awaiting_them'
  END AS bucket,
  CAST((julianday('now') - julianday(
         COALESCE(MAX(l.last_inbound_at, l.last_outbound_at),
                  l.last_inbound_at, l.last_outbound_at)
       )) * 24 AS INTEGER) AS stale_hours
FROM contacts c
LEFT JOIN latest l ON l.contact_id = c.id;
