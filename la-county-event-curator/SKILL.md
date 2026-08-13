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
3. Cover multiple parts of the county rather than treating the City of Los Angeles as the whole county. Include events from other communities when strong matches exist.
4. Favor organizer, venue, museum, university, government, and official ticketing pages over aggregators.
5. Use aggregators for discovery, but find an official event page before recommending the event whenever possible.

Vary queries by interest, date, venue type, and geography. Do not assume the first search results represent the county's best events.

## Verify each event

Open the event page and verify:

- event title
- date and start time, or the date range for an exhibition or festival
- venue and city/community
- that the venue is within Los Angeles County
- price or registration status when published
- that the event is publicly attendable; exclude member-only, invite-only, and private events unless the user asks for them
- a direct, working source URL

Use current web research for every briefing. Never invent missing details or rely solely on a search-result snippet. Label genuinely unavailable information as â€œNot listed.â€ Note sold-out events, waitlists, age restrictions, eligibility restrictions, or registration deadlines when found.

## Rank and select

Score candidates using these priorities:

1. Match to the interests in the curation profile
2. Evidence that the event offers a distinctive experience, useful learning, or notable programming
3. Source confidence and completeness of practical details
4. Preferred-source status
5. Geographic and topical variety across the final list

Deduplicate listings for the same event. Avoid filling the briefing with many similar events from one venue or one category. Select 10â€“15 strong events; return fewer and say so if the available evidence does not support 10.

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

End with a short **Worth noting** section only when usefulâ€”for example, an event with an unannounced schedule, a deadline just outside the date window, or a high-interest event that is already sold out.

## Update preferences or sources

When the user asks to change interests, exclusions, or preferred websites, update [la-county-event-curator/curation-profile.md](la-county-event-curator/curation-profile.md). Preserve existing preferences unless the user explicitly replaces them. Normalize website entries to a recognizable organization name and canonical homepage or events-page URL.
