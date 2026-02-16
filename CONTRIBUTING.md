# Muallimi Soniy — Hissa qo'shish qoidalari

Loyihaga qiziqish bildirganingiz uchun rahmat! 🎉

## Qanday hissa qo'shish mumkin

### 1. Bug xabar berish
- GitHub Issues orqali bug xabar bering
- Muammoni qayta hosil qilish qadamlarini batafsil yozing
- Screenshot yoki xato log'ini qo'shing

### 2. Feature taklif qilish
- Yangi feature g'oyangizni Issue sifatida yozing
- Nima uchun kerakligini tushuntiring

### 3. Kod bilan hissa qo'shish

```bash
# 1. Reponi fork qiling
# 2. Branch yarating
git checkout -b feature/yangi-xususiyat

# 3. O'zgarishlarni kiriting va test qiling
docker compose up -d
# ...o'zgarishlar...

# 4. Commit qiling
git commit -m "feat: yangi xususiyat qo'shildi"

# 5. Push qiling
git push origin feature/yangi-xususiyat

# 6. Pull Request oching
```

## Commit xabarlari

[Conventional Commits](https://www.conventionalcommits.org/) formatidan foydalaning:

- `feat:` — yangi xususiyat
- `fix:` — xatolik tuzatish
- `docs:` — hujjatlar o'zgartirish
- `style:` — kod formatlash
- `refactor:` — kodni qayta tuzish

## Kod sifati

- Python: PEP 8 standartiga rioya qiling
- Dart: `dart format` ishlatib formatlang
- Har bir o'zgarish uchun test yozing (iloji boricha)
- PR ochishdan oldin lokal muhitda ishlashini tekshiring

## Muhim qoidalar

- `.env` faylga **hech qachon** sir (parol, token) qo'shmang
- Katta o'zgarishlar uchun avval Issue oching va muhokama qiling
- Boshqa kontributorlarning kodini hurmat bilan ko'rib chiqing

---

Savollar bo'lsa Issues orqali yozing! 💬
