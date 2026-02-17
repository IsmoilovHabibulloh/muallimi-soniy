-- Update letter header units with positional forms
-- Each header letter is stored as a separate unit with grid col 0, 1, 2
-- Col 0 = beginning form + fatha: connecting letters get tatweel after
-- Col 1 = middle form + kasra: all letters get tatweel before, connecting also after
-- Col 2 = end form + damma: all letters get tatweel before
--
-- Run:
--   cd /root/muallimi-soniy
--   cat update_headers.sql | docker compose exec -T postgres psql -U muallimi -d muallimi_soniy

-- ═══════════════════════════════════════════
-- CONNECTING LETTERS (col 0: add tatweel after)
-- ب ت ث ج ح خ س ش ص ض ط ظ ع غ ف ق ك ل م ن ه ي
-- ═══════════════════════════════════════════

-- Col 0 (beginning): letter + tatweel + fatha → letterـَ
UPDATE text_units SET text_content = 'بـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'بَ';
UPDATE text_units SET text_content = 'تـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'تَ';
UPDATE text_units SET text_content = 'ثـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'ثَ';
UPDATE text_units SET text_content = 'جـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'جَ';
UPDATE text_units SET text_content = 'حـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'حَ';
UPDATE text_units SET text_content = 'خـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'خَ';
UPDATE text_units SET text_content = 'سـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'سَ';
UPDATE text_units SET text_content = 'شـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'شَ';
UPDATE text_units SET text_content = 'صـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'صَ';
UPDATE text_units SET text_content = 'ضـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'ضَ';
UPDATE text_units SET text_content = 'طـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'طَ';
UPDATE text_units SET text_content = 'ظـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'ظَ';
UPDATE text_units SET text_content = 'عـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'عَ';
UPDATE text_units SET text_content = 'غـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'غَ';
UPDATE text_units SET text_content = 'فـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'فَ';
UPDATE text_units SET text_content = 'قـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'قَ';
UPDATE text_units SET text_content = 'كـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'كَ';
UPDATE text_units SET text_content = 'لـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'لَ';
UPDATE text_units SET text_content = 'مـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'مَ';
UPDATE text_units SET text_content = 'نـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'نَ';
UPDATE text_units SET text_content = 'هـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'هَ';
UPDATE text_units SET text_content = 'يـَ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '0' AND text_content = 'يَ';

-- Col 1 (middle): tatweel + letter + tatweel + kasra → ـletterـِ (connecting)
-- Non-connecting (ز,د,ذ,و): tatweel + letter + kasra → ـletterِ
UPDATE text_units SET text_content = 'ـبـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'بِ';
UPDATE text_units SET text_content = 'ـتـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'تِ';
UPDATE text_units SET text_content = 'ـثـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'ثِ';
UPDATE text_units SET text_content = 'ـجـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'جِ';
UPDATE text_units SET text_content = 'ـحـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'حِ';
UPDATE text_units SET text_content = 'ـخـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'خِ';
UPDATE text_units SET text_content = 'ـسـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'سِ';
UPDATE text_units SET text_content = 'ـشـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'شِ';
UPDATE text_units SET text_content = 'ـصـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'صِ';
UPDATE text_units SET text_content = 'ـضـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'ضِ';
UPDATE text_units SET text_content = 'ـطـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'طِ';
UPDATE text_units SET text_content = 'ـظـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'ظِ';
UPDATE text_units SET text_content = 'ـعـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'عِ';
UPDATE text_units SET text_content = 'ـغـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'غِ';
UPDATE text_units SET text_content = 'ـفـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'فِ';
UPDATE text_units SET text_content = 'ـقـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'قِ';
UPDATE text_units SET text_content = 'ـكـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'كِ';
UPDATE text_units SET text_content = 'ـلـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'لِ';
UPDATE text_units SET text_content = 'ـمـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'مِ';
UPDATE text_units SET text_content = 'ـنـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'نِ';
UPDATE text_units SET text_content = 'ـهـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'هِ';
UPDATE text_units SET text_content = 'ـيـِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'يِ';
-- Non-connecting col 1
UPDATE text_units SET text_content = 'ـزِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'زِ';
UPDATE text_units SET text_content = 'ـدِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'دِ';
UPDATE text_units SET text_content = 'ـذِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'ذِ';
UPDATE text_units SET text_content = 'ـوِ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '1' AND text_content = 'وِ';

-- Col 2 (end): tatweel + letter + damma → ـletterُ (all letters)
UPDATE text_units SET text_content = 'ـبُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'بُ';
UPDATE text_units SET text_content = 'ـتُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'تُ';
UPDATE text_units SET text_content = 'ـثُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'ثُ';
UPDATE text_units SET text_content = 'ـجُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'جُ';
UPDATE text_units SET text_content = 'ـحُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'حُ';
UPDATE text_units SET text_content = 'ـخُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'خُ';
UPDATE text_units SET text_content = 'ـسُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'سُ';
UPDATE text_units SET text_content = 'ـشُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'شُ';
UPDATE text_units SET text_content = 'ـصُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'صُ';
UPDATE text_units SET text_content = 'ـضُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'ضُ';
UPDATE text_units SET text_content = 'ـطُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'طُ';
UPDATE text_units SET text_content = 'ـظُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'ظُ';
UPDATE text_units SET text_content = 'ـعُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'عُ';
UPDATE text_units SET text_content = 'ـغُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'غُ';
UPDATE text_units SET text_content = 'ـفُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'فُ';
UPDATE text_units SET text_content = 'ـقُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'قُ';
UPDATE text_units SET text_content = 'ـكُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'كُ';
UPDATE text_units SET text_content = 'ـلُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'لُ';
UPDATE text_units SET text_content = 'ـمُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'مُ';
UPDATE text_units SET text_content = 'ـنُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'نُ';
UPDATE text_units SET text_content = 'ـهُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'هُ';
UPDATE text_units SET text_content = 'ـيُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'يُ';
-- Non-connecting col 2
UPDATE text_units SET text_content = 'ـزُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'زُ';
UPDATE text_units SET text_content = 'ـدُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'دُ';
UPDATE text_units SET text_content = 'ـذُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'ذُ';
UPDATE text_units SET text_content = 'ـوُ' WHERE metadata::text LIKE '%_header%' AND metadata::jsonb->'grid'->>'col' = '2' AND text_content = 'وُ';
