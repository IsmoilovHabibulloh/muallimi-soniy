"""Page content data for Muallimus Soniy — transcribed from actual book pages.

Each page is a list of (text, section, type) tuples.
type: "letter", "word", "sentence"

Pages 1-2: Muqova va Muqaddima
Pages 3-16: Harflar mashqlari (kitobdan screenshot asosida yozilgan)

Jami: 16 sahifa
"""

PAGES = {}

# ═══════════════════════════════════════════════════
# Sahifa 1: Muqova (3 ta unit)
# ═══════════════════════════════════════════════════
PAGES[1] = [
    ("معلم ثانی", "cover_title", "word"),
    ("یاکی", "cover_subtitle", "word"),
    ("الفباء عربی", "cover_subtitle_2", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 2: MUQADDIMA — har bir so'z alohida unit
# Birinchi element sarlavha (sentence), qolganlari so'zlar (word)
# ═══════════════════════════════════════════════════
_MUQADDIMA_TEXT = """Qo'lingizdagi ushbu kitobcha va uning muallifiga chin ma'noda baxtli taqdir nasib etgan. 1868-yilning 26-sentyabrida Qozon uyezdining Toshsuv qishlog'ida tug'ilib, Qozondagi "Qosimiya" madrasasida ta'lim olgan Ahmad Hodiy Maqsudiy rahmatullohi alayhi hali ancha yoshligida ushbu qo'llanmani tuzar ekan, u asrlar osha avloddan-avlodga Alloh taoloning Kalomi asosida arab alifbosida xat-savod o'rgatish bilan birga dastlabki qur'oniy saboq berishda davom etishini Parvardigori olamdan so'ragani aniq. Hozirgi paytda bu sohada ko'plab biri-biridan qiziqarli, salmoqli darslik va qo'llanmalar yaratilganiga qaramasdan, muallifning boshqa asarlari, jumladan, "Ibodati islomiya" singari bu mo'jaz kitobcha ham sodda, o'zlashtirishga oson va dilga yaqinligi bilan hanuzgacha ko'plab musulmon diyorlarida ilm toliblarini o'ziga tortib kelayotgani, albatta, bu duoning ijobatidir. O'zbekiston Respublikasi Fanlar akademiyasi Sharqshunoslik instituti ko'lyozmalar xazinasida saqlanayotgan hujjatlarga va boshqa manbalarga asosan, kitobchaning Markaziy Osiyo hududida tarqalish tarixi quyidagicha kechganini taxmin qilish mumkin. 1902-yilda Toshkentda rus-tuzem maktablari o'zbek sinflari uchun Saidrasul Saidazizov (1866-1933) "Ustodi avval" ("Birinchi ustoz") qo'llanmasi nashrdan chiqadi. Bu Urta Osiyoda tovush usuli (usuli savtiya)da tuzilgan birinchi darslik bo'lib, oktyabr inqilobiga qadar rus-tuzem maktablaridagina emas, yangi usuldagi maktablarda ham o'zbek tilidan asosiy savod chiqarish kitobi sifatida qo'llangan. O'sha davrda Rossiyada Ahmad Hodiy Maqsudiyning ruscha-tatarcha "Muallimi avval" qo'llanmasi keng shuhrat qozongan edi. Kitobchaning bizning yurtimizda nashr etilgan keyingi barcha nashrlariga asos bo'lib xizmat qilgan nusxasi sarvarg'ida buni tasdiqlovchi rasmiy ma'lumotlar keltiriladi. Ushbu alifbo 1913-yil 9-aprelda muayyan raqamli hujjat bilan tatar va rus-tatar maktablarida sinfda foydalanishga kiritilgani qayd etilgach, yana bunday ta'kidlanadi: "Un to'rtinchi nashri. Birinchi nashriga 1892-yil 28-yanvarda Petrograd senzurasi ruxsat bergan. "Umid" shirkati matbaasi. Qozon, 1917 y.". Bundan kelib chiqadiki, birinchi nashriga ruxsat berilgach, kitobcha yigirma yildan ko'proq muddat mobaynida norasmiy ravishda xalq ta'limi sohasida obru qozonib ulgurgach, davlat unga maktablar uchun rasmiy qo'llanma maqomini berishga majbur bo'lgan. Shu davrdan e'tiboran kitobcha Rossiya imperiyasi, keyinchalik sobiq Sovet Ittifoqi hududidagi musulmon o'lkalarda avval lotin, so'ngra kirill alifbosi muomalaga kiritilganiga qadar shu vazifani bajarib keldi. Kitobcha 1917-yilga qadar o'n to'rt marta, keyingi davrlarda yana necha o'nlab bora nashr etilganining o'zi buning yorqin isbotidir. Jumladan, 1913-yili Toshkentda ham faqat noshir Ali Asg'ar (Kalinin) ismi ko'rsatilgan "Muallimi soniy" kitobchasi paydo bo'ladiki, u mazmunan aynan Maqsudiyning biz fikr yuritayotgan qo'llanmasiga muvofiq kelardi. Albatta, qo'llanmaning keyingi nashrlari muallif ismi sharifi bilan qayta-qayta chiqib turdi. O'shandan buyon u faqat bizdagina emas, balki boshqa ko'plab mamlakatlarda avlodlarga tengsiz beminnat muallimlik qilib keladi. Shularni hisobga olgan holda, mazkur qo'llanmani holicha, ya'ni nussa ko'chirilaverishidan xiralashib qolgan xatini tiniqlashtirgan va boshqa juz'iy texnik xatolarni tuzatgan holda, o'quvchilarga taqdim etishga qaror qilindi. Albatta, bugungi kunda Madina bosma mushaflar keng ommalashgani bois dastalab ushbu kitobchani ham ularga monand o'zgartirish rejasi ham yo'q emasdi. Birok, bir jihati, uzoq davr davomida xalqlarga qadrdon bo'lib, yaxshi xizmat kilib kelayotgan kitobchani asl xolicha saqlab kolish uni yaratgan va shu asosda ilm maydoniga qadam qo'ygan ajdodlarimiz xotirasiga hurmat va minnatdorlik belgisi bo'lib tuyuldi. Shunga ko'ra, qo'llanmaning asl ruhiyatini saqlab qolish maqsadidan kelib chiqib, kitobga deyarli o'zgarish kiritilmadi. Faqatgina suralarning xati diyorimizda Madina bosma mushaflar ommalashgani bois harflar ko'zga moslashishi oson bo'lishi uchun Madina bosma xatida, harakatlari esa Qozon bosma holatida qoldi. Shuningdek, asosiy maqsad o'quvchi arab xatini shunchaki o'qishnigina emas, balki boshdanok har bir harfni maxraji (joy-joyidan) chiqarishni yaxshi o'rganish orqali Qur'on suralari qiroatiga go'zal talaffuz bilan kirishuvini ko'zlab, kitobga ovoz tushirilgan disk ham ilova qilinmoqda. Talaba darsni o'zlashtirish jarayonida diskdagi ovozga diqqat qilgan holda, harflarning talaffuz sifati hamda fatha, kasra, zammadan iborat harakatlarning ado etilishiga e'tibor qaratmog'i lozim. Chunki Qur'on qiroatida aksar xatolar (zod) o'rniga (30) tovushi, (sod) o'rniga (sin) yoki (se) tovushiga o'xshatib, maxrajidan boshqa joydan chiqarilishi; jarangli (be) jarangsiz (pe) tovushiga o'xshatib talaffuz etilishi; sukunli "mim", "nun" va "lom" harflarining qalqala bo'lib tebranib qolishi kabi sifatlar va harakatlarda lablarning keragicha harakatlanmay, ixtilos (harakatning 2/3 qismi yo'qolib, 1/3 qismi talaffuzda namoyon) bo'lishi kabi holatlar yuz berishida kuzatiladi. Shu jihatlarga e'tibor qaratilsa, ushbu ilovali qo'llanma Qur'oni karimni to'g'ri o'qishni o'rganishda yana bir muhim vosita bo'lib xizmat qiladi, degan umiddamiz. Garchi Qur'oni karim kalimalaridan boshqa so'zlarni talaffuz qilishda tajvid qoidalariga rioya qilish vojib bo'lmasa-da, maqsad Qur'oni karimni to'g'ri o'qishga odatlantirish bo'lgani uchun imon kalimalari ham tajvid asosida o'qib ko'rsatildi."""

# Build page 2: first item = title sentence, then each word is a separate "word" unit
PAGES[2] = [("MUQADDIMA", "muqaddima_title", "sentence")]
for _w in _MUQADDIMA_TEXT.split():
    PAGES[2].append((_w, "muqaddima_body", "word"))


# ═══════════════════════════════════════════════════
# Sahifa 3: Bismillah + Alifbo + Alif va Ra asoslari
# (eski sahifa 5)
# ═══════════════════════════════════════════════════
PAGES[3] = [
    ("بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ", "bismillah", "sentence"),
    ("ا ب ت ث ج ح خ", "alphabet_row_1", "letter"),
    ("د ذ ر ز س ش ص", "alphabet_row_2", "letter"),
    ("ض ط ظ ع غ ف ق", "alphabet_row_3", "letter"),
    ("ك ل م ن و ه لا ي ة", "alphabet_row_4", "letter"),
    ("أَ إِ أُ", "alif_harakat", "letter"),
    ("رَ رِ رُ", "ra_harakat", "letter"),
    ("أَرْ إِرْ أُرْ", "alif_ra_sukun", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 4: Za (ز) + Mim (م) + Ta (ت)
# (eski sahifa 6)
# ═══════════════════════════════════════════════════
PAGES[4] = [
    # Za bo'limi
    ("زَ زِ زُ", "za_header", "letter"),
    ("أَزْ إِزْ أُزْ زَرْ زِرْ زُرْ", "za_row_1", "word"),
    ("أَزُرُ إِزُرُ أُزُرُ", "za_row_2", "word"),
    ("أَزُرُ إِزُرُ أُرْزُ", "za_row_3", "word"),
    # Mim bo'limi
    ("مَ مِ مُ", "mim_header", "letter"),
    ("أَمْ إِمْ أُمْ مُزْ مَزْ رُمْ", "mim_row_1", "word"),
    ("أَمَرَ أَمِرَ أُمِرُ إِمْرُ رَمَزَ إِرِمِ", "mim_row_2", "word"),
    ("مَرْمَرْ رَمْرَمْ زَمْزَمْ أَرْزَمْ", "mim_row_3", "word"),
    # Ta bo'limi
    ("تَ تِ تُ", "ta_header", "letter"),
    ("مَتْ مِتْ مُتْ تَمْرُ تَمِرَ", "ta_row_1", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 5: Ta davomi + Nun (ن) + Ya (ي)
# (eski sahifa 7)
# ═══════════════════════════════════════════════════
PAGES[5] = [
    # Ta davomi (ramkada)
    ("زُرْتُ أَمَرْتِ مَرَرْتُ أُمِرْتُ أَمَرْتُ", "ta_cont_row_1", "word"),
    ("أَمَرْتُمْ أُمِرْتُمْ مَرَرْتُمْ مُرِرْتُمْ", "ta_cont_row_2", "word"),
    # Nun bo'limi
    ("نَ نِ نُ", "nun_header", "letter"),
    ("أَنْ اِنْ زِنْ مَنْ مِنْ نَمْ", "nun_row_1", "word"),
    ("أَنْتَ نِمْتَ أَنْتُمْ نِمْتُمْ نَزُرُ نَزِنْ", "nun_row_2", "word"),
    ("اِمْرَنَ أُمِرْنَ مَرَرْنَ مُرِرْنَ أَمَرْنَ", "nun_row_3", "word"),
    # Ya bo'limi
    ("يَ يِ يُ", "ya_header", "letter"),
    ("اَيْ اَيْمُ زَيْتُ مَيْتُ رَأَى رَمَى", "ya_row_1", "word"),
    ("يَمَنُ مَرْيَمُ مِيْزَرُ مَيْمَنُ أَيْمَنُ", "ya_row_2", "word"),
    ("أَمْرَيْنِ زَيْتَيْنِ أَيْمِيْنِ مَيْتَيْنِ", "ya_row_3", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 6: Ba (ب) + Kaf (ك)
# (eski sahifa 8)
# ═══════════════════════════════════════════════════
PAGES[6] = [
    # Ba bo'limi
    ("بَ بِ بُ", "ba_header", "letter"),
    ("اَبْ اِبْنُ بِنْتُ بَيْتُ بَيْنَ رَيْبُ", "ba_row_1", "word"),
    ("زَيْنَبُ بَرْبَرُ بَيْرَمْ أَبْرَمُ مِنْبَرُ", "ba_row_2", "word"),
    ("بِأَمْرَيْنِ بِبَيْتَيْنِ مِنْبَرَيْنِ زَيْنَبَيْنِ", "ba_row_3", "word"),
    # Kaf bo'limi
    ("كَ كِ كُ", "kaf_header", "letter"),
    ("كَمْ كُمْ كُنْ كَيْ", "kaf_row_1", "word"),
    ("بَكُرُ مَكُرُ كَرَمُ كَنْزُ تَرَكُ", "kaf_row_2", "word"),
    ("كَتَبَ يَكْتُبُ تَرَكَ يَتْرُكُ كَتَبْتُمْ", "kaf_row_3", "word"),
    ("أَمَرَكَ أَمَرْتُكَ كُنْتُ مُمْكِنُ", "kaf_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 7: Lam (ل) + Waw (و)
# (eski sahifa 9)
# ═══════════════════════════════════════════════════
PAGES[7] = [
    # Lam bo'limi
    ("لَ لِ لُ", "lam_header", "letter"),
    ("اَلْ بَلْ لَمْ لُمْ لَنْ كِلْ", "lam_row_1", "word"),
    ("نَزَلَ لَزِمَ كَمُلَ اَنْزَلَ اَلْزَمَ اَكْمَلَ", "lam_row_2", "word"),
    ("اَكَلْتُ اَكَلْنَ اَكَلْتَ اَكَلْتِ اَكَلْتُ اَكَلْتُمْ", "lam_row_3", "word"),
    ("بُلْبُلُ يُلَمْلِمُ تَزَلْزَلَ يَتَزَلْزَلُ مُتَزَلْزِلُ", "lam_row_4", "word"),
    # Waw bo'limi
    ("وَ وِ وُ", "waw_header", "letter"),
    ("اَوْ رَوْ نَوْ لَوْ", "waw_row_1", "word"),
    ("وَرَمْ وَتَرْ وَمَنْ وَلَنْ وَلَمْ وَكَمْ", "waw_row_2", "word"),
    ("اَوَّلُ رُوْمُ يَوْمُ كَوْنُ وَيْلُ وَزْنُ", "waw_row_3", "word"),
    ("كَوْكَبُ مَوْكِبُ اَوْلَمْتُمْ اَوْتَرْتُمْ", "waw_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 8: Ha-ه (ه) + Fa (ف)
# (eski sahifa 10)
# ═══════════════════════════════════════════════════
PAGES[8] = [
    # Ha bo'limi
    ("هَ هِ هُ", "ha_header", "letter"),
    ("هَبْ هَمْ هَلْ هُوَ هِيَ هُمْ زَهْ", "ha_row_1", "word"),
    ("اَهَمْ وَهَبَ لَهَبْ وَهْمْ لَهُمْ بِهِمْ", "ha_row_2", "word"),
    ("مِنْهُ مِنْهُمْ اِلَيْهِ اِلَيْهِمْ اَمْهِلْهُمْ", "ha_row_3", "word"),
    # Fa bo'limi
    ("فَ فِ فُ", "fa_header", "letter"),
    ("فَمْ فَنْ كَفْ فَلَكْ كَفَنْ نَفَرْ", "fa_row_1", "word"),
    ("فَوْرُ فَوْزُ فَهْمُ فِكْرُ زَفَرُ كِفْلُ", "fa_row_2", "word"),
    ("فَلْفَلُ نَوْفَرُ نَوْفَلُ فَهِمَ يَفْهَمُ اِفْهَمْ", "fa_row_3", "word"),
    ("اِفْتَتَنَ يَفْتَتِنُ اِفْتَكَرَ يَفْتَكِرُ", "fa_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 9: Qaf (ق) + Shin (ش)
# (eski sahifa 11)
# ═══════════════════════════════════════════════════
PAGES[9] = [
    # Qaf bo'limi
    ("قَ قِ قُ", "qaf_header", "letter"),
    ("رُقْ قِنْ قُلْ قُمْ قِفْ قِهْ", "qaf_row_1", "word"),
    ("قَلْبُ قُبُلُ فَوْقَ قَلَمْ قَمَرْ لَقَبْ قُمْقُمْ", "qaf_row_2", "word"),
    ("اِقْتَرَبَ يَقْتَرِبُ اِنْقَلَبَ يَنْقَلِبُ", "qaf_row_3", "word"),
    ("كَمَرْ – قَمَرْ، فَلَكْ – فَلَقْ، فَرَكْ – فَرَقْ", "qaf_compare", "sentence"),
    # Shin bo'limi
    ("شَ شِ شُ", "shin_header", "letter"),
    ("رَشْ بُشْ شَرْ شَقْ شَمْ شَكْ", "shin_row_1", "word"),
    ("بَشَرُ شَرِبَ شَهْرُ نَشَرَ شُكْرُ شُرْبُ", "shin_row_2", "word"),
    ("مَشْرَبُ مَشْرِبُ مَشْرِقُ مُشْتَهِرُ مُشْتَرَكُ", "shin_row_3", "word"),
    ("اِشْتَهَرَ يَشْتَهِرُ اِبْرَنْشَقَ يَبْرَنْشِقُ", "shin_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 10: Sin (س) + Tha (ث)
# (eski sahifa 12)
# ═══════════════════════════════════════════════════
PAGES[10] = [
    # Sin bo'limi
    ("سَ سِ سُ", "sin_header", "letter"),
    ("بِسْ سَمْ سِرْ سِنْ سِلْ", "sin_row_1", "word"),
    ("سَفَرْ سَقَرْ سَبَقْ سَلَفْ سَمَكْ فَرَسْ", "sin_row_2", "word"),
    ("مَسْلَكُ مَسْكَنُ مُسْلِمُ مُسْرِفُ سِمْسِمُ", "sin_row_3", "word"),
    ("اَسْلَمَ يُسْلِمُ اِسْتَيْسَرَ يَسْتَيْسِرُ", "sin_row_4", "word"),
    # Tha bo'limi
    ("ثَ ثِ ثُ", "tha_header", "letter"),
    ("بَثْ ثَبْ ثُمْ ثِنْ ثَمَرْ ثَمَنْ", "tha_row_1", "word"),
    ("ثَوْرُ ثَوْبُ ثِيْبُ مِثْلُ مُثْلُ مَثَلْ", "tha_row_2", "word"),
    ("كَوْثَرُ اَكْثَرُ يَكْثُرُ اَثْبَتَ يُثْبِتُ", "tha_row_3", "word"),
    ("اِسْتَكْثَرَ يَسْتَكْثِرُ اِسْتَثْقَلَ يَسْتَثْقِلُ", "tha_row_4", "word"),
    ("سَمَرْ – ثَمَرْ، سَبَتْ – ثَبَتْ، سَلَسْ – ثُلُثْ", "tha_compare", "sentence"),
]

# ═══════════════════════════════════════════════════
# Sahifa 11: Sad (ص) + Ta-ط (ط)
# (eski sahifa 13)
# ═══════════════════════════════════════════════════
PAGES[11] = [
    # Sad bo'limi
    ("صَ صِ صُ", "sad_header", "letter"),
    ("صُمْ صِفْ فَصْ صَرْفُ صَبَرْ بَصَرْ قَصَبْ", "sad_row_1", "word"),
    ("نَصَرَ يَنْصُرُ اِسْتَبْصَرَ يَسْتَبْصِرُ", "sad_row_2", "word"),
    ("سَفَرْ – صَفَرْ، سَيْفُ – صَيْفُ، اِنْتَسَبَ – اِنْتَصَبَ", "sad_compare", "sentence"),
    # Ta-ط bo'limi
    ("طَ طِ طُ", "ta_t_header", "letter"),
    ("طَلْ طَيْ شَطْ بَطْ قَطْ فَقَطْ", "ta_t_row_1", "word"),
    ("وَطَنُ طَلَبَ طَرَفْ طُهْرُ طِفْلُ مَطَرْ", "ta_t_row_2", "word"),
    ("مَطْلَبُ مَسْقَطُ مَوْطِنُ مَرْبِطْ", "ta_t_row_3", "word"),
    ("اِصْطَبَرَ يَصْطَبِرُ اِسْتَوْطَنَ يَسْتَوْطِنُ", "ta_t_row_4", "word"),
    ("تَرَفْ – طَرَفْ، سَبَتْ – سَبَطْ، مُسْتَتِرْ – مُسْتَطِرْ", "ta_t_compare", "sentence"),
]

# ═══════════════════════════════════════════════════
# Sahifa 12: Jim (ج) + Kha (خ)
# (eski sahifa 14)
# ═══════════════════════════════════════════════════
PAGES[12] = [
    # Jim bo'limi
    ("جَ جِ جُ", "jim_header", "letter"),
    ("جَمْ جَرْ جِنْ جَبْ جُلْ", "jim_row_1", "word"),
    ("جَبَلُ جَمَلُ اَجْرُ فَجْرُ جَوْهَرُ جَوْرَبُ", "jim_row_2", "word"),
    ("تَجَوْرَبُ يَتَجَوْرَبُ اِسْتَجْلَبَ يَسْتَجْلِبُ", "jim_row_3", "word"),
    # Kha bo'limi
    ("خَ خِ خُ", "kha_header", "letter"),
    ("خَبْ خَلْ خَرَجَ خَبَرْ خَشَبْ خَلَفْ", "kha_row_1", "word"),
    ("خَيْرُ خَتَمُ خَمْرُ خَوْفُ مَخْرَجُ مُخْبِرُ", "kha_row_2", "word"),
    ("اَخْرَجَ يُخْرِجُ اَخْبَرَ يُخْبِرُ", "kha_row_3", "word"),
    ("اِسْتَخْبَرَ يَسْتَخْبِرُ اِسْتَخْرَجَ يَسْتَخْرِجُ", "kha_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 13: Ha-ح (ح) + Ghayn (غ)
# (eski sahifa 15)
# ═══════════════════════════════════════════════════
PAGES[13] = [
    # Ha-ح bo'limi
    ("حَ حِ حُ", "ha_h_header", "letter"),
    ("حَيْ حِلْ حَجْ حَسَنْ حَسَبْ حَسْفْ", "ha_h_row_1", "word"),
    ("مُحْسِنُ مَحْشَرُ مَنْحَرُ مَحْفَلُ اَحْسَنُ", "ha_h_row_2", "word"),
    ("اِمْتَحَنَ يَمْتَحِنُ اِحْتَمَلَ يَحْتَمِلُ", "ha_h_row_3", "word"),
    ("اِسْتَحْسَنُ يَسْتَحْسِنُ اِحْرَنْجَمُ يَحْرَنْجِمُ", "ha_h_row_4", "word"),
    ("خَلْقْ – حَلْقْ، خَتَمْ – حَتَمْ، اَرْخَمْ – اَرْحَمْ", "ha_h_compare", "sentence"),
    # Ghayn bo'limi
    ("غَ غِ غُ", "ghayn_header", "letter"),
    ("غَمْ غَبْ غِلْ غَيْرُ بَغْلُ فَرْغْ", "ghayn_row_1", "word"),
    ("غَيَّبْ مَبْلَغُ مَغْرِبُ اِغْلِبْ اِغْفِرْ", "ghayn_row_2", "word"),
    ("اِشْتَغَلَ يَشْتَغِلُ اِسْتَغْفَرَ يَسْتَغْفِرُ", "ghayn_row_3", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 14: Ayn (ع) + Dal (د)
# (eski sahifa 16)
# ═══════════════════════════════════════════════════
PAGES[14] = [
    # Ayn bo'limi
    ("عَ عِ عُ", "ayn_header", "letter"),
    ("بِعْ عَنْ عُمْ سُعْ مَعْ عَرَبْ عَجَمْ", "ayn_row_1", "word"),
    ("عَجَبْ عَمَلُ عِلْمُ عُمُرْ جَمْعُ جَعْلُ", "ayn_row_2", "word"),
    ("عِبْعِبْ عَسْكَرُ عِيْلَمُ جَعْفَرُ عَنْبَرُ", "ayn_row_3", "word"),
    ("غَيْنُ – عَيْنُ، بَغْلُ – بَعْلُ، بَلْغُ – بَلْعُ", "ayn_compare", "sentence"),
    # Dal bo'limi
    ("دَ دِ دُ", "dal_header", "letter"),
    ("دُمْ دُبْ دُفْ رِدْ زِدْ تَدْ", "dal_row_1", "word"),
    ("دَرَسُ دَفَعُ دِيْغُ دَلَكُ دَهْرُ دِهْنُ", "dal_row_2", "word"),
    ("دُلْدُلُ فُدْفُدُ هُدْهُدُ اَشْدُدُ", "dal_row_3", "word"),
    ("اِعْتَدَلَ يَعْتَدِلُ اِسْتَرْشَدَ يَسْتَرْشِدُ", "dal_row_4", "word"),
]

# ═══════════════════════════════════════════════════
# Sahifa 15: Dad (ض) + Dhal (ذ)
# (eski sahifa 17)
# ═══════════════════════════════════════════════════
PAGES[15] = [
    # Dad bo'limi
    ("ضَ ضِ ضُ", "dad_header", "letter"),
    ("ضَيْفُ عَضَلُ ضَهَبُ ضَبْطُ ضَعْفُ عَرْضُ", "dad_row_1", "word"),
    ("مَضْرِبُ مِضْرَبُ اِضْرِبْ تَضْرِبُ اَضْرِبُ نَضْرِبُ", "dad_row_2", "word"),
    ("اِضْطَرَبَ يَضْطَرِبُ اِسْتَضْعَفَ يَسْتَضْعِفُ", "dad_row_3", "word"),
    ("دَرَسُ – ضَرَسُ، وَدَعُ – وَضَعُ، بَعْدُ – بَعْضُ", "dad_compare", "sentence"),
    # Dhal bo'limi
    ("ذَ ذِ ذُ", "dhal_header", "letter"),
    ("اِذْ مُذْ خُذْ عُذْ ذَبْ ذُقْ ذَرْ مُنْذُ", "dhal_row_1", "word"),
    ("اَذَنُ بَذَلُ ذِكْرُ ذِهْنُ ذَهَبُ مَذْهَبُ", "dhal_row_2", "word"),
    ("ذَهَلَ يَذْهَلُ بَذَلَ يَبْذُلُ اَذْهَبَ يَذْهَبُ", "dhal_row_3", "word"),
    ("ذَفَرُ – زَفَرُ، بَذَلْ – بَزَلُ، اَبْذُلْ – اَبْزُلْ", "dhal_compare", "sentence"),
]

# ═══════════════════════════════════════════════════
# Sahifa 16: Zha (ظ)
# (eski sahifa 18)
# ═══════════════════════════════════════════════════
PAGES[16] = [
    # Zha bo'limi
    ("ظَ ظِ ظُ", "zha_header", "letter"),
    ("ظَنْ ظَلْ فَظْ حَظْ عَظْ لَظْ", "zha_row_1", "word"),
    ("ظَفَرُ نَظَرُ حَظَرُ ظَمَرُ ظَلَفُ عَظْمُ", "zha_row_2", "word"),
    ("نَظْمُ ظَلَفُ ظَلْفُ حَظْلُ ظُلْمُ ظَهْرُ", "zha_row_3", "word"),
    ("اَظْهَرُ اَظْفَرُ مَظْهَرُ مَنْظَرُ مُظْهِرُ مَظْلَمُ", "zha_row_4", "word"),
    ("ظَهَرَ يَظْهَرُ نَظَرَ يَنْظُرُ ظَلَمَ يَظْلِمُ", "zha_row_5", "word"),
    ("اِنْتَظَمَ يَنْتَظِمُ اِسْتَعْظَمَ يَسْتَعْظِمُ", "zha_row_6", "word"),
    ("ذَفَرَ – ظَفَرَ، حَظَرَ – حَضَرَ، ظَهْرُ – ضَهْرُ", "zha_compare_1", "sentence"),
    ("زَهَرَ – ظَهَرَ، اَزْهَرَ – اَظْهَرَ، اَعْزِمُ – اَعْظِمُ", "zha_compare_2", "sentence"),
]
