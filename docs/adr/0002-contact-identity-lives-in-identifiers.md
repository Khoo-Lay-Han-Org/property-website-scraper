# Contact identity lives in identifiers, not on the Contact

A Contact was originally keyed on a single unique phone number. That makes identity a
single mutable, nullable attribute, and it fails three ways in practice: one agent carrying
a personal and an agency number becomes two Contacts with their history split silently
across both; a recycled Malaysian prepaid number silently merges two unrelated people into
one; and a contact with only an email has no dedup key at all, because nulls are distinct in
a unique index. Identity therefore moves to Contact Identifier rows — phone, email, WhatsApp
id, agent registration number — with the Contact itself holding no identifying attribute.

## Consequences

Lookup cost is unchanged: one probe on a unique index, just a different one. The real gain is
that two rows later discovered to be one person can be merged by repointing identifier rows
rather than by choosing which history to destroy.

**This decision cannot be deferred cheaply.** Any pair of Contacts already split under the old
key cannot be rejoined automatically — nothing in the data records that they were the same
human. That knowledge exists only in the agent's head, and only for as long as they remember.

See `docs/database/08-review-v1.1.md` §22.2.
