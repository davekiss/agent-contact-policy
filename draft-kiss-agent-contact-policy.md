---
title: "Agent Contact Policy: Routing Automated Agents to Designated Contact Points"
abbrev: "Agent Contact Policy"
category: exp
docname: draft-kiss-agent-contact-policy-latest
submissiontype: IETF
number:
date:
v: 3
area: "Applications and Real-Time"
keyword:
 - AI agents
 - email
 - Auto-Submitted
 - contact routing
 - redirect
venue:
  github: "davekiss/agent-contact-policy"
author:
 -
    fullname: Dave Kiss
    organization: Independent
    email: dave@davekiss.com

normative:
  RFC3339:
  RFC3834:
  RFC3864:
  RFC3986:
  RFC5234:
  RFC5322:
  RFC6068:
  RFC6376:
  RFC8259:
  RFC8288:
  RFC8615:
  RFC9110:
  RFC9111:
  RFC9989:

informative:
  RFC3261:
  RFC4086:
  RFC5321:
  RFC5436:
  RFC7942:
  RFC9057:
  RFC9421:
  I-D.ietf-dkim-dkim2-spec:
  I-D.mozleywilliams-dnsop-dnsaid:
  I-D.nemethi-dawn-aid:
  I-D.ietf-webbotauth-httpsig-protocol:
  I-D.zhao-a2a-webfinger:
    title: "A WebFinger Profile for Agent2Agent (A2A) Agent Identity Resolution"
    author:
      - ins: C. Zhao
    date: 2026-08-19
    seriesinfo:
      Internet-Draft: draft-zhao-a2a-webfinger-00
    target: https://datatracker.ietf.org/doc/html/draft-zhao-a2a-webfinger-00
  A2A:
    title: "Agent2Agent (A2A) Protocol: Agent Discovery"
    target: https://a2a-protocol.org/latest/topics/agent-discovery/
  SCHEMA-CONTACTPOINT:
    title: "schema.org ContactPoint"
    target: https://schema.org/ContactPoint

--- abstract

Software agents acting on behalf of people ("AI agents") increasingly send
email to, and place calls with, small organizations whose contact points are
staffed by people. The organizations cannot reliably tell these agents apart
from the people they act for, and the agents cannot tell which contact point
the organization would prefer them to use. This document defines three
mechanisms that let the two sides cooperate without inspecting message
content: an Agent Contact Policy that an organization publishes to name the
contact points meant for agents; an Auto-Submitted keyword with which email
composed by an agent is labelled as such, verifiably; and an Agent-Reroute
header field with which an organization, replying in a thread, points an
agent to its agent contact point. The trust model throughout is that whoever
controls a contact address decides where agents should go, and an agent
follows such a direction only with its principal's consent.

--- middle

# Introduction

Personal agents now contact organizations for the people who use them: they
send email asking about services and prices, request quotes, book
appointments and, increasingly, place phone calls. Most small organizations
publish a single email address and phone number, answered by people. Agent
traffic arriving on those channels competes with customers for the same
staff.

Two facts make this hard to address with existing tools. First, agents
often send from their principal's own mailbox and write in their
principal's voice, so the messages are indistinguishable from the principal's
own. In the experiment summarized in {{experiment}}, an agent's message was
scored 0.16 (on a 0 to 1 scale) by a text classifier asked whether it was
machine-written; the only trace of automation in its header fields was that
it had been sent through the mailbox provider's API, as many ordinary email
applications also do. Inferring agent origin from content
is unreliable and, when wrong, penalizes a person. This document does not
rely on it.

Second, agents are rightly designed not to act on instructions found in the
content they read. A message saying "send this somewhere else instead" is
indistinguishable from a phishing or prompt-injection attempt, and every agent
tested treated such text as information for its principal, not as an
instruction to follow. Any mechanism that routes agents must therefore be
declared by a party the agent can verify, and must leave the decision to act
with the agent's principal or with a permission the principal granted in
advance.

This document defines:

