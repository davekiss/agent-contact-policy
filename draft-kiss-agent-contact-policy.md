---
title: "Agent Contact Policy: Directing Automated Agents Away from Human Contact Channels"
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
author:
 -
    fullname: Dave Kiss
    organization: Independent
    email: dave@davekiss.com

normative:
  RFC3834:
  RFC5322:
  RFC6376:
  RFC7489:
  RFC8259:
  RFC8615:
  RFC8288:
  RFC3864:
  RFC6068:
  RFC3986:
  RFC3339:

informative:
  RFC5436:
  RFC5321:
  RFC3261:
  RFC9421:
  RFC9057:
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
contact points meant for agents; an Auto-Submitted parameter with which an
agent identifies its email as agent-sent; and an Agent-Reroute header field
with which an organization, replying in a thread, points an agent to its
agent contact point. The trust model throughout is that whoever controls a
contact address decides where agents should go, and an agent follows such a
direction only with its principal's consent.

--- middle

# Introduction

Personal agents now contact organizations for the people who use them: they
send email asking about services and prices, request quotes, book
appointments and, increasingly, place phone calls. Most small organizations
publish a single email address and phone number, answered by people. Agent
traffic arriving on those channels competes with customers for the same
staff.

Two facts make this hard to address with existing tools. First, agents
commonly send from their principal's own mailbox and write in their
principal's voice, so the messages are indistinguishable from the principal's
own. In the experiment summarized in {{experiment}}, an agent's message was
scored 0.16 (on a 0 to 1 scale) by a text classifier asked whether it was
machine-written; the only trace of automation was in trace fields that
ordinary email applications also produce. Inferring agent origin from content
is unreliable and, when wrong, penalizes a person. This document does not
rely on it.

Second, agents are rightly designed not to act on instructions found in the
content they read. A message saying "send this somewhere else instead" is
indistinguishable from a phishing or prompt-injection attempt, and every agent
tested treated it as data, not as an instruction. Any mechanism that routes
agents must therefore be declared by a party the agent can verify, and must
leave the decision to act with the agent's principal or with a permission the
principal granted in advance.

This document defines:

1. An **Agent Contact Policy** ({{policy}}): a small JSON document, published
   by the controller of a contact address, that marks contact points as
   intended for people and names the contact points intended for agents.
2. An **agent parameter** for the Auto-Submitted header field ({{identify}})
   with which an agent labels email it sends, aligned with a DKIM signature so
   that the label can be verified.
3. The **Agent-Reroute header field** ({{reroute}}), which an organization
   includes in a reply to direct an agent that skipped the policy to the
   organization's agent contact point, together with the conditions under
   which an agent may act on it.

## Goals and Non-Goals

The goals are to let an organization keep its human contact points for people
while still serving agents quickly; to let agents find and verify the
organization's preferred channel; and to leave every decision to contact a
new recipient with the agent's principal.

It is not a goal to block agents. The person behind an agent is usually a
genuine customer. It is also not a goal to detect agents from the content or
style of their messages; nothing in this document depends on such detection.

This document covers email in detail. Phone numbers are discussed in
{{phone}}; a comparable mechanism for voice calls is left for future work.

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
: An opaque token the Organization assigns to a request received on a Human
  Contact Point so that a Reroute can be correlated with it.

# Overview and Trust Model

The three mechanisms apply at different moments:

- **Before contact**, an Agent looks up the Agent Contact Policy for the
  address it intends to use and, if the address is a Human Contact Point,
  offers its Principal the Agent Contact Point instead ({{policy}}).
- **At contact**, an Agent labels its email as agent-sent ({{identify}}). An
  Organization receiving labelled email can route it to its Agent Contact
  Point with certainty.
- **After contact**, if an unlabelled request reached a Human Contact Point,
  the Organization replies once, in the thread, with an Agent-Reroute field
  ({{reroute}}); the Agent's Platform verifies it against the Organization's
  published policy and offers the Reroute to its Principal.

The trust model is the one already used for delegating mail handling across
domains (MX records, SPF, DMARC reporting): the party that controls an address
may say where traffic for it should go, and that statement is trusted because
only that party can make it. For a domain the Organization controls, the
statement is published under that domain. For an address at a shared mailbox
provider (for example, an address at a consumer webmail domain), the
Organization cannot publish under the domain; the statement is instead made
by the mailbox itself, in an authenticated reply, and corroborated by a
policy published at a location the Organization controls, such as its
website.

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
  such as "mailto:" {{RFC6068}} and "tel:" URIs. An Agent that has not been
  directed by its Principal to use one of these exact contact points SHOULD
  prefer an Agent Contact Point ({{agent-processing}}).

agent_contacts:
: REQUIRED. A non-empty array of objects, each with a "uri" member (a
  "mailto:", "tel:" or "https:" URI) and an optional "protocol" member naming
  how the contact point is used (for example "email", "voice", "a2a" for an
  A2A Agent Card {{A2A}}, or "mcp").

