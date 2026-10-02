# LeitnerSwift — Zorunlu Düzeltmeler Yol Haritası

Bu dosya, her adımın ayrı bir chat oturumunda ve ayrı bir branch'te yapılacağı
şekilde yazıldı. **Bir adıma başlayan oturum önce bu dosyanın tamamını, sonra
kendi adımının bölümünü okumalı.** Adımlar sıralıdır, atlanamaz.

Kapsam: yalnızca **zorunlu** değişiklikler. Opsiyonel iyileştirmeler (Codable /
Sendable uyumları, retired-cards API'si, undo API'si, ReviewPolicy, box 0
önceliklendirmesi, `TimeInterval` → `Int` dönüşümü, actor izolasyonu) bilinçli
olarak kapsam dışıdır.

---

## Durum panosu

Buradaki durum **tek doğru kaynaktır.** Adım bölümlerinde ayrıca durum tutulmaz;
yalnızca bu tablo güncellenir.

| # | Adım | Model | Branch | Repo | Durum |
|---|---|---|---|---|---|
| 1 | Karakterizasyon testleri | Opus 5 | `test/characterization` | LeitnerSwift | ✅ DONE |
| 2 | Crash ve mantık hataları | Sonnet 5 | `fix/crashes-and-logic` | LeitnerSwift | ✅ DONE |
| 3 | `LeitnerError`'ı public yap | Haiku 4.5 | `fix/public-error-type` | LeitnerSwift | ✅ DONE |
| — | **tag `1.3.9`** | — | — | LeitnerSwift | ✅ DONE |
| 4 | Zaman enjeksiyonu | Sonnet 5 | `feat/date-provider` | LeitnerSwift | 🟡 IN PROGRESS |
| 5 | Due API'sini taşı | Sonnet 5 | `feat/due-query-api` | LeitnerSwift | ⬜ TODO |
| — | **tag `1.4.0`** | — | — | LeitnerSwift | ⬜ TODO |
| 6 | Uygulama yeni API'ye geçsin | Sonnet 5 | `refactor/use-library-due-api` | ⚠️ wordlern | ⬜ TODO |
| 7 | B1: zamanlamayı karta taşı | Opus 5 | `fix/card-level-scheduling` | LeitnerSwift | ⬜ TODO |
| — | **tag `1.5.0`** | — | — | LeitnerSwift | ⬜ TODO |
| 8 | Uygulama kart tarihini saklasın | Sonnet 5 | `feat/persist-card-review-date` | ⚠️ wordlern | ⬜ TODO |

Durum değerleri: `⬜ TODO` · `🟡 IN PROGRESS` · `✅ DONE`

`✅ DONE` şu anlama gelir: **branch'te iş bitti ve `swift test` yeşil.**
Merge ve tag işlemlerini kullanıcı yapar, ajan yapmaz.

---

## Çalışma protokolü — her oturum buna uyar

1. Bu dosyanın tamamını oku (özellikle aşağıdaki `wordlern` bağımlılık tablosunu).
2. Durum panosundaki **ilk `⬜ TODO`** adımı al. Sırayı atlama; önceki adım
   `✅ DONE` değilse dur ve kullanıcıya sor.
3. Adımın branch'ini aç. Panoda o adımı `🟡 IN PROGRESS` yap ve **bunu branch'in
   ilk commit'i olarak at** — böylece paralel çalışan başka bir oturum aynı adıma
   girmez.
4. İşi yap. `swift build` ve `swift test` yeşil olmadan bitmiş sayma.
5. Panoda adımı `✅ DONE` yap, commit et.
6. Kullanıcıya rapor ver: ne değişti, testler ne durumda, merge ve (varsa) tag
   için ne yapması gerekiyor. **Merge ve tag'i sen yapma.**

Bir adımda kapsam dışı bir sorun fark ederseniz düzeltmeyin — kullanıcıya
bildirin. Bu planın değeri her adımın küçük ve tek amaçlı kalmasında.

---