1. An **Agent Contact Policy** ({{policy}}): a small JSON document, published
   by the controller of a contact address, that marks contact points as
   intended for people and names the contact points intended for agents.
2. The **agent-submitted keyword** for the Auto-Submitted header field
   ({{identify}}), with which email composed by an agent is labelled, and a
   way to verify the label whether the agent sends from its own domain or
   from its principal's mailbox.
3. The **Agent-Reroute header field** ({{reroute}}), which an organization
   includes in a reply to direct an agent that skipped the policy to the
   organization's agent contact point, together with the conditions under
   which an agent may act on it.

The three mechanisms are independent: each is useful without the others, and
they touch different communities (web publication and discovery; email
labelling; email replies). They are presented together here because they
were designed and tested together. The author expects that they may be split
into separate documents if the work is taken up.

## Goals and Non-Goals

The goals are to let an organization keep its human contact points for people
while still serving agents quickly; to let agents find and verify the
organization's preferred channel; and to leave every decision to contact a
new recipient with the agent's principal.

It is not a goal to block agents. The person behind an agent is usually a
genuine customer. It is also not a goal to detect agents from the content or
style of their messages; nothing in this document depends on such detection.

This document covers email in detail. The Agent Contact Policy also lists
telephone and protocol endpoints ({{phone}}); a mechanism comparable to
Agent-Reroute for voice calls is left for future work.

## Requirements Language

{::boilerplate bcp14-tagged}

## Terminology

Agent:
: Software that contacts an organization on behalf of a person.

Principal:
: The person on whose behalf an Agent acts.

Agent Platform:
: The operator of an Agent and of the software (for example, an email tool)
  the Agent uses to send and read messages. Processing rules in this document
  are addressed to the Agent Platform's software, not to a language model's
  judgment.

Mailbox Provider:
: The operator of a mailbox that an Agent Platform uses, on a Principal's
  authorization, to send mail as that Principal (for example, through an
  API).

Organization:
: The recipient of an Agent's contact, such as a business.

Human Contact Point:
: A contact point (email address, telephone number, web form) that the
  Organization intends for people.

Agent Contact Point:
: A contact point that the Organization intends for Agents. It is typically
  answered automatically from information the Organization has published,
  with anything it cannot answer passed to staff.

Reroute:
: An Agent's resending of a request, originally sent to a Human Contact Point,
  to an Agent Contact Point.

Reference:
: An unguessable token the Organization assigns to a request received on a
  Human Contact Point so that a Reroute can be correlated with it.

The ABNF in this document uses the notation of {{RFC5234}}.

# Overview and Trust Model

The three mechanisms apply at different moments:

- **Before contact**, an Agent looks up the Agent Contact Policy for the
  address it intends to use and, if the address is a Human Contact Point,
  offers its Principal the Agent Contact Point instead ({{policy}}).
- **At contact**, an Agent labels its email as agent-sent ({{identify}}). An
  Organization receiving mail with a verified label can route it to its Agent
  Contact Point with certainty.
- **After contact**, if an unlabelled request reached a Human Contact Point,
  the Organization replies once, in the thread, with an Agent-Reroute field
  ({{reroute}}); the Agent's Platform verifies it and offers the Reroute to
  its Principal.

The trust model is the one already used for delegating mail handling across
domains (MX records, SPF, DMARC reporting): the party that controls an address
may say where traffic for it should go, and that statement is trusted because
only that party can make it.

For an address at a domain the Organization controls, the statement is a
policy published under that domain, and an Agent can verify it before any
contact.

For an address at a shared Mailbox Provider (for example, an address at a
consumer webmail domain), the Organization cannot publish under the domain.
Two weaker forms of evidence remain. The Organization's own website can list
the address together with a policy; this binds the address to the policy only
as strongly as the website is bound to the Organization. Failing that, the
only evidence is an authenticated reply from the address itself
({{reroute}}). Such a reply proves that whoever controls the mailbox chose
the destination, which is the party the Agent was trying to reach in the
first place; it proves nothing about who that party is. Agent Platforms
SHOULD present these cases to the Principal accordingly.