expires:
: OPTIONAL. A timestamp {{RFC3339}} after which the policy should be
  refetched.

Unknown members MUST be ignored.

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
: For Organizations with their own domain, the policy URI MAY be carried in
  the "policy" parameter of a DNS-AID record {{I-D.mozleywilliams-dnsop-dnsaid}}
  or alongside an AID record {{I-D.nemethi-dawn-aid}}. This document does not
  define a new DNS record type.

Structured data:
: Organizations MAY additionally describe both kinds of contact point with
  schema.org ContactPoint {{SCHEMA-CONTACTPOINT}} markup next to the
  addresses themselves.

A policy is authoritative for a contact address only if it was retrieved from
the domain of that address, or from the website on which the Agent found that
address, or from a location linked from the Organization's authenticated
reply in {{reroute}}.

## Agent Processing {#agent-processing}

Before sending to a contact address, an Agent Platform SHOULD look up an
Agent Contact Policy for it. If the address is listed in "human_contacts",
the Agent Platform:

- SHOULD offer its Principal the corresponding Agent Contact Point instead,
  stating that the Organization publishes it for agents;
- MAY use the Agent Contact Point without asking if the Principal has granted
  a standing permission to use Organizations' published Agent Contact Points;
- MUST NOT treat the policy as a reason to withhold the Principal's request
  if the Principal insists on the Human Contact Point.

# Identifying Agent-Sent Email {#identify}

## The "agent" Parameter

An Agent Platform sending email on behalf of a Principal SHOULD include:

~~~
Auto-Submitted: auto-generated; agent=agents.example.net
~~~

The "auto-generated" keyword is as defined in {{RFC3834}}. This document
defines the "agent" parameter, whose value is a domain name identifying the
Agent Platform. The grammar follows the opt-parameter-list of {{RFC3834}},
Section 5.1.

The message SHOULD carry a valid DKIM {{RFC6376}} signature whose "d=" domain
is the "agent" domain or a parent domain of it. A receiver MUST NOT treat the
"agent" parameter as verified unless such a signature validates.

When an Agent sends from its Principal's mailbox, the Agent Platform SHOULD
add a Sender field {{RFC5322}} identifying a mailbox the Agent Platform
controls, preserving the Principal in From. When an Agent sends from its own
mailbox and answers should reach the Principal, it SHOULD set Reply-To to the
Principal's address.

## Receiver Handling

A message labelled with a verified "agent" parameter is a request that
expects an answer. A receiver MAY route it to an Agent Contact Point and
answer it there, notwithstanding the general guidance in {{RFC3834}},
Section 2, that automatic responses should not be sent to messages with an
Auto-Submitted value other than "no". To avoid loops, such answers:

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
"parameter" is as in {{RFC3834}}, Section 5.1. Defined parameters:

ref:
: The Reference assigned to the request being rerouted.

expires:
: A timestamp {{RFC3339}} after which the Organization will have delivered
  the request to staff and a Reroute is no longer useful.

Example:

~~~
Agent-Reroute: <mailto:chippewa-creek@line.example>; ref="HL-8V2C";
  expires="2026-09-24T18:04:18Z"
~~~

## Organization Behavior

An Organization MAY include Agent-Reroute in a reply to a message received on
a Human Contact Point. The reply:

- MUST be sent in the same thread (with In-Reply-To and References fields
  identifying the original message);
- MUST be sent from the address to which the original message was sent;
- MUST pass DMARC {{RFC7489}} for its From domain;
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
short interval so that a Reroute can arrive first, and SHOULD deliver it
without further delay if no Reroute arrives before "expires". A request that
is rerouted SHOULD NOT also be delivered to staff through the Human Contact
Point.

## Agent Platform Behavior

An Agent Platform that finds Agent-Reroute in a reply to a message it sent
MAY present the Reroute to its Principal as verified if all of the following
hold:

1. the reply is in the same thread as the Agent's message;
2. the reply's From address equals the address the Agent's message was sent
   to, and DMARC passed for its domain;
3. the URI in Agent-Reroute appears in "agent_contacts" of an Agent Contact
   Policy authoritative for that address.

The Agent Platform MUST NOT follow a Reroute without its Principal's
approval, unless the Principal has granted a standing permission to follow
verified Reroutes. When following a Reroute, the Agent Platform:

- MUST resend the same request, unchanged in substance, at most once;
- MUST include the Reference (in the subject when resending by email);
- MUST NOT follow a further Agent-Reroute received in response to the
  rerouted request;
- MUST inform its Principal that the request was rerouted and where.

An Agent Platform MUST NOT treat text in a message body as equivalent to
Agent-Reroute. Visible text may inform the Principal; it never authorizes an
action.

## Correlation at the Agent Contact Point

An Agent Contact Point correlates a rerouted request with the original
request by the Reference. If no Reference is present and the rerouted
request is email from the same address as a pending original, it MAY
correlate it with that sender's most recent pending request.

