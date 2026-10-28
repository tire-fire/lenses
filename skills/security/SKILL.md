---
name: security
description: Use when auditing a branch diff for adversarial security vulnerabilities, trust-boundary violations, guard removals, misuse-prone APIs ("sharp edges"), or threat-model drift — or when bootstrapping and maintaining a concise, repository-grounded threat model (THREAT_MODEL.md or a threat-model section in ARCHITECTURE.md). Owns authentication, entry-point and object-level authorization (IDOR / confused deputy), CSRF/redirect integrity, untrusted source-to-sink injection/traversal, secret/credential handling, fail-closed API defaults, and asymmetric DoS; defers non-security functional, state-machine, and concurrency bugs to correctness.
---

# Security & Threat Model

Run an adversarial, repository-grounded differential security review — or bootstrap and
maintain the concise threat model that anchors that review.

Unlike generic checklist scanners that flood reviews with theoretical OWASP advice,
this skill operates on two rules:
1. **Every vulnerability finding must trace a concrete untrusted source → code path →
   sink or privilege violation in the actual codebase (`file:line`)**, verified against
   upstream guards and the repository's threat model.
2. **The repository's threat model is a living engineering artifact** — short enough to
   read before every review, specific enough to name every principal, credential boundary,
   and accepted risk, and kept in sync when a branch changes the attack surface.

**Boundary with sibling review lenses:** This skill owns adversarial security, trust
boundaries, privilege/credential delegation, secret handling, misuse-prone security APIs,
and threat-model drift. Defer non-security functional bugs, state-machine ordering, and
concurrency/locking races to `correctness`, local control-flow band-aids to
`ripoff-bandaids`, and cross-layer state placement to `architecture-doctrine`.

---

## 1. The Authority: Repository Threat Model

Look for `THREAT_MODEL.md` at the repo root, or a `## Threat model` / `## Security model`
section in `ARCHITECTURE.md`, `CONTEXT.md`, or `CLAUDE.md`.

- **When present:** Read it first and **cite** its invariants when reporting findings.
  Respect its **Explicit Non-Goals / Accepted Risks** — never re-litigate an intentional,
  documented design boundary on a PR unless the diff itself breaks the stated condition.
- **When absent or stale (`THREAT_MODEL_DRIFT`):** Still run the full five-surface
  differential review below, and if the diff adds or modifies an entry point, authentication
  or permission gate, credential delegation path, secret/key, external sink, or build/deploy
  path that is not covered by the repo's threat model (or if the repo's threat model is
  missing any of the eight elements in §2), report a `THREAT_MODEL_DRIFT` finding naming the
  exact boundary, threat/mitigation, or section the orchestrator should record.

---

## 2. Bootstrapping or Updating a Threat Model

When invoked to create or update a repository's threat model (or when resolving a
`THREAT_MODEL_DRIFT` finding during `/lenses` Step 5), write or update `THREAT_MODEL.md`
(or the `## Threat model` section in `ARCHITECTURE.md` if the repo keeps a single design
doc).

Keep it **concise, concrete, and code-cited** — never compliance boilerplate. An ideal
threat model has these eight elements:

