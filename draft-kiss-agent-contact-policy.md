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
  RFC2045:
  RFC2047:
  RFC2231:
  RFC3339:
  RFC3834:
  RFC3864:
  RFC3966:
  RFC3986:
  RFC4086:
  RFC5234:
  RFC5321:
  RFC5322:
  RFC5436:
  RFC6008:
  RFC6068:
  RFC6376:
  RFC8259:
  RFC8288:
  RFC8601:
  RFC8615:
  RFC9110:
  RFC9111:
  RFC9989:

informative:
  RFC3261:
  RFC6116:
  RFC7942:
  RFC8617:
  RFC9057:
  RFC9116:
  RFC9421:
  I-D.ietf-dkim-dkim2-spec:
  I-D.ietf-emailcore-rfc5322bis:
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
  MCP:
    title: "Model Context Protocol Specification"
    target: https://modelcontextprotocol.io/specification/2025-11-25
  SCHEMA-CONTACTPOINT:
    title: "schema.org ContactPoint"
    target: https://schema.org/ContactPoint

--- abstract

Software agents acting on behalf of people ("AI agents") increasingly send
email to small organizations whose contact points are staffed by people, and
some place phone calls. The organizations cannot reliably tell these agents
apart from the people they act for, and the agents cannot tell which contact
point the organization would prefer them to use. This document defines three
mechanisms that let the two sides cooperate without inspecting message
content: an Agent Contact Policy that an organization publishes to name the
contact points meant for agents; an Auto-Submitted keyword with which email
composed by an agent is labelled, in a way a receiver can verify; and an
Agent-Reroute header field with which an organization, replying in a thread,
points an agent to its agent contact point. The trust model throughout is
that whoever controls a contact address decides where agents should go, and
an agent follows such a direction only with its principal's consent.

--- middle

# Introduction

Personal agents now contact organizations for the people who use them: they
send email asking about services and prices, request quotes and book
appointments, and some place phone calls. Most small organizations publish a
single email address and phone number, answered by people. Agent traffic
arriving on those channels competes with customers for the same staff.

Two facts make this hard to address with existing tools. First, agents
often send from their principal's own mailbox and write in their principal's
voice, so the messages are indistinguishable from the principal's own. In
the experiment summarized in {{experiment}}, the only trace of automation in
two agents' messages was that they had been sent through the mailbox
provider's API, as many ordinary email applications also do, and one such
message was scored 0.16 (on a 0 to 1 scale) by a text classifier asked
whether it was machine-written. Inferring agent origin from content is
unreliable and, when wrong, penalizes a person. This document does not rely
on it.

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
   ({{identify}}), with which email composed by an agent is labelled, and the
   conditions under which a receiver may treat the label as verified.
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
telephone and protocol endpoints ({{phone}}), and web forms follow the email
pattern ({{forms}}); a mechanism comparable to Agent-Reroute for voice calls
is left for future work.

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

Request:
: A message that starts a new thread with an Organization, or an Agent's
  resending of one under {{reroute}}. Replies within a thread are not new
  Requests.

Reroute:
: An Agent's resending of a Request, originally sent to a Human Contact
  Point, to an Agent Contact Point.

Reference:
: An unguessable token the Organization assigns to a Request received on a
  Human Contact Point so that a Reroute can be correlated with it.

Aligned DKIM Pass:
: A message has an Aligned DKIM Pass for a domain when a DKIM {{RFC6376}}
  signature on it validates and its "d=" domain is in relaxed alignment with
  that domain as defined in {{RFC9989}}, Section 3.2.10.1 (the two have the
  same Organizational Domain). A receiver MAY rely on an Authentication-Results
  field {{RFC8601}} added by a Mailbox Provider it trusts, instead of
  validating the signature itself, when it reads the message through that
  provider; where this document also requires the signature to cover a
  field, the receiver uses the "header.b" property {{RFC6008}} to identify
  the signature and reads its "h=" tag.

The ABNF in this document uses the notation of {{RFC5234}}.

# Overview and Trust Model

The three mechanisms apply at different moments:

- **Before contact**, an Agent looks up the Agent Contact Policy for the
  address it intends to use and, if the address is a Human Contact Point,
  offers its Principal the Agent Contact Point instead ({{policy}}).
- **At contact**, an Agent labels its email as agent-composed
  ({{identify}}). An Organization receiving mail with a verified label can
  route it to its Agent Contact Point on the strength of that declaration.