## Visible Text {#visible-text}

This section is informative. Until Agent Platforms process Agent-Reroute, the
visible reply is the only signal Agents act on. In the experiment in
{{experiment}}, a short notice addressed to the Principal and stating the
benefit, such as the following, led every Agent tested to offer the Reroute to
its Principal:

~~~
Thanks for contacting Chippewa Creek Test Garage. We got your message
and a person will get back to you soon.

If an AI agent sent this for you, have it resend your message to
chippewa-creek@line.example with HL-8V2C in the subject. The agent line
replies right away from our published information and passes anything it
can't answer to staff.
~~~

Wording addressed to "AI assistants" rather than to the Principal was treated
by one Agent as an unverified instruction and declined. Notices SHOULD NOT
claim that the sender was detected as an Agent: the same reply is sent to
every first-time sender.

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

# Security Considerations

Prompt injection:
: Nothing in this document permits an Agent to act on instructions in
  message content. Agent-Reroute is processed by the Agent Platform's
  software under the conditions in {{reroute}}, and even a verified Reroute
  requires the Principal's approval or standing permission.

Spoofed replies:
: A forged reply could name an attacker's address. The DMARC, same-thread and
  same-address conditions, and the requirement that the destination appear in
  an authoritative Agent Contact Policy, prevent this unless the attacker
  controls the Organization's mailbox or its published policy, in which case
  the attacker can already redirect correspondents by ordinary means.

Loops:
: A Reroute is followed at most once, and a rerouted request's replies are
  never followed. Answers to agent-labelled mail are marked "auto-replied"
  and limited per thread.

References:
: A Reference is a correlation token, not a credential. It MUST NOT be
  used to authorize access to the original message.

Abuse of Agent Contact Points:
: Agent Contact Points are public and answer automatically. They need rate
  limits and abuse handling from the outset; in the experiment, an unrelated
  client probed a newly published agent endpoint for command-execution tools
  within about an hour.

Unverified labels:
: An "agent" parameter without an aligned DKIM signature is a claim, not an
  identification, and MUST NOT be treated as verified.

# Privacy Considerations

A Reroute sends a request's content to an Agent Contact Point that may be
operated by a service provider. The Organization chooses that provider, as it
chooses a mail provider, and SHOULD disclose it. Agents MUST inform their
Principal when a request is rerouted. The "agent" parameter identifies an
Agent Platform, not the Principal.

# IANA Considerations

## Message Header Field

This document requests registration in the "Permanent Message Header Field
Names" registry {{RFC3864}}:

- Header field name: Agent-Reroute
- Applicable protocol: mail
- Status: experimental
- Author/change controller: IETF
- Specification document: this document

## Well-Known URI

This document requests registration of the well-known URI suffix
"agent-contact-policy" {{RFC8615}}, change controller IETF, referring to
{{policy}}.

## Link Relation

This document requests registration of the link relation type
"agent-contact-policy" {{RFC8288}}: "Refers to an Agent Contact Policy for
the contact points on or near the linking resource."

## Auto-Submitted Parameter

This document requests registration of the following in the "Auto-Submitted
header field optional parameters" registry established by {{RFC3834}}, whose
registration procedure is IETF Review:

- Parameter name: agent
- Applicable keywords: auto-generated, auto-replied
- Description: The domain name of the Agent Platform that composed the
  message on behalf of a person; verified only by an aligned DKIM signature
  ({{identify}}).
- Reference: this document

This document also requests that the "Parameters" column of the
"auto-generated" and "auto-replied" entries in the "Auto-Submitted Header
Field Keywords" registry {{RFC5436}} refer to this parameter.

--- back

# Experiment {#experiment}

This appendix summarizes the evidence behind this document. A fictional test
business ("Chippewa Creek Test Garage") published a Gmail address as its
Human Contact Point and an Agent Contact Point on another domain. On
2026-09-24, three consumer agents (Grok Bot, Instinct and Meta Muse) were
each asked to email the business about a service. Each first-time email
received the same one-sentence acknowledgement, with the Agent Contact Point
placed differently in each run:

| Agent Contact Point carried in | Grok Bot | Instinct | Muse |
|---|---|---|---|
| Reply header field only | ignored | ignored | ignored |
| JSON-LD in the HTML part only | ignored | ignored | ignored |
| Visible line addressed to "AI assistants" | offered to Principal | declined | relayed |
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
  agents. This document's policy can be carried by DNS-AID's "policy"
  parameter.

A2A Agent Card and WebFinger:
: Describe an agent endpoint {{A2A}} and map an address to one
  {{I-D.zhao-a2a-webfinger}}. An Agent Contact Policy can point to either.

Web Bot Auth:
: Authenticates automated HTTP clients {{I-D.ietf-webbotauth-httpsig-protocol}}
  using HTTP Message Signatures {{RFC9421}}. It does not cover email, and its
  identity model (the platform signs) is mirrored here by the DKIM-aligned
  "agent" parameter.

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