## Arka plan: paket ne yapıyor, asıl hata ne?

`LeitnerSwift`, Leitner spaced-repetition sistemini uygulayan bağımlılıksız bir
SPM kütüphanesi. Kart her zaman box 0'a girer; doğru cevap bir sonraki kutuya
taşır, yanlış cevap box 0'a geri gönderir, son kutuda doğru cevap kartı sistemden
tamamen çıkarır (retire).

Zamanlama bugün **kutu seviyesinde**: her `Box`'ın bir `lastReviewedDate`'i var ve
`nextReviewDate = lastReviewedDate + reviewInterval` gün. Asıl hata (B1) burada:
bir kart yeni kutusuna taşındığında **o kutunun eski tarihini miras alıyor**.
Hedef kutu geçmişte review edilmişse kart taşındığı anda tekrar "due" olur — yani
kullanıcı kartı doğru bildiği hâlde aynı saniyede kart tekrar önüne gelir.
Spaced repetition'ın tüm amacı budur. Çözüm: zamanlamayı karta taşımak (Adım 7).

Default review aralıkları: `[0, 3, 7, 14, 30, 60]` gün, 6. kutudan sonra son
değer ikiye katlanarak uzatılır. Box 0'ın aralığı `0`, yani her zaman due —
bu **bilinçli** ve korunacak.

---

## Tüketici uygulama: `wordlern`

Paketi `/Users/fatihsaglam/Developer/wordlern` (Xcode projesi `thousand`)
kullanıyor, şu an `1.3.8`'e pinli. **Paket değişiklikleri bu uygulamayı
bozmamalı.** Kütüphane tarafında çalışan her oturum aşağıdaki bağımlılıkları
bilmek zorunda:

| Uygulamanın dayandığı şey | Nerede | Kural |
|---|---|---|
| `Card(id:word:)`, `Word(word:languageCode:meaning:exampleSentence:)`, `Box(cards:reviewInterval:lastReviewedDate:)` init imzaları | `SwiftDataCardStore`, `DemoContent`, `WordViewModel` | Yeni parametre **yalnızca sona ve default'lu** eklenebilir |
| `loadBoxes(boxes:)` ile undo — tüm box dizisinin snapshot'ı alınıp geri yükleniyor | `WordViewModel.undoLastAnswer()` | Snapshot → geri yükleme bire bir aynı durumu vermeli |
| `allBoxes`, `cardCountsPerBox` | progress / mastered / retired sayıları | Kutu üyeliğine dayanır, due'ya dayanmaz |
| `dueForReview(limit: 10)` — **throw eden** sürüm, `do/catch` içinde | `WordViewModel.fetchNextSet()` | İmzası ve throw davranışı **korunacak** |
| Box 0'ın `reviewInterval == 0` olması (her gün due) | `DemoContent` yorumları | Değiştirilmeyecek |
| `dueForReview`'ün kutuları **sondan başa** gezmesi (yüksek kutu önce) | `DemoContent.sessionBoxIndex = 1` | Değiştirilmeyecek |
| Default aralıkların `0,3,7,14,30` olması (kullanıcıya gösteriliyor) | `HowItWorksScreen` | Değiştirilmeyecek |
| Kütüphane tiplerine **hiçbir protokol uyumu eklenmemiş** (sadece `forPreview()` factory'leri) | — | Doğrulandı; ama yine de yeni uyum eklenmeyecek (kapsam dışı) |
| `StoredCard` kart tarihini **saklamıyor** | `SwiftDataCardStore` | Adım 8'de değişecek |

Uygulama ayrıca kütüphanenin due mantığını **kendi içinde kopyalamış**
(`WordViewModel` → `dueCount`, `nextReviewDate`, `nextReview`) ve bu kopya
widget'ı + hatırlatma bildirimlerini besliyor. Adım 7 due hesabını kart bazına
indirdiğinde bu kopya yanlışlar, bu yüzden **Adım 6 Adım 7'den önce** gelir.

---

## Sürüm ve merge akışı

```
Adım 1-3  → LeitnerSwift main → tag 1.3.9
Adım 4-5  → LeitnerSwift main → tag 1.4.0
Adım 6    → wordlern main (bağımlılığı 1.4.0'a çek)
Adım 7    → LeitnerSwift main → tag 1.5.0
Adım 8    → wordlern main (bağımlılığı 1.5.0'a çek)
```

Her adım: kendi branch'i → yerelde `swift build` + `swift test` → main'e merge.
Tag atlanırsa uygulama değişiklikleri görmez (`Package.resolved` revision'a pinli).

---

## Adım 1 — Karakterizasyon testleri

- **Branch:** `test/characterization`
- **Model:** Opus 5
- **Repo:** LeitnerSwift

`Sources/` altında **tek satır değişiklik yok.** Amaç bugünkü davranışı aynen
pinlemek, çünkü Adım 7'nin doğruluğunun kanıtı bu testler olacak.

Pinlenecek davranışlar:
1. Yeni eklenen kart anında due olur.
2. Box 0 (`interval 0`) her zaman due; yanlış cevaplanan kart aynı gün tekrar due olur.
3. `dueForReview` kutuları sondan başa gezer (yüksek kutu önce), `limit` uygular.
4. `dueForReview` hiç due kart yokken **throw eder**.
5. Son kutuda doğru cevap → kart sistemden çıkar; `cardCountsPerBox` buna göre azalır.
6. `allBoxes` snapshot'ı alınıp `loadBoxes` ile geri yüklenince sistem tam olarak eski hâline döner (uygulamanın undo'su bu).
7. `DemoContent` kurulumunun aynısı: 5 kutu, biri `-(interval+1)` gün geriye tarihli (due), diğerleri bugün (due değil) → yalnızca geriye tarihli kutu ve box 0 due sayılır.
8. Default aralıklar `[0,3,7,14,30]`; 7 kutu için `[0,3,7,14,30,60,120]`.

Mevcut testlere dokunma, yeni dosya olarak ekle
(`Tests/LeitnerSwiftTests/CharacterizationTests.swift`).

**Bitti sayılır:** yeni testlerin hepsi **mevcut kodda** geçiyor. Geçmeyen bir
test yazdıysan ya testi yanlış yazdın ya da bir bug buldun — bug ise Adım 2'ye
devret, bu adımda kaynak kodu düzeltme.

---

## Adım 2 — Crash ve mantık hataları

- **Branch:** `fix/crashes-and-logic`
- **Model:** Sonnet 5
- **Repo:** LeitnerSwift

Beşi de `Sources/LeitnerSwift/LeitnerSystem.swift` içinde, hepsi küçük ve
davranışı başka hiçbir yerde değiştirmemeli. Her biri için regresyon testi yaz.

| Hata | Mevcut durum | Düzeltme |
|---|---|---|
| **B2** | `dueForReview(limit: -1)` → `Fatal error: Can't take a prefix of negative length` | `prefix(max(0, limit))` |
| **B3** | `loadBoxes(boxes: [])` sonrası `addCard` → `Fatal error: Index out of range` | `loadBoxes`'a `guard !boxes.isEmpty else { return }`; `addCard` ve `updateCard`'a da boş-dizi koruması |
| **B4** | Son kutudaki kart retire edilirken `return`, alt satırdaki `updateLastReviewedDateIfNeeded(for:)` çağrısını atlıyor → son kutunun tarihi hiç güncellenmiyor, kutu kalıcı due kalıyor | `return` öncesi tarihi güncelle |
| **B5** | Aynı kart iki kez `addCard` edilince kart iki kutuda birden yaşıyor (`updateCard` ilk eşleşmede durur) | `addCard` idempotent olsun: aynı `id` sistemde varsa no-op |
| **B7** | `LeitnerSystem(boxAmount: 70)` → aritmetik overflow crash (`intervals.last! * 2` taşıyor) | Aralığı sınırla, ör. `min(last * 2, 365)` |

**Dikkat:** B7'nin düzeltmesi 7 kutuya kadar olan aralıkları
(`0,3,7,14,30,60,120`) değiştirmemeli — Adım 1'deki test bunu koruyor.

**Bitti sayılır:** Adım 1'in testleri dahil tüm testler geçiyor, beş yeni
regresyon testi var.

---

## Adım 3 — `LeitnerError`'ı public yap

- **Branch:** `fix/public-error-type`
- **Model:** Haiku 4.5
- **Repo:** LeitnerSwift

`LeitnerError` şu an `internal`, ama `public` olan `updateCard` ve `dueForReview`
bu hatayı fırlatıyor. Sonuç: kütüphane kullanıcısı `catch LeitnerError.cardNotFound`
yazamıyor, sadece genel `Error` yakalayabiliyor — hata yönetimi pratikte kullanılamaz.

1. `public enum LeitnerError: Error, Equatable` yap.
2. `Tests/LeitnerSwiftTests/LeitnerFlowTest.swift` sonundaki
   `extension LeitnerError: Equatable` bloğunu **sil** (artık çift uyum olur, derleme hatası verir).
3. `updateCard`'ın doküman yorumundaki `"This is passed as an inout parameter"`
   ifadesini sil — parametre `inout` değil.
4. `README.md`'deki `Card(id:question:answer:)` örneği derlenmiyor; gerçek API
   `Card(id:word:)` + `Word(...)`. Düzelt. Bağımlılık örneğindeki `from: "1.3.7"`
   → `"1.3.9"`.

**Bitti sayılır:** tüm testler geçiyor, README örneği gerçek API ile uyumlu.

> **Merge sonrası: `1.3.9` tag'i at.**

---

## Adım 4 — Zaman enjeksiyonu

- **Branch:** `feat/date-provider`
- **Model:** Sonnet 5
- **Repo:** LeitnerSwift

Adım 7'nin testlerini yazmanın tek yolu. Kod bugün her yerde `Date()` çağırıyor,
bu yüzden "kart 3 gün sonra gerçekten geri geliyor mu" test edilemiyor.

```swift
public init(boxAmount: UInt = 5, dateProvider: @escaping () -> Date = { Date() })
```

Default'lu parametre olduğu için `LeitnerSystem()` ve
`LeitnerSystem(boxAmount: 5)` aynen derlenir — source-compatible.
`LeitnerSystem` içindeki **tüm** `Date()` çağrılarını `dateProvider()` ile
değiştir (`init`'teki `lastReviewedDate` dahil, `updateLastReviewedDateIfNeeded`,
`dueForReview`'deki `today`).

`Box.nextReviewDate` içindeki `Date()` fallback'ine dokunma — `Box` bir değer
tipi, provider'ı yok.

**Bitti sayılır:** tüm testler geçiyor; zamanı ileri saran en az bir yeni test var
(ör. sahte provider ile kutunun 3 gün sonra due olduğunu doğrulayan).

---

## Adım 5 — Due API'sini kütüphaneye taşı (davranış **aynı**)

- **Branch:** `feat/due-query-api`
- **Model:** Sonnet 5
- **Repo:** LeitnerSwift

Uygulama bu hesapları kendi içinde kopyalamış durumda. Önce kütüphaneye, **bugünkü
kutu-bazlı mantıkla birebir aynı sonucu verecek şekilde** taşıyoruz. Semantiği
Adım 7 değiştirecek; uygulama o zaman tek satır değiştirmeyecek.

```swift
public func dueCount(asOf date: Date) -> Int   // o tarihte due olan kart sayısı
public var dueCount: Int { dueCount(asOf: dateProvider()) }
public var nextDueDate: Date?                  // kart içeren kutular arasında en erken nextReviewDate; dueCount > 0 ise nil
```

Referans — uygulamanın bugün yaptığı hesap (`WordViewModel`), birebir aynısı olmalı:

```swift
// dueCount
let today = Calendar.current.startOfDay(for: Date())
allBoxes.reduce(0) { $1.cards.isEmpty ? $0 :
    (Calendar.current.startOfDay(for: $1.nextReviewDate) <= today ? $0 + $1.cards.count : $0) }

// nextDueDate
guard dueCount == 0 else { return nil }
return allBoxes.filter { !$0.cards.isEmpty }.map(\.nextReviewDate).min()
```

Mevcut `dueForReview(limit:)`'e **dokunma** — imzası, throw davranışı, sıralaması
aynı kalacak. Deprecate de etme.

**Bitti sayılır:** yeni API'nin uygulamanın mevcut hesabıyla aynı sonucu verdiğini
gösteren testler var (`DemoContent` kurulumu dahil), tüm testler geçiyor.

> **Merge sonrası: `1.4.0` tag'i at.**

---

## Adım 6 — Uygulama yeni API'ye geçsin (davranış **aynı**)

- **Branch:** `refactor/use-library-due-api`
- **Model:** Sonnet 5
- **Repo:** `wordlern` ⚠️ (LeitnerSwift değil)

Bağımlılığı `1.4.0`'a çek. Sonra `thousand/Card/WordViewModel.swift` içindeki
kopya due mantığını sil ve kütüphane API'sine devret:

- `var dueCount: Int` → `leitnerSystem.dueCount`
- `var nextReviewDate: Date?` → `leitnerSystem.nextDueDate`
- `var nextReview: NextReview?` → tarihi `nextDueDate`'den, sayıyı
  `leitnerSystem.dueCount(asOf: date)`'ten al

`progress`, `retiredCount`, `masteredWordCount`, `currentBoxNumber`'a **dokunma** —
bunlar kutu üyeliğine dayanır, due'ya dayanmaz, Adım 7'den etkilenmezler.

Bu saf bir refactor: üç mülk de bugünle bit-bit aynı sonucu vermeli.

**Bitti sayılır:** uygulama derleniyor, `thousandTests` geçiyor, widget ve
hatırlatma bildirimi davranışı değişmemiş.
**Neden şimdi:** Adım 7 due hesabını kart bazına indirdiğinde bu kopya yanlışlardı —
widget "12 kelime hazır" der, seans 3 kart verirdi; bildirim ise hiç kurulmazdı.

---

## Adım 7 — B1: zamanlamayı karta taşı (asıl düzeltme)

- **Branch:** `fix/card-level-scheduling`
- **Model:** Opus 5
- **Repo:** LeitnerSwift

Bu planın tek davranış değiştiren adımı ve en dikkat gerektireni. Source-breaking
**değil**.

**7.1 — `Card`'a tarih alanı (sona, default'lu — imza uyumu şart):**
```swift
public struct Card {
    public let id: UUID
    public let word: Word
    public internal(set) var lastReviewedDate: Date?   // nil = hiç review edilmedi
    public init(id: UUID = UUID(), word: Word, lastReviewedDate: Date? = nil)
}
```

**7.2 — `updateCard`:** kartı taşırken (ileri, geri, her durumda)
`lastReviewedDate = dateProvider()` damgala.

**7.3 — `loadBoxes` geriye uyum damgalaması (planın kilit taşı):**
yüklenen kartlardan `lastReviewedDate == nil` olanlara **kendi kutusunun**
`lastReviewedDate`'ini yaz. Böylece migrasyon yapılmamış veri (uygulamanın
`StoredCard`'ı tarihi henüz saklamıyor) bugünkü davranışı **aynen** sürdürür.

**7.4 — Due kontrolü kart bazında:**
- `lastReviewedDate == nil` → due (yeni eklenen kartlar).
- Aksi hâlde due ⇔ `startOfDay(card.lastReviewedDate) + box.reviewInterval gün <= startOfDay(bugün)`.
- Box 0'ın `interval`'i `0` kalıyor → yanlış cevaplanan kart aynı gün tekrar due
  olmaya devam eder. **Bu bilinçli, değiştirme.**
- `dueForReview`'ün kutu sırası (sondan başa) ve `limit` davranışı **aynı kalacak**.

**7.5 —** Adım 5'teki `dueCount(asOf:)` ve `nextDueDate`'i de kart bazına geçir
(`nextDueDate` artık kartların kendi due tarihlerinin minimumu).

`Box.lastReviewedDate` ve `Box.nextReviewDate` **kalsın** — geriye uyum için
gerekli ve 7.3 onları kullanıyor.

**Doğrulama — Adım 1'in karakterizasyon testlerinden hangileri değişir:**
Yalnızca "yeni kutusuna taşınan kart erken geri geliyor" davranışını pinleyen
testler değişmeli. Özellikle şunlar **aynen geçmeye devam etmeli**:
yeni kart anında due · box 0 aynı gün tekrar · `dueForReview` sıralaması ve
`limit`'i · boşken throw etmesi · retire davranışı · **undo (snapshot → `loadBoxes`)** ·
`DemoContent` kurulumu (session box due, box 3-5 due değil, box 0 due).
Bunlardan biri kırılıyorsa tasarımda bir şey yanlış — testi değiştirerek geçme.

**Yeni test (asıl kanıt):** `dateProvider` ile — box 0'daki kart doğru cevaplanıp
box 1'e (interval 3) taşınır; hedef kutunun `lastReviewedDate`'i 10 gün geriye
tarihlidir. Kart **bugün due olmamalı**, 3 gün sonra due olmalı. Bu senaryo
bugünkü kodda kartı anında due yapıyor — B1 tam olarak bu.

> **Merge sonrası: `1.5.0` tag'i at.**

---

## Adım 8 — Uygulama kart tarihini saklasın

- **Branch:** `feat/persist-card-review-date`
- **Model:** Sonnet 5
- **Repo:** `wordlern` ⚠️ (LeitnerSwift değil)

Bu adım yapılmazsa uygulama **bozulmaz** ama Adım 7'nin faydasını da **görmez**:
her açılışta kart tarihleri `nil` gelir ve kutu tarihinden damgalanır, yani eski
davranışta kalır. Zincirin kullanıcıya ulaşması için gerekli.

`thousand/Persistence/SwiftDataCardStore.swift`:
1. `StoredCard`'a `lastReviewedDate: Date?` ekle (SwiftData'da optional attribute →
   hafif migrasyon, custom `MigrationPlan` gerekmez).
