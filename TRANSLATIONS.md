# Translations

ShareBox ships its Wi-Fi network name and home pages (home, "How it works",
status) in the languages below. How the files work and how to add a language:
[`docs/i18n.md`](docs/i18n.md).

Except English, every translation was produced by AI and has **not been
reviewed by a native speaker yet**. A language moves to "Reviewed" once a
fluent speaker has read `recipes-core/sharebox-config/files/i18n/strings/<code>.txt`
(and ideally the rendered pages on a phone). To review, edit the strings
file, run `scripts/gen-i18n-pages.sh`, commit the result and update the row
below with your name or handle.

The SSID is `ShareBox - <slogan>` and must fit in 32 bytes of UTF-8. When it
does not, no `ssid-<code>.txt` is shipped and the box uses the English SSID
(`ShareBox - Share Freely`) for that language; its pages stay translated.

| Language | Code | Dir | SSID | Fits 32 bytes | Review status |
| --- | --- | --- | --- | --- | --- |
| English (English) | `en` | ltr | `ShareBox - Share Freely` | yes (23 bytes) | Reference |
| Chinese (Simplified) (简体中文) | `zh-Hans` | ltr | `ShareBox - 自由分享` | yes (23 bytes) | AI-generated, needs human review |
| Chinese (Traditional) (繁體中文) | `zh-Hant` | ltr | `ShareBox - 自由分享` | yes (23 bytes) | AI-generated, needs human review |
| Hindi (हिन्दी) | `hi` | ltr | `ShareBox - बाँटें!` | yes (30 bytes) | AI-generated, needs human review |
| Spanish (Español) | `es` | ltr | `ShareBox - Comparte libremente` | yes (30 bytes) | AI-generated, needs human review |
| French (Français) | `fr` | ltr | `ShareBox - Partagez librement` | yes (29 bytes) | AI-generated, needs human review |
| Arabic (العربية) | `ar` | rtl | `ShareBox - شارك بحرية` | yes (30 bytes) | AI-generated, needs human review |
| Bengali (বাংলা) | `bn` | ltr | `ShareBox - শেয়ার!` | yes (30 bytes) | AI-generated, needs human review |
| Portuguese (Português) | `pt` | ltr | `ShareBox - Compartilhe com todos` | yes (32 bytes) | AI-generated, needs human review |
| Russian (Русский) | `ru` | ltr | `ShareBox - Делитесь!` | yes (28 bytes) | AI-generated, needs human review |
| Urdu (اردو) | `ur` | rtl | `ShareBox - شیئر کریں` | yes (28 bytes) | AI-generated, needs human review |
| Indonesian (Bahasa Indonesia) | `id` | ltr | `ShareBox - Bebas Berbagi` | yes (24 bytes) | AI-generated, needs human review |
| German (Deutsch) | `de` | ltr | `ShareBox - Frei teilen` | yes (22 bytes) | AI-generated, needs human review |
| Japanese (日本語) | `ja` | ltr | `ShareBox - 自由にシェア` | yes (29 bytes) | AI-generated, needs human review |
| Marathi (मराठी) | `mr` | ltr | `ShareBox - वाटा!` | yes (24 bytes) | AI-generated, needs human review |
| Telugu (తెలుగు) | `te` | ltr | `ShareBox - పంచండి` | yes (29 bytes) | AI-generated, needs human review |
| Turkish (Türkçe) | `tr` | ltr | `ShareBox - Özgürce Paylaş` | yes (28 bytes) | AI-generated, needs human review |
| Tamil (தமிழ்) | `ta` | ltr | `ShareBox - பகிர்க` | yes (29 bytes) | AI-generated, needs human review |
| Vietnamese (Tiếng Việt) | `vi` | ltr | `ShareBox - Chia sẻ tự do` | yes (28 bytes) | AI-generated, needs human review |
| Filipino (Filipino) | `fil` | ltr | `ShareBox - Magbahagi nang malaya` | yes (32 bytes) | AI-generated, needs human review |
| Korean (한국어) | `ko` | ltr | `ShareBox - 자유롭게 공유` | yes (30 bytes) | AI-generated, needs human review |
| Persian (فارسی) | `fa` | rtl | `ShareBox - اشتراک آزاد` | yes (32 bytes) | AI-generated, needs human review |
| Hausa (Hausa) | `ha` | ltr | `ShareBox - Raba cikin 'yanci` | yes (28 bytes) | AI-generated, needs human review |
| Swahili (Kiswahili) | `sw` | ltr | `ShareBox - Shiriki kwa uhuru` | yes (28 bytes) | AI-generated, needs human review |
| Javanese (Basa Jawa) | `jv` | ltr | `ShareBox - Bebas Andum` | yes (22 bytes) | AI-generated, needs human review |
| Italian (Italiano) | `it` | ltr | `ShareBox - Condividi liberamente` | yes (32 bytes) | AI-generated, needs human review |
| Punjabi (ਪੰਜਾਬੀ) | `pa` | ltr | `ShareBox - ਸਾਂਝਾ ਕਰੋ` | **no** (36 bytes): English SSID used | AI-generated, needs human review |
| Gujarati (ગુજરાતી) | `gu` | ltr | `ShareBox - શેર કરો` | yes (30 bytes) | AI-generated, needs human review |
| Thai (ไทย) | `th` | ltr | `ShareBox - แชร์กัน` | yes (32 bytes) | AI-generated, needs human review |
| Kannada (ಕನ್ನಡ) | `kn` | ltr | `ShareBox - ಹಂಚಿರಿ` | yes (29 bytes) | AI-generated, needs human review |
| Amharic (አማርኛ) | `am` | ltr | `ShareBox - በነጻ ያጋሩ` | yes (30 bytes) | AI-generated, needs human review |
| Polish (Polski) | `pl` | ltr | `ShareBox - Dziel się swobodnie` | yes (31 bytes) | AI-generated, needs human review |
| Yoruba (Yorùbá) | `yo` | ltr | `ShareBox - Pín ní òmìnira` | yes (29 bytes) | AI-generated, needs human review |
| Malayalam (മലയാളം) | `ml` | ltr | `ShareBox - പങ്കിടൂ` | yes (32 bytes) | AI-generated, needs human review |
| Burmese (မြန်မာ) | `my` | ltr | `ShareBox - မျှဝေပါ` | yes (32 bytes) | AI-generated, needs human review |
| Ukrainian (Українська) | `uk` | ltr | `ShareBox - Діліться!` | yes (28 bytes) | AI-generated, needs human review |
| Dutch (Nederlands) | `nl` | ltr | `ShareBox - Deel vrijuit` | yes (23 bytes) | AI-generated, needs human review |
| Malay (Bahasa Melayu) | `ms` | ltr | `ShareBox - Bebas Berkongsi` | yes (26 bytes) | AI-generated, needs human review |
| Romanian (Română) | `ro` | ltr | `ShareBox - Partajează liber` | yes (28 bytes) | AI-generated, needs human review |
| Uzbek (Oʻzbekcha) | `uz` | ltr | `ShareBox - Erkin ulashing` | yes (25 bytes) | AI-generated, needs human review |
| Pashto (پښتو) | `ps` | rtl | `ShareBox - آزاد شریکول` | yes (32 bytes) | AI-generated, needs human review |