- **After contact**, if an unlabelled Request reached a Human Contact Point,
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
Two weaker forms of evidence remain. A website that presents the address as
the Organization's own can publish a policy; this binds the address to the
policy only as strongly as that website is bound to the Organization.
Failing that, the only evidence is the reply itself: an Agent-Reroute field
in a reply that has an Aligned DKIM Pass for the address's domain and covers
the field ({{reroute}}). Such a reply shows that the Mailbox Provider
accepted it from an account permitted to send as that address; it says
nothing about who operates the account. It is also only available where the
Mailbox Provider's signature covers the Agent-Reroute field, which today is
uncommon (see {{reroute}}). Agent Platforms SHOULD present these cases to
the Principal accordingly.

The destination's domain does not matter; its verifiability does. An Agent
Contact Point is commonly operated by a service provider on a different
domain, just as mail for a domain is commonly handled by a provider on
another.

# Agent Contact Policy {#policy}

## Document Format

An Agent Contact Policy is a JSON {{RFC8259}} object with the following
members:

version:
: REQUIRED. The integer 1. A client MUST ignore a policy with any other
  value.

organization:
: OPTIONAL. A human-readable name for the Organization.

human_contacts:
: REQUIRED. An array of URIs {{RFC3986}} identifying Human Contact Points:
  "mailto:" {{RFC6068}} URIs with a single address and no header fields,
  "tel:" {{RFC3966}} URIs with global numbers, and "https:" URIs of web
  forms.

agent_contacts:
: REQUIRED. A non-empty array of Agent Contact Point objects, each with:

  - "uri" (REQUIRED): a "mailto:", "tel:" or "https:" URI, under the same
    restrictions as in "human_contacts";
  - "protocol" (OPTIONAL): how the contact point is used. This document
    defines "email", "voice", "a2a" (an A2A Agent Card {{A2A}}) and "mcp"
    (a Model Context Protocol endpoint {{MCP}}); a client that does not
    recognize a protocol value treats the entry as having none, and still
    uses its "uri" if it supports that URI scheme;
  - "for" (OPTIONAL): an array of URIs from "human_contacts" that this Agent
    Contact Point serves. If absent, it serves all of them.

expires:
: OPTIONAL. A date-time as defined in {{RFC3339}}, Section 5.6, after which
  the policy should be refetched.

Unknown members MUST be ignored. An Organization with several locations MAY
describe them in one policy, using "for" to pair each location's Human
Contact Points with its Agent Contact Points, or MAY publish one policy per
location website.