2. `CardSnapshot`'a alanı ekle, `saveBoxes` içinde `card.lastReviewedDate`'i geçir
   ve mevcut kayıt güncellenirken tarih değişimini de yaz (şu an yalnızca
   `boxIndex` güncelleniyor).
3. `StoredCard.toCard()` → `Card(id:word:lastReviewedDate:)`.

**Bitti sayılır:** uygulama derleniyor, `thousandTests` geçiyor; bir kartı doğru
cevaplayıp uygulamayı yeniden başlatınca kartın **erken geri gelmediği** elle
doğrulanmış.

---

## Bitiş durumu

Tamamlandığında: üç crash yolu kapalı, dört mantık hatası düzeltilmiş, public
hata tipi kullanılabilir, zamanlama kart bazında — yani paket gerçek bir spaced
repetition sistemi gibi davranıyor. API kırılmadı, uygulama her adımda çalışır
durumda kaldı.

Kapsam dışı bırakılan tek **işlevsel** konu: `dueForReview`'ün kutuları sondan
başa gezmesi, `limit` ile birleşince box 0'ı açlığa mahkum edebiliyor (yüksek
kutularda çok kart due ise, her gün çalışılması gereken box 0 sıraya hiç girmez).
Adım 7 bu baskıyı büyük ölçüde azaltır — due kümesi artık gerçekten "bugün due
olanlar" olur — ama sıralama sorunu teknik olarak durur. İleride ele alınabilir.
