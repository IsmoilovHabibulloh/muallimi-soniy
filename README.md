# 📖 Muallimus Soniy (Ikkinchi Muallim)

**Ahmad Xodiy Maqsudiy — "Muallimus Soniy"** kitobini raqamlashtirish loyihasi.
Arab alifbosini interaktiv o'rganish platformasi.

> An interactive Arabic alphabet learning platform, digitizing the classic textbook "Muallimus Soniy" (The Second Teacher) by Ahmad Khodiy Maqsudiy.

---

## ✨ Xususiyatlar

- 📱 **Flutter Web** — responsive interfeys (mobil va desktop)
- 🔊 **Audio playback** — har bir harf va so'z uchun ovozli talaffuz
- ✏️ **Admin panel** — kontentni boshqarish, sahifalarni annotatsiya qilish
- 🤖 **OCR pipeline** — Tesseract orqali avtomatik text aniqlash
- 📄 **PDF import** — kitob sahifalarini avtomatik import
- 🎯 **QA checks** — kontent sifatini avtomatik tekshirish
- 🔐 **JWT authentication** — xavfsiz admin kirish

## 🏗️ Texnologiyalar

| Qatlam | Texnologiya |
|--------|-------------|
| Frontend | Flutter Web (Dart) |
| Backend | FastAPI (Python 3.11) |
| Database | PostgreSQL 15 |
| Cache | Redis 7 |
| Task Queue | Celery |
| Web Server | Nginx |
| Container | Docker & Docker Compose |

## 📁 Loyiha strukturasi

```
├── frontend/          # Flutter Web ilova
├── backend/           # FastAPI + Celery
│   ├── app/
│   │   ├── api/       # REST endpointlar
│   │   ├── models/    # SQLAlchemy modellar
│   │   ├── services/  # Biznes logika
│   │   ├── tasks/     # Celery tasklar
│   │   └── middleware/ # Request logging, rate limiting
│   └── alembic/       # DB migratsiyalar
├── admin/dist/        # Admin panel (statik)
├── deploy/            # Nginx va deploy skriptlar
└── docs/              # Qo'shimcha hujjatlar
```

## 🚀 Ishga tushirish

### Talablar
- Docker & Docker Compose

### Qadamlar

```bash
# 1. Reponi klonlash
git clone https://github.com/YOUR_USERNAME/muallimus-soniy.git
cd muallimus-soniy

# 2. Environment sozlash
cp .env.example .env
# .env faylini o'zingizning ma'lumotlaringiz bilan to'ldiring

# 3. Ishga tushirish
docker compose up -d

# 4. DB migratsiyalar
docker compose exec api alembic upgrade head

# 5. Tekshirish
curl http://localhost:8888/health
```

### Lokal servislar

| Servis | URL |
|--------|-----|
| Web App | http://localhost:8888 |
| Admin Panel | http://localhost:8888/admin/ |
| API | http://localhost:8001 |
| Health Check | http://localhost:8888/health |

## 🔧 Asosiy buyruqlar

```bash
docker compose up -d          # Ishga tushirish
docker compose down           # To'xtatish
docker compose logs -f api    # API loglar
docker compose exec api alembic upgrade head  # Migratsiya
```

## 🔒 Xavfsizlik

- Barcha API aloqalari **HTTPS (TLS/SSL)** orqali shifrlangan
- Admin panel **JWT token** bilan himoyalangan
- CORS faqat ruxsat berilgan domenlardan
- Rate limiting middleware
- `.env` fayllar versiya boshqaruviga kiritilmagan

## 📝 Hissa qo'shish

Loyihaga hissa qo'shmoqchimisiz? [CONTRIBUTING.md](CONTRIBUTING.md) ni o'qing.

## 📄 Litsenziya

Ushbu loyiha [CC BY-NC 4.0](LICENSE) litsenziyasi ostida tarqatiladi.

> ⚠️ **Tijorat maqsadida foydalanish TAQIQLANADI.** Pulga sotish, pulli servis qilish yoki har qanday tijorat faoliyatida foydalanish mumkin emas. Barchaga TEKIN!
---

**Muallif:** Ahmad Xodiy Maqsudiy (asl kitob)
**Raqamlashtirish:** CodingTech jamoasi
