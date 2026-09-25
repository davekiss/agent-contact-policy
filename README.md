# Agent Contact Policy

An Internet-Draft for letting a business tell AI agents where to reach it,
and letting agents say they're agents, without anyone guessing from the
content of a message.

- **Read it:** [text](draft-kiss-agent-contact-policy.txt) ·
  [HTML](https://htmlpreview.github.io/?https://github.com/davekiss/agent-contact-policy/blob/main/draft-kiss-agent-contact-policy.html) ·
  [source](draft-kiss-agent-contact-policy.md)
- **Status:** individual draft, not yet submitted to the IETF. Feedback wanted.

## What it defines

1. **Agent Contact Policy.** A small JSON document at
   `/.well-known/agent-contact-policy` (also linkable, and carriable in
   DNS-AID) that marks a business's phone numbers, email addresses and forms
   as meant for people, and names the contact points meant for agents: an
   agent email address, an agent phone number, an A2A Agent Card or an MCP
   endpoint.
2. **`Auto-Submitted: agent-submitted; agent=<platform>`.** A label on email
   an agent composes, verified by an aligned DKIM signature: the agent
   platform's own when the agent has its own mailbox, or the mailbox
   provider's (`by=`) when the agent sends from its person's mailbox.
3. **`Agent-Reroute`.** A header a business puts in its reply when an agent
   skipped the policy, plus the conditions under which an agent platform may
   act on it. Agents never reroute without their person's approval or a
   standing permission they granted.

## Why

Personal agents (Grok Bot, Meta's Muse, Instinct) already email and call
small businesses for their users, on channels staffed by people. They write
as their person, so the business can't tell them apart, and they're rightly
built to ignore instructions they find in content. The draft's appendix
summarizes an experiment with all three agents; the write-up is
[I opened a fake auto shop for AI agents](https://davekiss.com/blog/i-opened-a-fake-auto-shop-for-ai-agents/).

## Build

```sh
gem install kramdown-rfc
pipx install xml2rfc
make
```

## Contributing

Issues and pull requests are welcome. Discussion of this draft is an IETF
Contribution under the [IETF Note Well](https://www.ietf.org/about/note-well/)
(BCP 78 and BCP 79).