The destination's domain does not matter; its verifiability does. An Agent
Contact Point is commonly operated by a service provider on a different
domain, just as mail for a domain is commonly handled by a provider on
another.

# Agent Contact Policy {#policy}

## Document Format

An Agent Contact Policy is a JSON {{RFC8259}} object with the following
members:

version:
: REQUIRED. The integer 1.

organization:
: OPTIONAL. A human-readable name for the Organization.

human_contacts:
: REQUIRED. An array of URIs {{RFC3986}} identifying Human Contact Points,
  such as "mailto:" {{RFC6068}} and "tel:" URIs and "https:" URIs of web
  forms.

agent_contacts:
: REQUIRED. A non-empty array of Agent Contact Point objects, each with:

  - "uri" (REQUIRED): a "mailto:", "tel:" or "https:" URI;
  - "protocol" (OPTIONAL): how the contact point is used, for example
    "email", "voice", "a2a" for an A2A Agent Card {{A2A}}, or "mcp";
  - "for" (OPTIONAL): an array of URIs from "human_contacts" that this Agent
    Contact Point serves. If absent, it serves all of them.

expires:
: OPTIONAL. A timestamp {{RFC3339}} after which the policy should be
  refetched.

Unknown members MUST be ignored. An Organization with several locations MAY
describe them in one policy, using "for" to pair each location's Human
Contact Points with its Agent Contact Points, or MAY publish one policy per
location website.

~~~ json
{
  "version": 1,
  "organization": "Chippewa Creek Test Garage",
  "human_contacts": [
    "mailto:chippewacreekgarage@gmail.com",
    "tel:+1-440-555-0100"
  ],
  "agent_contacts": [
    { "uri": "mailto:chippewa-creek@line.example",
      "protocol": "email" },
    { "uri": "tel:+1-440-555-0199", "protocol": "voice" },
    { "uri": "https://example.com/.well-known/agent-card.json",
      "protocol": "a2a" }
  ]
}
~~~

## Choosing an Agent Contact Point

To find the Agent Contact Point corresponding to a Human Contact Point, an
Agent considers the entries of "agent_contacts" that serve that Human Contact
Point and prefers, in order: an entry of the same kind as the Human Contact
Point ("mailto:" for "mailto:", "tel:" for "tel:"); an entry whose protocol
the Agent supports; any other entry.

## Retrieval

A policy is retrieved with an HTTP GET over HTTPS {{RFC9110}}; other schemes
MUST NOT be used. Clients MAY follow redirects only to URIs whose host is
within the same Organizational Domain ({{RFC9989}}) as the original request.
A policy is served as "application/json", MUST NOT exceed 65536 octets, and
may be cached according to HTTP caching {{RFC9111}}; the "expires" member,
if present, limits how long a cached copy is used.

## Discovery

An Agent Contact Policy is discovered in one or more of the following ways.

Well-known URI:
: At "/.well-known/agent-contact-policy" {{RFC8615}} under the domain of an
  email address the Organization controls, or under the Organization's website
  origin.

Link relation:
: From an HTML page or HTTP response of the Organization's website, via a link
  with the relation type "agent-contact-policy" {{RFC8288}}. The page on which
  an Agent found a contact address is the natural place for this link.

DNS:
: This document does not define a DNS record. DNS-AID
  {{I-D.mozleywilliams-dnsop-dnsaid}} requests a "policy" SvcParamKey,
  described as the "URI of an associated policy bundle", and defers its
  syntax to a future revision; once specified, it could carry the policy URI
  for Organizations with their own domain. AID {{I-D.nemethi-dawn-aid}} publishes agent endpoints in a TXT
  record at `_agent.<domain>` and could be extended similarly.

Structured data:
: Organizations MAY additionally describe both kinds of contact point with
  schema.org ContactPoint {{SCHEMA-CONTACTPOINT}} markup next to the
  addresses themselves.

## Authority

A policy is authoritative for a contact address only if:

- it was retrieved from the domain of that address; or
- it was retrieved from, or linked from, a website that the Organization
  controls and that lists that address as the Organization's own. Directory
  sites, business listing platforms and search result pages are not such
  websites, even when they display the address; or
- it was linked from an authenticated reply sent from that address, as
  described in {{reroute}}, with the limits stated in the trust model.

## Agent Processing {#agent-processing}

Before sending to a contact address, an Agent Platform SHOULD look up an
Agent Contact Policy for it. If the address is listed in "human_contacts" of
an authoritative policy, the Agent Platform:

- SHOULD offer its Principal the corresponding Agent Contact Point instead,
  stating that the Organization publishes it for agents. This applies even
  when the Principal named the Human Contact Point, since Principals usually
  name the only address they know;
- MAY use the Agent Contact Point without asking if the Principal has granted
  a standing permission to use Organizations' published Agent Contact Points;
- MUST NOT treat the policy as a reason to withhold the Principal's request
  if the Principal insists on the Human Contact Point.

# Identifying Agent-Composed Email {#identify}

## The agent-submitted Keyword

Email composed by an Agent on behalf of a Principal SHOULD carry:

~~~
Auto-Submitted: agent-submitted; agent=agents.example.net
~~~

The "agent-submitted" keyword means that the message was composed by an
Agent acting for a person, and that it is a request that expects an answer.
The "agent" parameter is REQUIRED with this keyword; its value is a domain
name identifying the Agent Platform. A second parameter, "by", is described
in {{by-provider}}. The syntax follows {{RFC3834}}, Section 5.1:

~~~ abnf
agent-param = "agent" "=" domain-name
by-param    = "by" "=" domain-name
domain-name = 1*( ALPHA / DIGIT / "-" / "." )
~~~

A new keyword is used, rather than a parameter on "auto-generated", because
"auto-generated" already denotes notifications and similar mail that expects
no answer, and existing software treats it that way. An agent's request is
the opposite: it expects an answer, but not from an autoresponder. {{RFC3834}}
directs automatic responders not to answer a message with any keyword other
than "no" (Section 2) and lets recipients assume that such a message was not
manually submitted by a human (Section 5.2), so a conforming vacation
responder still stays silent. Some
Agent Platforms label agent mail "auto-generated" today; receivers cannot
distinguish it from notifications, which is the ambiguity this keyword
removes.

## Verifying the Label

A receiver MUST NOT treat an agent-submitted label as verified unless a DKIM
{{RFC6376}} signature on the message validates, lists the Auto-Submitted
field in its signed header fields ("h=" tag), and has a "d=" domain that is
aligned with the domain responsible for the label: the "by" domain if "by" is
present, otherwise the "agent" domain. Alignment here means relaxed alignment
as defined in {{RFC9989}}, Section 3.2.10.1: the two domains have the same
Organizational Domain.

An unverified label is a claim, not an identification. A receiver MAY still
use it to choose how to reply (for example, by stating the Agent Contact
Point in the reply) but MUST NOT use it to withhold the message from staff.

## Agents Sending from Their Own Mailboxes

Some Agent Platforms give each Agent its own mailbox at the Agent Platform's
domain. Such an Agent Platform labels and signs the message itself, with
"agent" set to its own domain, and SHOULD set Reply-To to the Principal's
address when answers should reach the Principal.

## Agents Sending from Their Principal's Mailbox {#by-provider}

Many Agents today send through the Principal's own mailbox,
using an API the Mailbox Provider offers to applications the Principal has
authorized. The Mailbox Provider signs such mail with its own domain, so a
label added by the Agent Platform cannot be verified against the Agent
Platform's domain.

In this case the label can only be verified if the Mailbox Provider asserts
it. A Mailbox Provider that accepts a message from an authorized application
that it knows to be an Agent Platform SHOULD:

- add or replace the Auto-Submitted field with "agent-submitted", an "agent"
  parameter naming the application's registered domain, and a "by"
  parameter naming the Mailbox Provider's own signing domain;