## SSID falling back to English

| Code | Slogan | Why |
| --- | --- | --- |
| `pa` | ਸਾਂਝਾ ਕਰੋ ("share") | 25 bytes, limit is 21. ਸਾਂਝ ਪਾਓ is 22. ਵੰਡੋ fits but means "divide" (Partition connotation), ਵੰਡ ਛਕੋ fits but is a religious principle. A native speaker may find a short slogan. |

## Slogans shortened to fit

The literal "Share freely" did not fit in these languages; the slogan was
shortened or rephrased. A reviewer may find a better short form.

| Code | Slogan | Meaning |
| --- | --- | --- |
| `pt` | Compartilhe com todos | "Share with everyone" ("Compartilhe livremente" is 22 bytes) |
| `ru` | Делитесь! | "Share!" |
| `uk` | Діліться! | "Share!" |
| `hi` | बाँटें! | "Share!" |
| `bn` | শেয়ার! | "Share!" (ভাগ করুন is 22 bytes) |
| `mr` | वाटा! | "Share out!" (शेअर करा is 22 bytes) |
| `te` | పంచండి | "Distribute" (పంచుకోండి is too long) |
| `ta` | பகிர்க | "Share" (polite) |
| `gu` | શેર કરો | "Share" |
| `kn` | ಹಂಚಿರಿ | "Distribute" (ಹಂಚಿಕೊಳ್ಳಿ is too long) |
| `ml` | പങ്കിടൂ | "Share!" |
| `ur` | شیئر کریں | "Share" |
| `th` | แชร์กัน | "Let's share" |
| `my` | မျှဝေပါ | "Please share" |
| `fa` | اشتراک آزاد | "Free sharing" (pages use هم‌رسانی, which does not fit) |
| `ps` | آزاد شریکول | "Free sharing" |

## Points for reviewers

- Word for the device ("box"): languages chose a local word (caja, caixa,
  скринька, kisanduku, ဘောက်စ်, بکس...) or "Box"; Russian uses устройство
  ("device"), Polish urządzenie. Check it sounds natural.
- `zh-Hans` uses WLAN (as Android in China); `zh-Hant` uses Taiwan wording.
- `id` uses everyday loanwords (download, upload, update) rather than unduh,
  unggah, pembaruan.
- `pt` uses Brazilian forms (celular, baixar, arquivos, pen drive).
- `it`, `ro`, `fr` contain masculine forms for "connected".
- `ha` uses the Nigerian spelling 'yanci (plain apostrophe).
- Least confident files, to review first: `jv`, `ps`, `my`, `yo` (tone marks),
  `ha`, `am`.
- RTL pages (`ar`, `fa`, `ur`, `ps`): check the order of Latin words and
  addresses on a real phone.
