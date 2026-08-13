---
name: la-county-event-curator
description: Discover, verify, rank, and summarize upcoming events throughout Los Angeles County, California. Use when the user asks for an LA County event roundup, a next-month event briefing, or recommendations involving museums, exhibitions, science, festivals, talks, lectures, workshops, or theater. Search preferred websites first, then broaden to trustworthy public event sources, and provide direct source links.
---

# LA County Event Curator

Create a selective, accurate briefing of Los Angeles County events that match the user's interests. Prefer quality and relevance over filling a quota.

## Load the curation profile

Read [la-county-event-curator/curation-profile.md](la-county-event-curator/curation-profile.md) before searching. Treat it as the default profile unless the user's current request overrides it.

## Set the search window

- Default to the next calendar month in `America/Los_Angeles`.
- State the exact inclusive date range near the beginning of the briefing.
- Honor a different date range when the user supplies one.
- Include multi-day events when at least one public occurrence falls inside the range. Clearly show the relevant dates.

## Discover candidates

1. Search every website under **Preferred sources** in the curation profile first. Search the site itself when practical; otherwise use targeted web queries restricted to its domain.
2. Broaden the search across trustworthy public sources to avoid missing events elsewhere in Los Angeles County.
3. Build a substantially larger candidate pool than the requested final digest. For a digest of 10–20 events, attempt to identify at least 40–60 plausible candidates before ranking.
4. Favor organizer, venue, museum, university, government, and official ticketing pages over aggregators.
5. Use aggregators for discovery, but find an official event page before recommending the event whenever possible.

Vary queries by interest, date, venue type, and geography. Do not assume the first search results represent the county's best events.

Search across multiple categories:

- Science, technology, engineering, and astronomy
- Nature, hiking, gardens, and outdoor activities
- Museums, art, and exhibitions
- Live music
- Theater, film, dance, and performing arts
- Lectures, talks, and educational events
- Food and culinary events
- Festivals and community events
- History and cultural events
- Unusual, experimental, or one-time experiences

## Fill discovery gaps

After initial discovery, classify candidates by category and identify categories that are missing or poorly represented. Perform additional targeted searches for those categories before selecting the final recommendations.

For example, if the pool contains many concerts but few science events, explicitly search universities, observatories, science museums, research institutions, and science organizations for public events. Do not assume the initial results adequately represent what is happening across the county.

## Enforce source and geographic diversity

Search multiple independent sources. Unless an exceptional event justifies an exception:

- Include no more than 2 events from the same venue.
- Include no more than 3 events discovered from the same source website.

Treat these as guidelines rather than absolute restrictions. Search throughout Los Angeles County and look for worthwhile events in multiple regions, including:

- San Gabriel Valley
- Central Los Angeles
- Northeast Los Angeles
- San Fernando Valley
- Westside
- South Bay
- Long Beach
- Southeast Los Angeles County
- Antelope Valley

Do not sacrifice event quality merely to satisfy geographic diversity. Avoid concentrating the digest in one neighborhood or region merely because its calendars are easier to search.

## Verify each event

Open the event page and verify:

- event title
- date and start time, or the date range for an exhibition or festival
- venue and city/community
- that the venue is within Los Angeles County
- price or registration status when published
- that the event is publicly attendable; exclude member-only, invite-only, and private events unless the user asks for them
- a direct, working source URL

Use current web research for every briefing. Never invent missing details or rely solely on a search-result snippet. Label genuinely unavailable information as “Not listed.” Note sold-out events, waitlists, age restrictions, eligibility restrictions, or registration deadlines when found.

## Rank and select

Only rank events after completing the diversity and gap-search process. For a typical 15-event digest, aim for a mixture roughly resembling:

- 2–4 science, technology, or astronomy events
- 2–4 outdoor or nature events
- 2–3 museum, art, or exhibition events
- 2–3 music or performing arts events
- 1–3 food, festival, or community events
- 1–3 lectures, talks, or educational events
- 1–2 wildcard recommendations

Allow events to belong to multiple categories. Treat these ranges as targets rather than quotas; never include a mediocre event solely to fill a category.

Reserve at least one recommendation for an event that is unusual, surprising, highly local, experimental, or difficult to categorize. Use the wildcard to surface an opportunity the user would be unlikely to discover through an ordinary event search.

Optimize the final selection in this order:

1. Match to the interests in the curation profile
2. Uniqueness or rarity
3. Quality of the event
4. Limited-time opportunity
5. Diversity relative to the other selected events
6. Geographic accessibility
7. Reliability of the source information

Use preferred-source status as a positive signal without allowing it to override relevance, quality, or diversity.

Deduplicate listings for the same event. Select 25–30 strong events; return fewer and say so if the available evidence does not support 10. The goal is not a representative sample of every event in Los Angeles County, but a diverse collection of unusually worthwhile events that the user is likely to find interesting.

## Write the briefing

Begin with a short orientation and the exact date range. Group events by their strongest interest category, using only categories represented in the results.

For each event, provide:

- **Event title**
- Date and time
- Venue and city/community
- Price or registration status
- A concise explanation of why it matches the profile
- A direct link to the best available event page

Keep entries easy to scan and avoid promotional language. If dates, prices, or schedules may change, advise the user to confirm them before traveling or purchasing tickets.

End with a short **Worth noting** section only when useful—for example, an event with an unannounced schedule, a deadline just outside the date window, or a high-interest event that is already sold out.

## Update preferences or sources

When the user asks to change interests, exclusions, or preferred websites, update [references/curation-profile.md](references/curation-profile.md). Preserve existing preferences unless the user explicitly replaces them. Normalize website entries to a recognizable organization name and canonical homepage or events-page URL.