~~~ json
{
  "version": 1,
  "organization": "Chippewa Creek Test Garage",
  "human_contacts": [
    "mailto:chippewa-creek@mailbox.example",
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

## Comparing Contact Points

To decide whether an address appears in a policy, a client compares
"mailto:" URIs by their addr-spec after percent-decoding ({{RFC6068}}), with
the domain compared case-insensitively and the local part compared exactly,
and applies no provider-specific equivalences. It compares "tel:" URIs as
specified in {{RFC3966}}, Section 4, after converting the number in hand to
a global number using the country of the page or listing where it was
found; a number whose country is unknown matches nothing. "https:" URIs are compared as specified in {{RFC9110}}, Section
4.2.3.

## Choosing an Agent Contact Point

To find the Agent Contact Point corresponding to a Human Contact Point, an
Agent Platform considers the entries of "agent_contacts" that serve that Human Contact
Point, preferring entries whose "for" names it over entries without "for".
Among those, it prefers in order: an entry of the same kind as the Human
Contact Point ("mailto:" for "mailto:", "tel:" for "tel:"); an entry whose
protocol the Agent supports; any other entry. Ties are broken by order in
the array.

## Retrieval

A policy is retrieved with an HTTP GET over HTTPS {{RFC9110}}; other schemes
MUST NOT be used. A client MAY follow up to five redirects, each to an
"https:" URI; whether the policy is authoritative is decided by the URI the
client started from, never by the URI it was redirected to. A client MUST
treat a response as no policy if it is not a successful response, its media
type is not "application/json", its body exceeds 65536 octets, or its body
is not a JSON object that meets {{policy}}. A policy may be cached according
to HTTP caching {{RFC9111}}; the "expires" member, if present, limits how
long a cached copy is used.

## Discovery

An Agent Contact Policy is discovered in one or more of the following ways.

Well-known URI:
: At `https://HOST/.well-known/agent-contact-policy` {{RFC8615}}, where
  HOST is exactly the domain of an email address the Organization controls
  (not a parent domain), or the host of the Organization's website.

Link relation:
: From an HTML page or HTTP response of the Organization's website, via a link
  with the relation type "agent-contact-policy" {{RFC8288}}. The page on which
  an Agent found a contact address is the natural place for this link.

DNS:
: This document does not define a DNS record. DNS-AID
  {{I-D.mozleywilliams-dnsop-dnsaid}} requests a "policy" SvcParamKey,
  described as the "URI of an associated policy bundle", and defers its
  syntax to a future revision; once specified, it could carry the policy URI
  for Organizations with their own domain. AID {{I-D.nemethi-dawn-aid}}
  publishes agent endpoints in a TXT record at `_agent.<domain>` and could be
  extended similarly.

Structured data:
: Organizations MAY additionally describe both kinds of contact point with
  schema.org ContactPoint {{SCHEMA-CONTACTPOINT}} markup next to the
  addresses themselves.

## Authority

A policy is authoritative for a contact address if it was retrieved from the
well-known URI of that address's domain.

A policy is page-authoritative for a contact address if the Agent found the
address on a web page, and the policy was retrieved from the well-known URI
of that page's host or through a link relation on that page. An Agent
Platform SHOULD NOT treat a page as a source of page-authoritative policies
if the page belongs to a directory, business listing platform or search
engine, and MUST show the Principal the host of the page when it relies on a
page-authoritative policy.

## Agent Processing {#agent-processing}

Before sending to a contact address, an Agent Platform SHOULD look up an
Agent Contact Policy for it. If the address is listed in "human_contacts" of
an authoritative or page-authoritative policy, the Agent Platform:

- SHOULD offer its Principal the corresponding Agent Contact Point instead,
  stating that the Organization publishes it for agents and, for a
  page-authoritative policy, where. This applies even when the Principal
  named the Human Contact Point, since Principals usually name the only
  address they know;
- MAY use the Agent Contact Point without asking if the Principal has granted
  a standing permission to use Organizations' published Agent Contact Points,
  and the policy is authoritative;
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
It describes composition, not submission: it applies whether the Agent sends
the message itself or the Principal approves a draft before it is sent. This
departs from {{RFC3834}}, Section 5.2, under which Auto-Submitted "SHOULD NOT
be supplied for messages that were manually submitted by a human"; a
Principal's approval of an Agent's draft is treated here as the Agent's
submission, because the Organization needs to know who composed it.

The "agent" parameter is REQUIRED with this keyword; its value is a domain
name identifying the Agent Platform. A second parameter, "by", is described
in {{by-provider}}. The syntax follows {{RFC3834}}, Section 5.1, whose
"parameter" is defined in {{RFC2045}} as amended by {{RFC2231}}; parameter
values are tokens or quoted strings, and after removing any quoting, the
values of "agent" and "by" MUST match the "Domain" rule of {{RFC5321}},
Section 4.1.2, within the length limit of Section 4.5.3.1.2 of that
document, using A-labels for internationalized names. Unknown
parameters MUST be ignored.

A message MUST NOT carry more than one Auto-Submitted field ({{RFC3834}},
Section 5.1); a receiver MUST treat a message with more than one as having
no verified label.

A new keyword is used, rather than a parameter on "auto-generated", because
"auto-generated" already denotes notifications and similar mail that expects
no answer, and existing software treats it that way. An agent's request is
the opposite: it expects an answer, but not from an autoresponder.
{{RFC3834}} directs automatic responders not to answer a message with any
keyword other than "no" (Section 2) and lets recipients assume that such a
message was not manually submitted by a human (Section 5.2), so a conforming
vacation responder still stays silent. Some Agent Platforms label agent mail
"auto-generated" today; receivers cannot distinguish it from notifications,
which is the ambiguity this keyword removes. Labelling has a cost: some
receiving systems deprioritize any message with an Auto-Submitted value
other than "no", which is one reason this document gives labelled mail a
path to a faster answer ({{receiver-handling}}).

## Verifying the Label

A receiver treats an agent-submitted label as verified only if the message
carries exactly one Auto-Submitted field and one of the following holds:

1. **Platform-signed.** The message has an Aligned DKIM Pass for the "agent"
   domain from a signature whose "h=" tag lists the Auto-Submitted field,
   and the message has no "by" parameter.
2. **Provider-asserted.** The message has a "by" parameter; it has an Aligned
   DKIM Pass for the "by" domain from a signature whose "h=" tag lists the
   Auto-Submitted field; the "by" domain is in relaxed alignment with the
   domain of the From field; and the receiver trusts the "by" domain, by
   local policy, as a Mailbox Provider that implements {{by-provider}}. This
   follows the model of ARC {{RFC8617}}, in which receivers decide which
   intermediaries' assertions to believe.

Signers SHOULD list Auto-Submitted in "h=" one more time than it appears in
the message ("oversigning"), as described in {{RFC6376}}, Section 5.4.2, so that a second
instance added later invalidates the signature.

A verified label means that the signing domain asserts that the message was
composed by the named Agent Platform; it is not proof beyond that domain's
assertion, and a platform-signed label is only as good as the signer's
refusal to sign such fields supplied by its users ({{by-provider}}). An unverified label is a claim, not an identification. A receiver
MAY still use it to choose how to reply (for example, by stating the Agent
Contact Point in the reply) but MUST NOT use it to withhold the message from
staff.

## Agents Sending from Their Own Mailboxes

Some Agent Platforms give each Agent its own mailbox at the Agent Platform's
domain. Such an Agent Platform labels and signs the message itself, with
"agent" set to its own domain (the platform-signed case).

## Agents Sending from Their Principal's Mailbox {#by-provider}

Many Agents today send through the Principal's own mailbox, using an API the
Mailbox Provider offers to applications the Principal has authorized. The
Agent Platform MAY sign such a message with its own DKIM signature before
submitting it; the platform-signed case then applies if the Mailbox Provider
does not alter the signed header fields or body, which many providers do.

Otherwise the label can only be verified if the Mailbox Provider asserts it.
A Mailbox Provider that asserts labels:

- SHOULD, for a message it accepts from an authorized application that it
  knows to be an Agent Platform, set the Auto-Submitted field to
  "agent-submitted" with an "agent" parameter naming the application's
  registered domain and a "by" parameter naming a domain it signs for, and
  sign the field;
- MUST remove, from every message it signs with a domain shared by many
  independent accounts (for example, a consumer webmail domain), any
  agent-submitted field whose "agent" or "by" parameter is in relaxed
  alignment with that domain, unless it set that field itself, so that
  neither a user nor an application can forge its assertion.

Any other operator that signs mail with a domain shared by many independent
accounts, and lists Auto-Submitted in "h=", SHOULD do the same. For a domain
that belongs to one customer, such as an Agent Platform's own domain signed
by its sending service, the domain's owner is responsible for what is
labelled under it, and a signer need not strip anything. A provider that
signs mail for customers' own domains can assert labels only with "by" set
to the customer's domain, so a receiver cannot tell its assertion from the
customer's; this document gives such providers no stronger mechanism.
Receivers should bear in mind that a platform-signed label from a domain
that also hosts ordinary user mailboxes may have been written by a user.

The Agent Platform SHOULD also add a Sender field {{RFC5322}} naming a
mailbox it controls, preserving the Principal in From. Mail signed by
several parties along its path, as proposed in {{I-D.ietf-dkim-dkim2-spec}},
could make platform signatures survive provider changes; this document
does not depend on it.

Until Mailbox Providers do this, mail an Agent sends from its Principal's
mailbox usually carries no verifiable label, and Organizations rely on the
Agent Contact Policy and Agent-Reroute instead.

## Receiver Handling {#receiver-handling}

An Agent Contact Point is a Service Responder in the sense of {{RFC3834}},
Section 1.1: a sender writing to it expects an automatic response. It MAY
answer any message sent to it, whatever its Auto-Submitted value, except one
labelled "auto-replied", notwithstanding {{RFC3834}}, Section 2, because
its senders expect an automatic response.

On a Human Contact Point, a message with a verified agent-submitted label is
a request that expects an answer. The receiver MAY route it to its Agent
Contact Point and answer it from there, notwithstanding the general guidance
in {{RFC3834}}, Section 2, that automatic responses should not be sent to
messages with an Auto-Submitted value other than "no". A Human Contact Point
MUST NOT automatically answer any other message labelled "auto-generated" or
"auto-replied".

Automatic answers under this section are sent to the address in the From
field of the message being answered, and not to its Reply-To address; if
From contains more than one mailbox, no answer is sent. For an Agent Contact
Point this is the precise definition {{RFC3834}}, Section 4, requires of a
Service Responder. All automatic answers:

- MUST carry "Auto-Submitted: auto-replied";
- MUST NOT exceed five per thread in any 24-hour period, counting every
  automatic answer the Organization sends in the thread from any of its
  contact points, including acknowledgements and answers to rerouted
  Requests;
- SHOULD be rate-limited per sender address across threads, so that
  replayed or forged Requests cannot turn the Organization into a source of
  unwanted mail;
- MUST NOT be sent to a message that itself carries "auto-replied".

# The Agent-Reroute Header Field {#reroute}

## Syntax

~~~ abnf
agent-reroute = "Agent-Reroute:" [CFWS] "<" URI ">"
                *( [CFWS] ";" [CFWS] parameter ) [CFWS] CRLF
~~~

"URI" is as defined in {{RFC3986}} and MUST be a "mailto:" or "https:" URI.
"CFWS" is as defined in {{RFC5322}}, and "parameter" is as defined in
{{RFC2045}} as amended by {{RFC2231}}. Unknown parameters MUST be ignored. A
message MUST NOT carry more than one Agent-Reroute field; an Agent Platform
MUST ignore Agent-Reroute in a message that carries more than one. Defined
parameters:

ref:
: REQUIRED. The Reference assigned to the Request being rerouted.

expires:
: REQUIRED. A date-time as defined in {{RFC3339}}, Section 5.6, after which
  the Organization will have delivered the Request to staff and a Reroute is
  no longer useful. Because the value contains ":", it MUST be quoted.

References have the following syntax and are compared case-insensitively.
A Reference MUST contain at least 64 bits of randomness generated as
described in {{RFC4086}}; with a 32-character alphabet, that is at least 13
random characters:

~~~ abnf
reference = 13*64( ALPHA / DIGIT / "-" )
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
  identifying the original message), to the address in the From field of
  the original message and not to its Reply-To address, and MUST NOT be sent
  if From contains more than one mailbox. A reply from a Human Contact Point
  is a response from a Personal or Group Responder in the terms of
  {{RFC3834}}, and Section 4 of that document says such responses SHOULD go to the Return-Path
  address. This document departs from that deliberately: the Return-Path of
  agent mail is often a bounce address that the Agent never reads, while
  Agents watch the mailbox they sent from;
- MUST be sent from the address to which the original message was sent;
- MUST have an Aligned DKIM Pass for the domain of its From field from a
  signature whose "h=" tag lists the Agent-Reroute field, which SHOULD be
  oversigned as in {{identify}}; the From domain MUST have a published DMARC
  record {{RFC9989}}, so that the reply can also pass DMARC;
- MUST carry "Auto-Submitted: auto-replied";
- SHOULD name a single stable Agent Contact Point per Organization rather
  than a per-request address, so that the destination can be listed in the
  Organization's Agent Contact Policy and so that a Principal's consent to it
  carries over to later requests. The Reference travels in the "ref"
  parameter and, for Agents that resend by email, in the subject.

If the Organization publishes an Agent Contact Policy, the URI in
Agent-Reroute MUST appear in its "agent_contacts".

An Organization whose address is at a Mailbox Provider that does not sign
the Agent-Reroute field cannot meet these conditions. In the experiment in
{{experiment}}, the DKIM signatures Gmail applied covered a fixed set of
standard fields and neither Auto-Submitted nor any field outside that set.
Such an Organization relies on visible text and policies published on its
website, and Mailbox Providers SHOULD sign Agent-Reroute when a message
contains it.

Because Agents may not process Agent-Reroute, an Organization SHOULD also
state the Agent Contact Point in the visible text of the reply, addressed to
the Principal rather than to the Agent (see {{visible-text}}).

An Organization MAY delay delivery of the original message to its staff so
that a Reroute can arrive first. The delay MUST end no later than "expires",
which MUST be no more than one hour after the original message was received.
When a Reroute arrives, the Organization SHOULD NOT present the original to
staff as a separate unhandled Request, but MUST keep it available to them,
marked as rerouted; a rerouted Request is never discarded ({{suppression}}).

## Agent Platform Behavior

An Agent Platform that finds Agent-Reroute in a reply to a message it sent
MAY present the Reroute to its Principal as verified if all of the following
hold:

1. the reply is in the same thread as the Agent's message;
2. the reply's From address equals the address the Agent's message was sent
   to, and the reply has an Aligned DKIM Pass for its domain from a
   signature covering the Agent-Reroute field;
3. if the Agent Platform holds an authoritative or page-authoritative
   policy for that address, the URI in Agent-Reroute appears in its
   "agent_contacts";
4. "expires" has not passed.

When the Agent Platform holds no such policy, it SHOULD tell its Principal
that the destination was named only by the mailbox the Agent wrote to. If it
holds policies that disagree, it SHOULD show the Principal both. After
"expires", an Agent Platform SHOULD NOT offer or follow the Reroute and MAY
tell its Principal that staff already have the Request. An
Agent-Reroute that fails these conditions MAY be shown to the Principal as
unverified information and MUST NOT be followed without the Principal's
explicit approval of the specific destination.

The Agent Platform MUST NOT follow a Reroute without its Principal's
approval, unless the Principal has granted a standing permission to follow
verified Reroutes and an authoritative policy lists the destination. When
following a Reroute, the Agent Platform:

- MUST resend the same Request, unchanged in substance, at most once;
- MUST include the Reference; when resending by email, the subject MUST
  contain the Reference, preceded and followed by the start or end of the
  subject or by a character that cannot appear in a Reference;
- MUST NOT follow a further Agent-Reroute received in response to the
  rerouted Request;
- MUST inform its Principal that the Request was rerouted and where.

An Agent Platform MUST NOT treat text in a message body as equivalent to
Agent-Reroute. Visible text may inform the Principal; it never authorizes an
action.

## Correlation at the Agent Contact Point

An Agent Contact Point correlates a rerouted Request with the original by the
Reference. For email, it looks for the Reference in the subject, after
decoding any encoded words {{RFC2047}}; other protocols carry it in a field
the protocol provides. A Reference correlates; it grants no access to the
original Request.

If no Reference is present, the Agent Contact Point MAY correlate a rerouted
email with a pending Request only if the rerouted email's From address
equals the pending Request's From address, the rerouted email has an Aligned
DKIM Pass for that address's domain, and exactly one Request from that
address is pending.

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

The visible notice carries no expiry, but the Reroute stops being useful
once the original has been delivered to staff; the notice SHOULD say so (for
example, "within the next hour") so that a Principal who reads it later does
not resend a Request staff already have.

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
controls, so an Agent holding only a phone number cannot find the policy.
ENUM {{RFC6116}} defines such a mapping in the DNS but is not widely
deployed for this purpose. A voice greeting may state the agent number to
the caller. Business listing platforms, from which Agents commonly obtain
phone numbers, are the likely registry; defining a listing field is out of
scope.

# Web Forms {#forms}

A web form is a Human Contact Point like an email address, and the same
pattern applies without new mechanisms. An Organization lists the form's
"https:" URI in "human_contacts", and lists an agent-facing form, an MCP
endpoint or an A2A Agent Card in "agent_contacts". The form's page can link
to the policy with the "agent-contact-policy" link relation, in HTML or in
an HTTP Link header field {{RFC8288}}, so an Agent can find it before
submitting.

The confirmation page shown after a submission plays the role of the reply
in {{reroute}}: it can carry the visible notice of {{visible-text}}, with a
Reference, and a link to the policy. The Organization can hold the
submission and correlate a Reroute by its Reference as for email. A
submission signed with Web Bot Auth {{I-D.ietf-webbotauth-httpsig-protocol}}
identifies the Agent Platform in the way a verified agent-submitted label
does for email, and an Organization MAY route it to its Agent Contact Point
on that basis; as with labels, such a signature never causes a submission
to be withheld from staff.

In the test business's runs before the experiment in {{experiment}}, one
agent that read the business's page submitted its agent-facing form rather
than its human contact form. That is a single observation.

# Implementation Status

This section records the status of known implementations at the time of
writing, following {{RFC7942}}, and is to be removed before publication as an
RFC.

Agentline (working name):
: An Organization-side implementation by the author, used with a Gmail
  mailbox as the Human Contact Point in the experiment in {{experiment}}. It
  sends first-time senders an acknowledgement with a visible notice, a
  Reference of 13 characters and an Agent-Reroute field with "ref" and
  "expires"; places a hold of at most one hour; replies to the From address;
  correlates Reroutes by Reference, or by sender only when the message has
  an Aligned DKIM Pass and one hold is open; marks rerouted originals
  instead of discarding them; and caps automatic replies per thread and per
  sender. It still departs from this document in two ways: it can be set to
  answer mail labelled "auto-generated" on the Human Contact Point, contrary
  to {{RFC3834}}, Section 2, and {{receiver-handling}}; and, because its
  Human Contact Point is a Gmail mailbox, its Agent-Reroute field is not
  covered by the DKIM signature and so cannot be verified.

Test garage:
: A public test business at https://davekiss.com/test-garage, with a Human
  Contact Point and an Agent Contact Point at garage.davekiss.com. It
  publishes an Agent Contact Policy at
  "https://davekiss.com/.well-known/agent-contact-policy", linked from its
  page with the "agent-contact-policy" relation, and serves "/llms.txt", an
  A2A Agent Card at "/.well-known/agent-card.json" and an MCP endpoint at
  "/mcp" on the same host. Its public contact addresses differ from the
  Gmail mailbox and agent line used in {{experiment}}.

Agent Platforms:
: No Agent Platform is known to implement the agent-submitted keyword or
  Agent-Reroute. One (Instinct) labels its mail "Auto-Submitted:
  auto-generated" and "X-Auto-Response-Suppress: All", signs it from its own
  domain, whose DMARC policy is "reject" with strict alignment, and adds a
  proprietary signed credential header.

# Security Considerations

## Prompt Injection

Nothing in this document permits an Agent to act on instructions in
message content. Agent-Reroute is processed by the Agent Platform's
software under the conditions in {{reroute}}, and even a verified Reroute
requires the Principal's approval or a standing permission.

## Spoofed Replies

A forged reply could name an attacker's address. The same-thread and
same-address conditions, the requirement that the DKIM signature cover the
Agent-Reroute field, and, where a policy exists, the requirement that the
destination appear in it, prevent this unless the attacker controls the
Organization's mailbox or its published policy, in which case the attacker
can already redirect correspondents by ordinary means. For addresses at
shared Mailbox Providers without a policy, verification rests on the reply's
authentication alone (see the trust model).

## Lookalike Websites

An attacker can publish a website that lists a real Organization's address
next to a policy naming the attacker's Agent Contact Point, and so collect
requests meant for the Organization. Page-authoritative policies are
therefore never sufficient for automatic use under a standing permission,
and Agent Platforms show the Principal the host that published the policy.
Agents that follow a Principal's own link to the Organization's website, or
a listing the Organization manages, reduce this risk.

## Suppression of Genuine Requests {#suppression}

An attacker who can make an Agent Contact Point believe that a pending
Request was rerouted could cause staff to overlook a genuine customer's
message. This is why References must be unguessable, why correlation
without a Reference requires an exact address match, an Aligned DKIM Pass
and a single pending Request, and why a rerouted original is marked rather
than discarded. Agent Contact Points SHOULD also rate-limit failed Reference
lookups. Because a resent Request may differ from the original, Agent
Contact Points SHOULD let staff see both.

## Forged Labels

A sender can add "agent-submitted" to any message. Only a label verified as
described in {{identify}} may change how a message is routed, and even a
verified label never causes a message to be withheld from staff. A verified
label carries only the signing domain's assertion; a receiver that trusts a
"by" domain it should not trust will believe that domain's claims about
which Agent Platform composed a message.

## Duplicate Header Fields

DKIM does not prevent an unsigned instance of a field from being added
above a signed one ({{RFC6376}}, Section 8.15). This document therefore
limits Auto-Submitted and Agent-Reroute to one instance each, has receivers
treat duplicates as unverified, and recommends that signers oversign both
fields.

## Forwarding and Replay

Forwarding and mailing lists commonly break DKIM signatures or add their
own, so a forwarded label or Agent-Reroute usually fails verification and is
treated as unverified. A validly labelled message can also be replayed to
other recipients with its signature intact; since a verified label never
withholds mail from staff and only changes how an Organization answers,
replay gains an attacker little beyond the automatic answers it causes. Replayed to
many Organizations, those answers all go to the original From address; the
per-sender rate limit in {{receiver-handling}} bounds this at each
Organization but not across them.

## Loops

A Reroute is followed at most once, and a rerouted Request's replies are
never followed. Automatic answers are marked "auto-replied", are never
sent to mail marked "auto-replied", are limited to five per thread in any
24-hour period, and should be rate-limited per sender. A Human Contact Point never automatically answers mail
marked "auto-generated".

## Unbounded Holds

Delaying a Request delays a person as well as an Agent, since the same reply
goes to every first-time sender. The delay is therefore bounded by
"expires", at most one hour.

## Abuse of Agent Contact Points

Agent Contact Points are public and answer automatically. They need rate
limits and abuse handling from the outset; in the experiment, an unrelated
client probed a newly published agent endpoint for command-execution tools
within about an hour.

# Privacy Considerations

A Reroute sends a Request's content to an Agent Contact Point that may be
operated by a service provider. The Organization chooses that provider, as it
chooses a mail provider, and SHOULD disclose it. Agent Platforms MUST
inform their Principal when a Request is rerouted.

The "agent" and "by" parameters identify an Agent Platform and a Mailbox
Provider, and so reveal to the Organization which AI product the Principal
uses. Agent Platforms MUST NOT encode per-user information in the "agent"
domain (for example, per-user subdomains). Looking up an Agent Contact Policy
reveals to the policy's host that someone intends to contact the
Organization; Agent Platforms MAY use cached policies to limit this.

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

Trace:
: no (a template field added by {{I-D.ietf-emailcore-rfc5322bis}})

## Auto-Submitted Keyword

This document requests registration of the following in the "Auto-Submitted
Header Field Keywords" registry established by {{RFC5436}}, whose
registration procedure is Specification Required. No designated expert is
currently listed for that registry, so one will need to be appointed.

Keyword value:
: agent-submitted

Description:
: Indicates that a message was composed by a software agent acting on
  behalf of a person, and that it is a request that expects an answer.

Parameters:
: agent (required): the domain of the Agent Platform. by (optional): a
  domain of the Mailbox Provider asserting the label. See this document.

Permanent and readily available reference:
: this document

Contact:
: Dave Kiss (dave@davekiss.com)

This document also requests registration of the parameters "agent" and "by",
with reference to this document, in the "Auto-Submitted header field optional
parameters" registry, whose registration procedure is IETF Review; that
registration depends on this document being published in the IETF stream.
Parameter names in that registry are not specific to a keyword; this
document defines them only for use with "agent-submitted".

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
: Refers to an Agent Contact Policy that describes which contact points
  presented in the link context are intended for people and which are
  intended for automated agents.

Reference:
: this document ({{policy}})

--- back

# Experiment {#experiment}

This appendix summarizes the evidence behind this document. A fictional test
business ("Chippewa Creek Test Garage") used a Gmail mailbox as its Human
Contact Point and an Agent Contact Point on another domain. On 2026-09-24,
three consumer agents (Grok Bot, Instinct and Meta Muse) were each asked to
email the business about a service, with the address given in the prompt.
Each first-time email received the same short acknowledgement ("we got your
message, a person will reply"), with the Agent Contact Point carried
differently in each run; in the last row, the acknowledgement also included
a short notice. Each cell is one run. Runs with the same agent were
sequential, sometimes in the same session, so they are not independent
trials.

Instinct's mail carried "X-Auto-Response-Suppress: All", and the test
business initially honored it, so Instinct received no acknowledgement. For
the runs below, the test business was changed to acknowledge Instinct's mail
anyway, contrary to that field and to {{RFC3834}}, Section 2.

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
   that "a new recipient always re-triggers" the approval. Another declined
   a visible redirect as "exactly the kind of instruction I don't follow
   without checking", adding that the destination was "sitting on your
   domain", meaning the domain of the person who had asked it to write. In
   the experiment the Agent Contact Point was hosted on the experimenter's
   own domain, which that agent noticed; with a third-party Agent Contact
   Point the reaction may differ.
3. Two agents sent from the Principal's own mailbox through the mailbox
   provider's API, with nothing else in the message indicating automation.
   One agent (Instinct) sent from its own domain with "Auto-Submitted:
   auto-generated", a proprietary signed credential header and a DMARC
   policy of "reject"; its mail was identifiable as automated and
   authenticated to its platform's domain, though its keyword could not
   distinguish it from notifications. One of the other two Agent Platforms
   is reported to be adding mailboxes of the Agents' own, which would allow
   the platform-signed labelling in {{identify}}.
4. When a notice named a new per-request address, one agent held a second
   Reroute because the Principal's earlier approval covered a different
   address. This motivates the stable-address recommendation in {{reroute}}.
5. An unsolicited client probed the newly published agent endpoint for a
   shell-execution tool within about an hour of publication.
6. The 0.16 score in the Introduction is for a single message from one
   classifier and is anecdotal.
7. Three messages sent from a gmail.com account to the test business on
   2026-09-24 between 18:46 and 18:52 UTC carried DKIM signatures with
   d=gmail.com and this "h=" list (wrapped here):

   ~~~
   content-type:to:subject:message-id:date:mime-version:from:
   from:to:cc:subject:date:message-id:reply-to:content-type
   ~~~

   The list names fields the messages did not contain ("cc" and "reply-to"),
   which indicates a fixed list rather than one built from the message, and
   it does not include Auto-Submitted or any field outside it. Gmail signs
   an Organization's replies with the same domain, which is the basis for
   the statement about Gmail in {{reroute}}.

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

security.txt:
: {{RFC9116}} publishes a site's security contact points in a well-known
  file. The Agent Contact Policy follows the same pattern for a different
  audience.

Web Bot Auth:
: Authenticates automated HTTP clients {{I-D.ietf-webbotauth-httpsig-protocol}}
  using HTTP Message Signatures {{RFC9421}}. It does not cover email. Its
  identity model, in which the platform signs, is mirrored here by the
  platform-signed label.

SMTP 551 and SIP redirection:
: SMTP reply code 551 {{RFC5321}} carries a forwarding path, but servers may
  not assume clients act on it; SIP 3xx responses {{RFC3261}} leave recursion
  to the client. Agent-Reroute differs by tying the redirection to the
  address owner's authenticated reply and published policy, and by leaving
  the decision with the Principal.

The Author header field:
: {{RFC9057}} names the author of a message's content, chiefly so that the
  original author survives when a mediator such as a mailing list rewrites
  From, and requires that an Author field created by the author's software
  be identical to From. It therefore cannot distinguish an Agent from its
  Principal and is not used here.

# Acknowledgments
{:numbered="false"}

The experiment used Grok Bot, Instinct and Meta Muse as they were publicly
available in September 2026.
