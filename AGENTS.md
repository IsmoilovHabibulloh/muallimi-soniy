# Agent Instructions — Muallimi Soniy

Bu loyiha **bd** (beads) bilan task tracking qiladi. Yangi conversation boshlaganda `bd list --all` bilan tarixni ko'ring.

## Loyiha Haqida

**Muallimi Soniy** — Ahmad Xodiy Maqsudiy kitobini raqamlashtirish loyihasi (arab alifbosi o'qitish platformasi).

| Komponent | Texnologiya | Joylashuv |
|-----------|-------------|-----------|
| Backend | FastAPI + PostgreSQL + Redis + Celery | `backend/` |
| Frontend | Flutter (iOS/Android/Web) | `frontend/` |
| Admin | Vanilla JS SPA | `admin/` |
| Deploy | Docker Compose + Nginx + SSL | `deploy/` |

- **Server:** `root@ikkinchimuallim.codingtech.uz` (parol: `codingtech2204`)
- **API:** `https://ikkinchimuallim.codingtech.uz/api/`
- **Admin:** `https://ikkinchimuallim.codingtech.uz/admin/`
- **GitHub:** `github.com/IsmoilovHabibulloh/muallimi-soniy`

## Beads Quick Reference

```bash
bd list --all         # Barcha issuelar (open + closed)
bd list               # Faqat ochiq issuelar
bd ready              # Tayyor tasklar
bd show <id>          # Issue tafsiloti
bd create "Title" -d "description" -t task -p 1  # Yangi task
bd update <id> --status in_progress              # Ishni boshlash
bd close <id> --reason "reason"                  # Ishni tugatish
bd sync               # Git bilan sinxronlash
```

## Landing the Plane (Session Completion)

**MANDATORY WORKFLOW:**

1. **File issues** — Yakunlanmagan ishlar uchun `bd create`
2. **Quality gates** — Testlar, lintlar
3. **Update status** — `bd close` tugagan ishlar uchun
4. **PUSH TO REMOTE:**
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # "up to date with origin" bo'lishi shart
   ```
5. **Hand off** — Keyingi session uchun context

**CRITICAL:** `git push` tugagunicha ish yakunlanmagan!
