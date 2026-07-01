# Cloudflare Bulk 301 — Presentation Summary
*Short meeting talking points (~5 minutes)*

---

## 1. What I'm Proposing (30 sec)

A **desktop app** (macOS + Windows) called **Cloudflare Bulk 301** that lets us apply **301 redirects across many Cloudflare domains in one go** — instead of doing it manually in the dashboard, one domain at a time.

---

## 2. The Problem (30 sec)

Today, when we need to redirect multiple domains to one target:
- We go into Cloudflare **zone by zone**
- Create/update redirect rules **manually**
- **60 domains ≈ 20 minutes** per batch
- Easy to make **inconsistent** redirect patterns
- Gets worse with repeated migrations or portfolio updates

---

## 3. The Solution (1 min)

**Simple 4-step workflow:**
1. **Login** with Cloudflare API token
2. Set **one target domain** (where all traffic goes)
3. Add source domains **manually or via CSV**
4. Click **Apply** → see **per-domain results** (success / failed)

**Redirect pattern (consistent every time):**
`*source-domain/*` → `https://target-domain/$2` (301 Permanent)

Works on **macOS and Windows** from one codebase (Flutter).

---

## 4. Time Savings (30 sec)

| Process | 60 domains |
|---------|------------|
| **Manual (today)** | ~20 minutes |
| **With the app** | ~3 minutes |
| **Improvement** | ~85% faster |

100+ domains: under 5 minutes. Real-time status per domain.

---

## 5. Security — Why Desktop, Not a Web Tool (1–2 min)

**Five key points:**

1. **Not online** — Desktop app only. No public URL. Can't be accessed remotely from the internet.

2. **Token login** — Uses Cloudflare API token with scoped permissions (Zone Read + Page Rules Edit). No shared dashboard passwords.

3. **IP-restricted tokens** — If someone steals the token, it **won't work** from an IP that's not on the allowlist. Login screen shows your IPv4/IPv6 to make setup easy.

4. **Token never stored** — Held in **memory only** for the session. Close the app = token is gone. Nothing saved to disk or config files.

5. **Direct to Cloudflare** — All API calls go straight to `api.cloudflare.com` over HTTPS. No third-party servers. Actions still logged in **Cloudflare Audit Logs**.

---

## 6. What We Need (15 sec)

- Cloudflare API tokens (proper permissions)
- macOS or Windows workstations
- Optional but recommended: **IP allowlist** on tokens

No new servers. No hosting costs.

---

## 7. Timeline if Approved (15 sec)

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1 — Core app | 2–3 weeks | Login, bulk redirects, CSV, results |
| Phase 2 — Security | 1 week | IP display, error handling |
| Phase 3 — Rollout | 1 week | Testing, macOS + Windows deploy |

**Total: ~4–5 weeks**

---

## 8. The Ask (15 sec)

**Approval to proceed with development.**

This tool supports domain migrations, consolidations, and bulk redirect campaigns — **faster, consistent, and more secure** than manual work or a web-based internal tool.

---

## Quick Q&A Prep

**Q: What if the token is stolen?**
A: With IP allowlisting, it won't work outside registered IPs. Token also isn't saved on the machine.

**Q: Why not a web app?**
A: Web apps are exposed online and often store credentials on servers. Desktop = smaller attack surface.

**Q: Does it work with our Cloudflare setup?**
A: Yes — supports User tokens (Page Rules) and Account tokens (Redirect Rules).

**Q: Can we audit what was done?**
A: Yes — Cloudflare Audit Logs show API actions, token name, and source IP.

---

*Show prototype mockup from proposal doc (Figure 1) when discussing the UI.*