| An ideal threat model has | What to record (with `file:line` citations) |
|---|---|
| **1. Attackers and their goals** | Who you defend against (unauthenticated internet client, signed-in user/volunteer, compromised guest VM, external IdP/API peer, co-tenant) and what each wants, plus whose credentials execute downstream calls (delegated user token vs. service account). |
| **2. Assets ranked by impact** | What is worst to lose, ordered by blast radius: crown-jewel secrets/keys, user credentials/tickets, cluster/infrastructure control, tenant/team isolation, audit integrity, availability — and where each secret lives, how it is sealed (`nonce`/AAD domain), and where it must **never** appear (logs, URLs, DOM, SSE, error strings). |
| **3. Trust boundaries and data flows** | Every boundary where untrusted or semi-trusted bytes cross between principals or privilege zones (browser ↔ reverse proxy ↔ web server ↔ worker ↔ DB ↔ external control plane / guest agent), **ideally as an ASCII or Mermaid diagram** paired with the entry-point gates. |
| **4. Threats per boundary (STRIDE)** | Concrete threats at each boundary — often organized by **STRIDE** (**S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure, **D**enial of service, **E**levation of privilege) — plus repo-specific sharp edges (e.g., test-only fallbacks that must never fire in prod). |
| **5. Mitigations, each tied to a threat** | The specific code gate, cryptographic binding, query/parameter check, or isolation mechanism (`file:line`) that neutralizes each threat, rather than a disconnected list of controls. |
| **6. Accepted risks and non-goals** | Threats intentionally out of scope and why (e.g., *"Shared lab guest credentials in VM notes across signed-in volunteers"*, *"Compromised Proxmox/IdP control plane"*), so reviewers focus on real bugs instead of relitigating the architecture. |
| **7. Build and deploy path** | How code becomes running software: CI checks (`govulncheck`, tests, pinned action SHAs), image signing/publishing, secret injection, and CD/rollout authority (e.g., GitHub Actions → GHCR → Argo CD manifest pin). |
| **8. Owner and review trigger** | Who owns the threat model and the explicit triggers that require updating it in the same PR (any new/changed route, auth/permission gate, credential delegation path, secret/sealing purpose, external sink, or CI/CD deploy step). |

---

## 3. Differential Security Review Method

When reviewing a branch diff (`git diff <BASE>..HEAD`), execute these three steps in order:

### Step 1: Guard-Removal & Regression Triage (`-` lines first)

Before reading new features, inspect every removed or loosened check in the diff (`-` lines)
and check `git log` / `git blame` on touched security-critical functions:
- Did the branch remove, bypass, or widen a previously enforced authentication middleware,
  role/permission check, tenant/resource ownership filter, bounds check, `Origin`/redirect
  validation, or cryptographic/sealing check?
- Did a refactor move a validation call out of a shared helper into only *some* of its
  callers, leaving sibling callers unguarded?

### Step 2: Trace the Five Adversarial Surfaces

For every new or modified code path in the diff:

1. **Entry-point & object-level authorization (IDOR / confused deputy)**
   - Confirm every new or changed route, handler, RPC, CLI command, or queue consumer
     enforces authentication and privilege checks.
   - Confirm **object-level authorization**: the caller is authorized for the *specific*
     target resource, ID, node, pool, or tenant named in the request — not merely signed in.
   - Confirm **credential delegation**: downstream calls execute with the right principal's
     credential rather than a privileged service credential by mistake.
   - Confirm **fail-closed parity**: unauthorized requests fail closed with the same status
     and response shape as sibling endpoints (not a redirect where siblings return `403`,
     not a partial write before checking permissions).

2. **State-changing request integrity & redirect safety**
   - Confirm state-changing operations use safe HTTP methods (`POST`/`PUT`/`DELETE`, never
     `GET`) and enforce CSRF / `Origin` / `Sec-Fetch-Site` checks consistent with siblings.
   - Confirm any redirect target (`next`, `return_to`, `redirect`, `Location`) is validated
     against open redirects, including scheme-relative `//evil.com`, backslash `\/evil.com`,
     URL-encoded control characters, and host confusion.

3. **Untrusted source-to-sink injection & traversal**
   - Trace attacker-, user-, or upstream-controlled inputs (query/form/body params, headers,
     wire frames, external API/SSH/DB responses, filenames, environment) to every sink:
     - **HTML/JS/DOM sinks:** unescaped `template.HTML`/`template.JS`/`template.URL`,
       `innerHTML`, `insertAdjacentHTML`, `javascript:`/`data:` URLs, or unquoted attributes.
     - **Subprocess & CLI sinks:** shell interpolation (`sh -c`, SSH command strings), or
       positional arguments that can begin with `-` passed without `--` option termination.
     - **Filesystem & archive sinks:** `filepath.Join` with unvalidated input, `..` or
       symlink traversal escaping the intended root directory, or world-readable file modes
       on sensitive files.
     - **Query, SSRF & header/log sinks:** string-concatenated SQL/queries, user-controlled
       outbound URLs/hosts/ports, HTTP header splitting, or unescaped control characters in
       structured logs.