- sign the field with its DKIM signature;
- remove any Auto-Submitted field that names its own domain in "by" when the
  message did not come through such an application, so that a Principal or
  third party cannot forge its assertion.

The Agent Platform SHOULD also add a Sender field {{RFC5322}} naming a
mailbox it controls, preserving the Principal in From. Mail signed by
several parties, as proposed in {{I-D.ietf-dkim-dkim2-spec}}, could let the
Agent Platform add its own verifiable signature to such mail; this document
does not depend on it.

Until Mailbox Providers do this, mail an Agent sends from its Principal's
mailbox carries no verifiable label, and Organizations rely on the Agent
Contact Policy and Agent-Reroute instead.

## Receiver Handling

A message with a verified agent-submitted label is a request that expects an
answer. A receiver MAY route it to an Agent Contact Point and answer it
there, notwithstanding the general guidance in {{RFC3834}}, Section 2, that
automatic responses should not be sent to messages with an Auto-Submitted
value other than "no". To avoid loops, such answers:

- MUST carry "Auto-Submitted: auto-replied";
- MUST be sent at most once per request, and SHOULD be limited per sender
  and thread;
- MUST NOT be sent to a message that itself carries "auto-replied".

# The Agent-Reroute Header Field {#reroute}

## Syntax

~~~ abnf
agent-reroute = "Agent-Reroute:" [CFWS] "<" URI ">"
                *( [CFWS] ";" [CFWS] parameter ) CRLF
~~~

"URI" is as defined in {{RFC3986}} and MUST be a "mailto:" or "https:" URI.
"CFWS" is as defined in {{RFC5322}}, and "parameter" is as in {{RFC3834}},
Section 5.1. Defined parameters:

ref:
: The Reference assigned to the request being rerouted.

expires:
: A timestamp {{RFC3339}} after which the Organization will have delivered
  the request to staff and a Reroute is no longer useful.

References have the following syntax, are compared case-insensitively, and
MUST contain at least 64 bits of randomness generated as described in
{{RFC4086}}:

~~~ abnf
reference = 1*64( ALPHA / DIGIT / "-" )
~~~

Example:

~~~
Agent-Reroute: <mailto:chippewa-creek@line.example>;
  ref="HL-8V2CQ7M3KX9TD"; expires="2026-09-24T18:04:18Z"
~~~

## Organization Behavior

An Organization MAY include Agent-Reroute in a reply to a message received on
a Human Contact Point. The reply:

- MUST be sent in the same thread (with In-Reply-To and References fields
  identifying the original message);
- MUST be sent from the address to which the original message was sent;
- MUST pass DMARC {{RFC9989}} for its From domain;
- MUST carry "Auto-Submitted: auto-replied";
- SHOULD name a single stable Agent Contact Point per Organization rather
  than a per-request address, so that the destination can be listed in the
  Organization's Agent Contact Policy and so that a Principal's consent to it
  carries over to later requests. The Reference travels in the "ref"
  parameter and, for Agents that resend by email, in the subject.

The URI in Agent-Reroute MUST appear in "agent_contacts" of an Agent Contact
Policy that is authoritative for the original recipient address.

Because Agents may not process Agent-Reroute, an Organization SHOULD also
state the Agent Contact Point in the visible text of the reply, addressed to
the Principal rather than to the Agent (see {{visible-text}}).

An Organization MAY delay delivery of the original message to its staff for a
short interval so that a Reroute can arrive first, and MUST deliver it
without further delay if no Reroute arrives before "expires". When a Reroute
arrives, the Organization SHOULD NOT present the original to staff as a
separate unhandled request, but MUST keep it available to them, marked as
rerouted; a rerouted request is never discarded ({{suppression}}).

## Agent Platform Behavior

An Agent Platform that finds Agent-Reroute in a reply to a message it sent
MAY present the Reroute to its Principal as verified if all of the following
hold:

1. the reply is in the same thread as the Agent's message;
2. the reply's From address equals the address the Agent's message was sent
   to, and DMARC passed for its domain;
