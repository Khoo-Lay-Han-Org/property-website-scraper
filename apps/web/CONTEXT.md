# Workspace

The working tool for one Malaysian property agent. It holds two halves that share a
vocabulary but not a purpose: **the book**, which is the agent's own relationships and
mandates, and **the feed**, which is everything scraped from the portals.

## The two halves

**The Book**:
Everything the agent owns and is accountable for — their contacts, their own mandates, their deals, their follow-ups. The irreplaceable half.
_Avoid_: CRM, my listings

**The Feed**:
The scraped inventory the agent browses and prospects from. Replaceable by definition — it can be re-scraped.
_Avoid_: the scrape, search results

**Acquisition**:
How a Property came to be known to us — won as the agent's own mandate, or observed on a portal. The single attribute that separates the book from the feed.
_Avoid_: origin, type, ownership

## Properties and advertisements

**Property**:
One real-world unit. A unit cross-listed on three portals is still one Property.
_Avoid_: listing, unit, house, asset

**Advertisement**:
One appearance of a Property on one Portal. Cross-listing produces several Advertisements for one Property; this is what makes cross-portal deduplication possible at all.
_Avoid_: listing, source, ad post, property source

**Portal**:
A third-party property marketplace the feed is scraped from — mudah, PropertyGuru, iProperty, EdgeProp.
_Avoid_: website, site, source

**Location**:
A named place in the Malaysian administrative hierarchy — state, district, mukim, township. A Property sits in exactly one, and every Location knows its parent. Replaces free text so that two spellings of the same place stop being two places.
_Avoid_: area, region, locality, address

**Project**:
A named development a Property belongs to — a condominium, a serviced apartment block, or a landed scheme. Not every Property has one; a shoplot or an individual bungalow may stand alone.
_Avoid_: development, building, block, scheme, taman

**Mandate**:
The agent's right to market a Property, granted by an owner. Exclusive or open, with an appointment date, an expiry and an agreed commission rate. A Property acquired as an own mandate has one; a scraped Property does not. Distinct from a Deal — one Mandate can produce several transaction attempts, and a Mandate that expires unsold produced none.
_Avoid_: listing agreement, instruction, appointment, authority

**Price History**:
The record of what a Property was quoted at over time, and by which Advertisement. Cannot be backfilled, so it is recorded from the first day even before anything reads it.
_Avoid_: price log, price changes

> Note on the word **listing**. It is never a noun for a record. It survives only as a qualifier meaning *how a unit is being marketed* — a Property's listing type (rent or sale) and its listing status. Anything that could be called "a listing" is either a Property or an Advertisement, and the distinction always matters.

## People

**Contact**:
One human being, whoever they are to the agent this week. A landlord on one deal is a buyer on the next, so what someone *is* to us never lives on the Contact.
_Avoid_: person, lead, client, customer, account

**Contact Identifier**:
A phone number, email, WhatsApp id or agent registration number that identifies a Contact. A Contact may have several, and identity lives here rather than on the Contact itself.
_Avoid_: phone, contact detail

**Property Role**:
What a Contact is to a Property as a standing fact — owner, co-agent, listing agent. A fact about the unit, not about any transaction. Occupancy is not one of these: that is a Tenancy, because it ends.
_Avoid_: relationship, link, association

**Deal Role**:
What a Contact is to one Deal — buyer, tenant, vendor, landlord, co-agent, lawyer, banker. Distinct from Property Role, because being interested in a unit is a fact about a transaction attempt, not about the unit.
_Avoid_: party type, role

## Work

**Deal**:
One transaction attempt on one Property. A unit that fails to sell and is relisted is a second Deal. Commission lives here, and commission is why the agent opens the application.
_Avoid_: case, transaction, opportunity, pipeline

**Tenancy**:
An occupancy of a Property by a Contact for a term — start, end, rent and deposit. Created by a Deal that completed, but outlives it: the Deal is the transaction attempt, the Tenancy is what the attempt produced.
_Avoid_: lease, rental, agreement, contract

**Stage**:
Where a Deal has reached, from first lead through to completed or lost. Owned by the agent, never by a machine.
_Avoid_: status, state

**Listing Status**:
Whether a Property is still being marketed — active, expired or withdrawn. Owned by the expiry sweep and the owner's decision, never by the agent's deal progress.
_Avoid_: status, state

**Interaction**:
One touch between the agent and a Contact that has already happened — a call, a WhatsApp exchange, a viewing. Append-only: interactions are corrected by adding, never by editing.
_Avoid_: activity, log entry, touchpoint, communication

**Appointment**:
One scheduled event with a time and attendees — a viewing, a key handover, a signing. When it happens, it becomes an Interaction. Past and future stay separate so Interaction can remain honestly append-only.
_Avoid_: event, booking, meeting, viewing

**Task**:
A to-do the agent wrote down explicitly. Always created by a human.
_Avoid_: todo, reminder, follow-up

**Follow-up**:
A Contact or Deal that has gone quiet and is surfaced by asking, never by storing. Derived state only — a Follow-up is a query result, never a record.
_Avoid_: reminder, task, chase

## Matching

**Requirement**:
What a Contact is looking for — area, budget, size, type. The buyer-side brief.
_Avoid_: search, criteria, buyer profile, wishlist

**Match**:
A Property put in front of a Requirement, and what came of it. Recorded so the same Contact is never sent the same Property twice.
_Avoid_: recommendation, suggestion, hit