4. **Secret, credential & token handling**
   - Confirm tickets, API tokens, session cookies, private keys, or sealed blobs never leak
     into log lines, error pages, HTML data attributes, SSE/WebSocket broadcasts, URL query
     strings, or JSON responses.
   - Confirm secret/token/MAC comparisons use constant-time comparison (`subtle.ConstantTimeCompare`,
     `hmac.Equal`) and encryption/sealing binds nonces and AAD/context domains so ciphertexts
     cannot be transplanted across users, rows, or record types.

5. **Misuse-resistant APIs ("sharp edges") & asymmetric resource exhaustion (DoS)**
   - **Sharp edges / fail-closed defaults:** Inspect new structs, options, constructors, and
     helper signatures. Can a caller pass a zero value, empty string, or `nil` callback that
     silently disables authentication, skips verification, or defaults to "allow all" in
     production? Security gates must fail closed by default.
   - **Asymmetric DoS:** Check for unbounded `io.ReadAll` on request/response bodies,
     unbounded slice/map/goroutine allocation driven by untrusted counts, mutexes or DB
     transactions held across external network/SSH calls, or expensive work reachable before
     authentication.

### Step 3: Reachability, Blast Radius & False-Positive Gate

Before emitting any finding, run it through this verification gate:

1. **Trace upstream:** Read the callers up to the entry point. Is the input already
   authenticated, parsed into a strict type (e.g., `int`, strict enum, validated identifier),
   or escaped before reaching this function? If an upstream gate already makes the exploit
   path unreachable, drop the finding.
2. **Trace downstream & blast radius:** What privilege does the sink execute with, and how
   many production callers reach this path? Confirm the code path is reachable from
   production roots (`main`, router, server registration), not dead code or test-only wiring.
3. **Anti-rationalization check:**
   - *"It's a tiny 3-line PR"* → Heartbleed was 2 lines; small diffs often drop guards.
   - *"It's just a refactor"* → Refactors move validation across call boundaries; verify
     every caller still hits the guard.
   - *"It's an internal helper"* → Trace its callers; if an entry point passes untrusted
     input or a zero-value config, the helper is on the boundary.
4. **Hard exclusions — drop any candidate that falls into these buckets:**
   - Generic "add rate limiting", "add CAPTCHA", or "put behind a WAF" advice.
   - Theoretical resource/CPU/memory exhaustion without a concrete unauthenticated or
     high-amplification trigger introduced or exposed by the diff.
   - "Secrets remain in process memory" or unzeroed strings in garbage-collected runtimes.
   - Missing redundant validation ("defense in depth") on internal values that are already
     validated at the trust boundary.
   - Findings confined to unit test files or test fixtures (unless a test bypass is exported
     into production code and reachable at runtime).
   - Scenarios explicitly documented under **Accepted Risks / Non-Goals** in the repo's
     threat model.

---

## 4. Reporting Format

Order findings most severe first:

- **Vulnerability finding:**
  - **Defect:** One-sentence statement of the vulnerability or sharp edge.
  - **Exploit scenario:** Concrete trace (`attacker capability + untrusted input/state → code path → sink / security impact`).
  - **Location:** `file:line` (citing both the entry/source and the sink or dropped guard).
  - **Confidence:** `CONFIRMED` (traced end-to-end in source or reproduced with a targeted test) or `PLAUSIBLE` (state what single external condition could not be verified from the repo).
- **Threat-model drift finding (`THREAT_MODEL_DRIFT`):**
  - **Drift:** One-sentence statement of the new or changed trust boundary, principal rule, secret, or entry point at `file:line` that is missing from or contradicts the repo's threat model, and the exact update needed in `THREAT_MODEL.md` / `ARCHITECTURE.md`.

If neither vulnerabilities nor threat-model drift exist in the range, state that plainly
in one line rather than padding with low-confidence advice.