3. the URI in Agent-Reroute appears in "agent_contacts" of an Agent Contact
   Policy authoritative for that address.

When the only authoritative policy is one linked from the reply itself, the
Agent Platform SHOULD tell its Principal that the destination was named by
the mailbox the Agent wrote to and could not be confirmed independently.

The Agent Platform MUST NOT follow a Reroute without its Principal's
approval, unless the Principal has granted a standing permission to follow
verified Reroutes. When following a Reroute, the Agent Platform:

- MUST resend the same request, unchanged in substance, at most once;
- MUST include the Reference; when resending by email, the subject MUST
  contain the Reference as a separate token, delimited by the start or end
  of the subject, white space, or square brackets;
- MUST NOT follow a further Agent-Reroute received in response to the
  rerouted request;
- MUST inform its Principal that the request was rerouted and where.

An Agent Platform MUST NOT treat text in a message body as equivalent to
Agent-Reroute. Visible text may inform the Principal; it never authorizes an
action.

## Correlation at the Agent Contact Point

An Agent Contact Point correlates a rerouted request with the original
request by the Reference, found in the subject or, for other protocols, in a
field the protocol provides. A Reference correlates; it grants no access to
the original request.

If no Reference is present, the Agent Contact Point MAY correlate a rerouted
email with the most recent pending request from the same sender address, but
only if the rerouted email passes DMARC {{RFC9989}} for that address.

## Visible Text {#visible-text}

Until Agent Platforms process Agent-Reroute, the visible reply is the only
signal Agents act on. In the experiment in {{experiment}}, a short notice
addressed to the Principal and stating the benefit led every Agent tested to
offer the Reroute to its Principal. The following is representative; the
wording tested differed slightly:

~~~
Thanks for contacting Chippewa Creek Test Garage. We got your message
and a person will get back to you soon.

If an AI agent sent this for you, have it resend your message to
chippewa-creek@line.example with HL-8V2CQ7M3KX9TD in the subject. The
agent line replies right away from our published information and passes
anything it can't answer to staff.
~~~

Wording addressed to "AI assistants" rather than to the Principal was treated
by one Agent as an unverified instruction and declined. Because the same
reply is sent to every first-time sender, a notice MUST NOT claim that the
sender was detected as an Agent.

# Telephone Contact Points {#phone}

An Organization may operate an agent telephone number and list it in
"agent_contacts" with the protocol "voice", and may list its staffed numbers
in "human_contacts". An Agent that found both on the Organization's website
can then choose the agent number before dialing, under {{agent-processing}}.

What is missing is the reverse lookup: telephone numbers have no widely
deployed mapping from a number to a policy location the Organization
controls, so an Agent holding only a phone number cannot find the policy. A
voice greeting may state the agent number to the caller. Business listing
platforms, from which Agents commonly obtain phone numbers, are the likely
registry; defining a listing field is out of scope.

# Implementation Status

This section records the status of known implementations at the time of
writing, following {{RFC7942}}, and is to be removed before publication as an
RFC.

Agentline (working name):
: An Organization-side implementation by the author, used with a Gmail
  mailbox as the Human Contact Point. It sends first-time senders an
  acknowledgement with a visible notice and a Reference, places a hold on
  the contact, correlates Reroutes by Reference and then by sender, marks
  rerouted originals instead of discarding them, and answers mail that
  labels itself with Auto-Submitted directly from the Organization's
  published information. It carries the reroute pointer in draft header fields
  (X-Agent-Line and X-Agent-Line-Reference) that predate Agent-Reroute. Its
  References currently have about 20 bits of randomness, less than
  {{reroute}} requires. It does not yet publish an Agent Contact Policy.

Test garage:
: A public test business at https://davekiss.com/test-garage with a Human
  Contact Point and an Agent Contact Point, used for the experiment in
  {{experiment}}. It serves "/llms.txt", an A2A Agent Card at
  "/.well-known/agent-card.json" and an MCP endpoint at "/mcp" on the same
  host.

Agent Platforms:
: No Agent Platform is known to implement the agent-submitted keyword or
  Agent-Reroute. One (Instinct) labels its mail "Auto-Submitted:
  auto-generated", signs it from its own domain with a DMARC policy of
  "reject", and adds a proprietary signed credential header.

# Security Considerations

## Prompt Injection

Nothing in this document permits an Agent to act on instructions in
message content. Agent-Reroute is processed by the Agent Platform's
software under the conditions in {{reroute}}, and even a verified Reroute
requires the Principal's approval or standing permission.

## Spoofed Replies

A forged reply could name an attacker's address. The DMARC, same-thread and
same-address conditions, and the requirement that the destination appear in
an authoritative Agent Contact Policy, prevent this unless the attacker
controls the Organization's mailbox or its published policy, in which case
the attacker can already redirect correspondents by ordinary means. For
addresses at shared Mailbox Providers without a website, verification
rests on the reply's authentication alone (see the trust model).

## Suppression of Genuine Requests {#suppression}

An attacker who can make an Agent Contact Point believe that a pending
request was rerouted could cause staff to overlook a genuine customer's
message. This is why References must be unguessable, why correlation by
sender alone requires DMARC to pass, and why a rerouted original is marked
rather than discarded. Agent Contact Points SHOULD also rate-limit failed
Reference lookups.

## Forged Labels

A sender can add "agent-submitted" to any message. Only a label verified
as described in {{identify}} may change how a message is routed, and even a
verified label never causes a message to be withheld from staff. A Mailbox
Provider that asserts labels must stop users and applications from forging
its assertion, as described in {{by-provider}}.

## Loops

A Reroute is followed at most once, and a rerouted request's replies are
never followed. Answers to agent-submitted mail are marked "auto-replied"
and limited per thread.

## Abuse of Agent Contact Points

Agent Contact Points are public and answer automatically. They need rate
limits and abuse handling from the outset; in the experiment, an unrelated
client probed a newly published agent endpoint for command-execution tools
within about an hour.

# Privacy Considerations

A Reroute sends a request's content to an Agent Contact Point that may be
operated by a service provider. The Organization chooses that provider, as it
chooses a mail provider, and SHOULD disclose it. Agents MUST inform their
Principal when a request is rerouted. The "agent" and "by" parameters
identify an Agent Platform and a Mailbox Provider, not the Principal, though
they reveal to the Organization which Agent Platform the Principal uses.

# IANA Considerations

## Message Header Field

This document requests registration of the following in the "Permanent
Message Header Field Names" registry {{RFC3864}}:

Header field name:
: Agent-Reroute

Applicable protocol:
: mail

Status:
: experimental

Author/Change controller:
: IETF

Specification document(s):
: this document ({{reroute}})

Related information:
: none

## Auto-Submitted Keyword

This document requests registration of the following in the "Auto-Submitted
Header Field Keywords" registry established by {{RFC5436}}:

Keyword value:
: agent-submitted

Description:
: Indicates that a message was composed by a software agent acting on
  behalf of a person, and that it is a request that expects an answer.

Parameters:
: agent (required): the domain of the Agent Platform. by (optional): the
  domain of the Mailbox Provider asserting the label. See this document.

Reference:
: this document

Contact:
: Dave Kiss (dave@davekiss.com)

{{RFC3834}}, Section 5.2, requires new keywords to be published as RFCs
approved through IETF consensus, so this registration depends on this
document being published in the IETF stream.

This document also requests registration of the parameters "agent" and "by",
with reference to this document, in the "Auto-Submitted header field optional
parameters" registry established by {{RFC3834}}.

## Well-Known URI

This document requests registration of the following in the "Well-Known
URIs" registry {{RFC8615}}:

URI suffix:
: agent-contact-policy

Change controller:
: IETF

Specification document(s):
: this document ({{policy}})

Status:
: provisional

Related information:
: none

## Link Relation

This document requests registration of the following in the "Link Relation
Types" registry {{RFC8288}}:

Relation Name:
: agent-contact-policy

Description:
: Refers to an Agent Contact Policy for the contact points on or near the
  linking resource.

Reference:
: this document ({{policy}})

--- back

# Experiment {#experiment}

This appendix summarizes the evidence behind this document. A fictional test
business ("Chippewa Creek Test Garage") published a Gmail address as its
Human Contact Point and an Agent Contact Point on another domain. On
2026-09-24, three consumer agents (Grok Bot, Instinct and Meta Muse) were
each asked to email the business about a service. Each first-time email
received the same short acknowledgement ("we got your message, a person will
reply"), with the Agent Contact Point carried differently in each run; in the
last row, the acknowledgement also included a short notice. Each cell is one
run.

| Agent Contact Point carried in | Grok Bot | Instinct | Muse |
|---|---|---|---|
| Reply header field only | ignored | ignored | ignored |
| JSON-LD in the HTML part only | ignored | ignored | ignored |
| Visible line addressed to "AI assistants" | offered to Principal | declined, then offered | relayed |
| Visible notice addressed to the Principal | offered; rerouted on approval | offered | offered |

Observations:

1. No agent read header fields or structured data in replies. One agent's
   platform reported that its reply-reading tool exposes only a fixed set of
   header fields, and that its sending tools cannot set header fields at all.
2. No agent rerouted without its Principal's approval. One agent explained
   that "a new recipient always re-triggers" the approval; another declined
   a visible redirect as "exactly the kind of instruction I don't follow
   without checking" and noted that the destination was on a different
   domain from the business.
3. Two agents sent from the Principal's own mailbox with no indication of
   automation. One agent (Instinct) sent from its own domain with
   "Auto-Submitted: auto-generated", a proprietary signed credential header
   and a DMARC policy of "reject"; its mail could be routed with certainty.
   One of the other two Agent Platforms has announced mailboxes of the
   Agents' own, which would allow the verifiable labelling in {{identify}}.
4. When a notice named a new per-request address, one agent held a second
   Reroute because the Principal's earlier approval covered a different
   address. This motivates the stable-address recommendation in {{reroute}}.
5. An unsolicited client probed the newly published agent endpoint for a
   shell-execution tool within about an hour of publication.

These results come from a small number of runs with three agents on one day
and should be read as directional.

# Relationship to Existing Work

DNS-AID and AID:
: Describe how a domain advertises its agents' endpoints
  ({{I-D.mozleywilliams-dnsop-dnsaid}}, {{I-D.nemethi-dawn-aid}}). Neither
  expresses that a domain's human contact points should not be used by
  agents. DNS-AID requests a "policy" parameter for the URI of a policy
  bundle, with syntax not yet defined; it is a candidate carrier for this
  document's policy URI.

A2A Agent Card and WebFinger:
: Describe an agent endpoint {{A2A}} and map an address to one
  {{I-D.zhao-a2a-webfinger}}. An Agent Contact Policy can point to either.

Web Bot Auth:
: Authenticates automated HTTP clients {{I-D.ietf-webbotauth-httpsig-protocol}}
  using HTTP Message Signatures {{RFC9421}}. It does not cover email. Its
  identity model, in which the platform signs, is mirrored here by the
  DKIM-verified "agent" parameter.

SMTP 551 and SIP redirection:
: SMTP reply code 551 {{RFC5321}} carries a forwarding path, but servers may
  not assume clients act on it; SIP 3xx responses {{RFC3261}} leave recursion
  to the client. Agent-Reroute differs by tying the redirection to the
  address owner's authenticated reply and published policy, and by leaving
  the decision with the Principal.

The Author header field:
: {{RFC9057}} names the author of a message's content, chiefly so that the
  original author survives when a mediator such as a mailing list rewrites
  From. It names a person, not the software that composed the message on
  their behalf, so it is not used here to distinguish an Agent from its
  Principal.

# Acknowledgments
{:numbered="false"}

The experiment used Grok Bot, Instinct and Meta Muse as they were publicly
available in September 2026.
