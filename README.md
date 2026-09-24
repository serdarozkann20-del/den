# AI Studio: Godot 4.7 için yapay zekâ asistanı ve ajan eklentisi

AI Studio, Godot editörünün içinde çalışan bir yapay zekâ eklentisidir. Bir modelle projeniz hakkında sohbet edersiniz. **Agent** modunda model, sizin izninizle projeniz üzerinde **gerçek işlem yapan araçlar** kullanır:

- sahne kurar;
- betik yazar ve derleyip kontrol eder;
- animasyonları düzeltir;
- import ayarlarını değiştirir;
- projeyi export eder;
- editörden çalıştırdığınız oyunu canlı olarak inceler ve yönetir.

Kendi API anahtarınızla çalışır. Desteklenen sağlayıcılar: OpenAI, Anthropic (Claude), Google Gemini, Nous Portal (Hermes), OpenRouter, **9Router**, Hermes Agent proxy, Ollama, LM Studio ve OpenAI uyumlu her uç nokta. **MCP** sunucularını da bağlayabilirsiniz; Hermes Agent için hazır ayarlar vardır.

> **Özet**
> - **183** yerleşik araç; varsayılan olarak modele **89** tanesi gösterilir.
> - **110** çalışma zamanı oyun komutu ve istediğiniz kadar MCP aracı.
> - Hepsi GDScript ile yazılmıştır. Node.js, Python veya ek sunucu gerekmez.
> - Hedef sürüm: **Godot 4.7+** (4.7.2-stable ile test edildi).

---

## İçindekiler

- [Öne çıkan özellikler](#öne-çıkan-özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Hızlı başlangıç (5 dakika)](#hızlı-başlangıç-5-dakika)
- [Arayüz](#arayüz)
  - [Chat sekmesi](#chat-sekmesi)
  - [Model sekmesi](#model-sekmesi)
  - [MCP sekmesi](#mcp-sekmesi)
  - [Tools sekmesi](#tools-sekmesi)
  - [Help sekmesi](#help-sekmesi)
- [Sağlayıcılar ve modeller](#sağlayıcılar-ve-modeller)
  - [9Router ve combo adları](#9router-ve-combo-adları)
  - [Otomatik geri çekilmeler (fallback)](#otomatik-geri-çekilmeler-fallback)
- [Ajan nasıl çalışır](#ajan-nasıl-çalışır)
  - [Editör bağlamı](#editör-bağlamı)
  - [Onay (izin) sistemi](#onay-izin-sistemi)
  - [Güvenlik kuralları](#güvenlik-kuralları)
- [Araç referansı](#araç-referansı)
- [Oyun köprüsü](#oyun-köprüsü)
- [MCP sunucuları](#mcp-sunucuları)
- [Ayarlar](#ayarlar)
- [Projeye özel ayarlar: `.ai_studio.json`](#projeye-özel-ayarlar-ai_studiojson)
- [Dosyaların saklandığı yerler](#dosyaların-saklandığı-yerler)
- [Ortam değişkenleri](#ortam-değişkenleri)
- [Kurulumu doğrulama (smoke test)](#kurulumu-doğrulama-smoke-test)
- [Örnek istekler ve iş akışları](#örnek-istekler-ve-iş-akışları)
- [Sorun giderme](#sorun-giderme)
- [Dosya yapısı](#dosya-yapısı)
- [Bu sürümdeki değişiklikler](#bu-sürümdeki-değişiklikler)
- [Lisans ve teşekkür](#lisans-ve-teşekkür)

---

## Öne çıkan özellikler

**Sohbet ve ajan**
- Editöre gömülü bir dock içinde akışlı (streaming) sohbet. Markdown ve kod blokları görüntülenir; modelin düşünme (reasoning) çıktısı açılıp kapanabilir.
- İki mod:
  - **Agent**: model araç kullanır.
  - **Chat**: yalnızca konuşma.
- Her araç çağrısı sohbette bir **araç kartı** olarak görünür: argümanlar, sonuç, hata.
- Değişiklik yapan araçlar için **izin kartları**: *Approve*, *Approve all this turn*, *Deny*.
- Mesaj başına araç adımı sınırı (varsayılan 12, en fazla 50), durdurma düğmesi (*Stop*) ve token kullanımı göstergesi.
- Konuşmalar otomatik kaydedilir ve **Markdown olarak dışa aktarılabilir**.
- Açık sahne ağacı, seçili node'lar, açık betik ve istenirse proje ayarları her isteğe otomatik bağlam olarak eklenir.

**Godot araçları (183)**
- **İnceleme**:
  - proje özeti, sahne ağacı, seçim, editör durumu, node ayrıntıları, proje ayarları;
  - **motorun kendi ClassDB'sinden sınıf referansı**; model API uydurmak yerine buna bakar;
  - editör ekran görüntüsü.
- **Dosyalar**: okuma, listeleme, arama (içerikte grep dahil), yazma (`.bak` yedeğiyle), taşıma, kopyalama, silme. Taşımada `.import` ve `.uid` dosyaları korunur.
- **Açık sahne**: node ekleme, silme, yeniden adlandırma, özellik ayarlama, sahne örnekleme, betik bağlama. Hepsi **Ctrl+Z ile geri alınabilir**.
- **Diskteki sahne dosyaları**: `.tscn` dosyalarını açmadan okuma ve düzenleme, node taşıma/çoğaltma/sıralama, kalıcı sinyal bağlantıları, MeshLibrary export.
- **Rig ve animasyon**:
  - kemik listesi, humanoid **BoneMap** üretimi (Mixamo, Rigify, Unreal...);
  - animasyon retarget;
  - bozuk track tespiti;
  - animasyon ve kütüphane **yeniden adlandırma ile tüm referansları güncelleme** (betiklerdeki `play("...")` çağrıları, AnimationTree durumları, AnimatedSprite);
  - animasyonları yerinde düzeltme;
  - **`.glb`/`.fbx` içindeki animasyon adlarını kalıcı olarak düzeltme**: yeniden içe aktarmada kaybolmaz.
- **3D**: mesh inceleme, materyal oluşturma/atama, fizik gövdesi ile otomatik boyutlu çarpışma şekli, kamera, tek adımda ışık + gökyüzü + ortam kurulumu.
- **Kaynaklar**: herhangi bir Resource sınıfını oluşturma, okuma, değiştirme (Theme öğeleri dahil), UID yönetimi.
- **Betikler**: GDScript'i **motorun derleyicisiyle** doğrulama (değişen dosyalar veya tümü), GDScript/C# betik ve shader oluşturma.
- **Proje**: proje ayarları, ana sahne, autoload'lar, input map, katman adları, eklentiler, çeviriler.
- **Export**: preset yönetimi, headless export, GitHub Actions/Dockerfile üretimi.
- **Editör**: tek seferlik **editör betiği çalıştırma** (her zaman onaylı) ve **editör hata/uyarı günlüğü** okuma.
- **Oyun köprüsü (110 komut)**: editörden çalışan oyunun canlı sahne ağacını okuma, özellik değiştirme, metot çağırma, GDScript eval, tıklama/tuş/fare/dokunma/gamepad simülasyonu, ekran görüntüsü, log ve hatalar, performans, fizik sorguları, ses, kamera, UI, ağ ve daha fazlası.

**MCP**
- stdio ve Streamable HTTP (SSE destekli) taşıma katmanları.
- Sunucu başına otomatik onay, araç izin/engel listeleri.
- Sunucudan gelen `sampling/createMessage` isteklerini yanıtlama.
- Hermes Agent için hazır ayarlar.
- Proje dosyasıyla gelen sunucular **ancak siz güvenmeyi seçerseniz** başlar.

**Güvenlik**
- API anahtarları proje klasörüne asla yazılmaz (`user://ai_studio/config.cfg`); ortam değişkenleri önceliklidir.
- Dosya araçları `res://` dışına çıkamaz. Eklentinin kendi klasörüne yazamaz ve kendini devre dışı bırakamaz.
- Oyun köprüsü yalnızca editörden başlatılan oyunlarda, `127.0.0.1` üzerinde ve oturum başına rastgele bir token ile çalışır. Export edilen oyunları etkilemez.

---

## Gereksinimler

- **Godot 4.7 veya üstü** (standart ya da .NET sürümü). Eklenti 4.7 API'lerini kullanır, eski sürümlerde yüklenmez.
- En az bir model sağlayıcısı: bir bulut API anahtarı ya da yerel bir sunucu (Ollama, LM Studio, 9Router...).
- **Agent modu** için **araç çağırmayı (tool/function calling) destekleyen** bir model. Desteklemeyen modeller yalnızca sohbet eder.
- İsteğe bağlı:
  - MCP sunucuları için ilgili komutlar (`npx`, `uvx`, `hermes`...);
  - export için Godot export şablonları.

## Kurulum

1. Bu depodaki `addons/ai_studio` klasörünü projenize `<proje>/addons/ai_studio` olarak kopyalayın.
2. Godot'da **Project → Project Settings → Plugins** bölümünden **AI Studio**'yu etkinleştirin.
3. Editörün sağ tarafında **AI Studio** dock'u açılır.

> Eklenti yalnızca `addons/ai_studio/plugin.cfg` konumundan yüklenir. Eklenti listesinde görünmüyorsa klasör bir seviye fazla iç içe kopyalanmıştır. Doğru yol `<proje>/addons/ai_studio/plugin.cfg` olmalıdır.

## Hızlı başlangıç (5 dakika)

1. **Model** sekmesinde bir sağlayıcı seçin (ör. *Anthropic*, *OpenAI*, *OpenRouter*, *9Router*).
2. API anahtarını yapıştırın. *Get a key* bağlantısı sağlayıcının anahtar sayfasını açar. Anahtar bir ortam değişkeninde varsa otomatik kullanılır.
3. **Refresh models** ile model listesini çekin ve bir model seçin. Listede olmayan bir model kimliğini de yazıp **Enter** veya **Use typed model** ile kaydedebilirsiniz.
4. **Test** düğmesine basın. `OK` yanıtı anahtarın, adresin ve modelin çalıştığını gösterir.
5. **Chat** sekmesine geçin. Modun **Agent** olduğundan emin olun ve bir şey isteyin, örneğin:
   - "Bu projeyi incele ve yapısını özetle."
   - "Açık sahneye zemin, ışık ve bir oyuncu kamerası ekle."
   - "`scripts/` klasöründeki tüm betikleri derleyip hataları düzelt."
6. Model bir değişiklik yapmak istediğinde bir **izin kartı** çıkar. *Approve*, *Approve all this turn* veya *Deny* seçin.

---

## Arayüz

Dock beş sekmeden oluşur. Son açık sekme hatırlanır.

### Chat sekmesi

| Öğe | İşlev |
|---|---|
| **Agent / Chat** | Mod seçimi. *Agent* modunda model araç kullanır; *Chat* modunda yalnızca konuşur. |
| **New** | Yeni konuşma başlatır. Eskisi kaydedilir (kaydetme açıksa). |
| **Export** | Konuşmayı Markdown dosyası olarak dışa aktarır. |
| **Settings** | Model/ayar sekmesine gider. |
| **Attach editor context** | Açıkken her mesaja editör bağlamı eklenir: sahne ağacı, seçim, açık betik... |
| **Send** (Ctrl+Enter) | Mesajı gönderir. |
| **Stop** | Akışı ve araç döngüsünü hemen durdurur. |
| Düşünme (reasoning) bölümü | Modelin düşünme çıktısını destekleyen modellerde katlanabilir bir bölüm olarak gösterir. |
| Araç kartları | Her araç çağrısını adı ve argümanlarıyla gösterir. Sonuç ve hata metni açılıp kapanabilir (`ui/show_tool_cards`). |
| İzin kartları | Onay gerektiren çağrılar için *Approve* / *Approve all this turn* / *Deny*. |
| Durum satırı | Token kullanımı, bağlantı durumu, fallback bildirimleri ve adım sınırına ulaşıldığında bir uyarı. |

### Model sekmesi

| Öğe | İşlev |
|---|---|
| **Model provider** | Sağlayıcı seçimi (bkz. [Sağlayıcılar](#sağlayıcılar-ve-modeller)). Her sağlayıcının anahtarı, adresi ve modeli ayrı saklanır. |
| **API key** + *Get a key* | Anahtar alanı. Kullanılan anahtarın kaynağı (ortam değişkeni veya yapılandırma) gösterilir. |
| **Base URL** + *Apply* | Uç nokta adresi. Yolu olmayan adreslere otomatik `/v1` eklenir ve düzeltilmiş değer gösterilir. |
| **Model ID** + *Use typed model* | Serbest metin model alanı. Router takma adları ve combo adları gibi listede olmayan kimlikler de kaydedilebilir (Enter, odak kaybı veya düğme ile). |
| **Refresh models** | Anahtarınızın erişebildiği modelleri sağlayıcıdan çeker. |
| **Test** | Kısa bir istekle anahtarı, adresi ve modeli dener. |
| **Agent behaviour** | Akış, onaylar, bağlam, kaydetme ve oyun araçları seçenekleri (bkz. [Ayarlar](#ayarlar)). |
| **Max tool steps per message** | Bir mesajda en fazla kaç araç adımı atılacağı (1–50). |
| **Request timeout (seconds)** | İstek zaman aşımı. |
| **System prompt** + *Save* / *Reset to default* | Sistem istemini düzenler veya varsayılana döndürür. |
| **Clear stored API keys** | Yapılandırma dosyasındaki tüm anahtarları siler. |

### MCP sekmesi

| Öğe | İşlev |
|---|---|
| **Add server** | Yeni sunucu ekler. Menüde boş stdio/HTTP şablonları ve **Hermes Agent (stdio: `hermes mcp serve`)** ile **Hermes Agent (HTTP endpoint)** hazır ayarları bulunur. |
| Sunucu kartı | Etkin/devre dışı, taşıma türü (stdio: komut, argümanlar, env, çalışma klasörü, *shell wrap*; HTTP: URL, başlıklar), araç izin/engel listesi, **auto-approve**, notlar. |
| **Connect all / Disconnect all / Reload tools** | Tüm sunuculara bağlanır, bağlantıları keser veya araç listelerini yeniden yükler. |
| **Sampling** | Sunucuların modelden tamamlama istemesine (`sampling/createMessage`) izin verir. Kapalıyken bu istekler hatayla yanıtlanır. |
| **Trust this project's servers** | `res://.ai_studio.json` içinde tanımlı sunucuların başlamasına izin verir. Varsayılan olarak kapalıdır. |
| Sunucu günlükleri | Her sunucunun stderr/bağlantı günlüğü. |

### Tools sekmesi

Tüm yerleşik araçları listeleyen **elle çalıştırma** paneli:

- Listede her aracın yanında **[read-only]** ya da **[asks]** etiketi vardır.
- Bir araç seçildiğinde açıklaması ve parametre şeması görünür.
- Argümanlar JSON olarak yazılır ve **Run** ile çalıştırılır. Sonuç panelde görünür.

Modeli devreye sokmadan bir aracı denemek veya hata ayıklamak için idealdir. Örneğin `godot_scene_tree` için `{"max_depth": 3}`.

### Help sekmesi

Model seçimi, Agent/Chat modları, izinler, MCP ve oyun köprüsü hakkında editör içi kısa kılavuz.

---

## Sağlayıcılar ve modeller

| Sağlayıcı | Protokol | Varsayılan adres | Anahtar ortam değişkenleri |
|---|---|---|---|
| OpenAI | `openai` | `https://api.openai.com/v1` | `OPENAI_API_KEY`, `AI_STUDIO_OPENAI_API_KEY` |
| Anthropic (Claude) | `anthropic` | `https://api.anthropic.com/v1` | `ANTHROPIC_API_KEY`, `AI_STUDIO_ANTHROPIC_API_KEY` |
| Google Gemini (yerel API) | `gemini` | `https://generativelanguage.googleapis.com/v1beta` | `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `AI_STUDIO_GEMINI_API_KEY` |
| Google Gemini (OpenAI uyumlu) | `openai` | `.../v1beta/openai` | `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `AI_STUDIO_GEMINI_API_KEY` |
| Nous Portal (Hermes modelleri) | `openai` | `https://inference-api.nousresearch.com/v1` | `NOUS_API_KEY`, `NOUS_PORTAL_API_KEY`, `AI_STUDIO_NOUS_API_KEY` |
| OpenRouter | `openai` | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY`, `AI_STUDIO_OPENROUTER_API_KEY` |
| **9Router (yerel ağ geçidi)** | `openai` | `http://localhost:20128/v1` | `NINE_ROUTER_API_KEY`, `ROUTER_API_KEY`, `AI_STUDIO_9ROUTER_API_KEY` |
| Hermes Agent (yerel abonelik proxy'si) | `openai` | `http://127.0.0.1:8645/v1` | anahtar gerekmez |
| Ollama | `openai` | `http://127.0.0.1:11434/v1` | anahtar gerekmez |
| LM Studio | `openai` | `http://127.0.0.1:1234/v1` | anahtar gerekmez |
| Özel (OpenAI uyumlu) | `openai` | `http://127.0.0.1:8000/v1` | `AI_STUDIO_CUSTOM_API_KEY` |

- Ortam değişkenindeki anahtar her zaman yapılandırma dosyasındakinden önce gelir.
- Her sağlayıcının anahtarı, adresi, seçili modeli ve ek HTTP başlıkları ayrı saklanır. Sağlayıcı değiştirince ayarlarınız kaybolmaz.
- Ayrıntılar: [`addons/ai_studio/docs/providers.md`](addons/ai_studio/docs/providers.md).

### 9Router ve combo adları

[9Router](https://github.com/decolua/9router), yedekleme zincirleri ("combo") destekleyen, kendi sunucunuzda çalışan OpenAI uyumlu bir ağ geçididir.

1. **Model → Provider → 9Router (local gateway)** seçin. Adres `http://localhost:20128/v1` olarak dolar; `http://localhost:20128` yazmanız da yeterlidir, `/v1` otomatik eklenir.
2. 9Router panelindeki anahtarı yapıştırın.
3. **Model ID** alanına yönlendirilmiş bir model (`kr/claude-sonnet-4.5`) ya da **combo adınızı** (`premium-coding`, `free-combo`...) yazıp **Enter**'a basın. Ardından **Test** edin.
4. *Refresh models*, ağ geçidinin bildirdiği modelleri ve combo'ları listeler. Listede olmayan bir combo da yazılarak kullanılabilir.

Aynı şeyi **Custom (OpenAI-compatible)** sağlayıcısıyla da yapabilirsiniz: aynı adres, anahtar ve model olarak combo adı.

### Otomatik geri çekilmeler (fallback)

Bazı ağ geçitleri veya modeller isteğin belirli alanlarını reddeder. AI Studio bu durumda isteği o alan olmadan otomatik yeniden dener ve bu tercihi **sağlayıcı başına hatırlar**, böylece hata yalnızca bir kez yaşanır:

| Hata | Ne yapılır |
|---|---|
| `HTTP 400 ... stream_options` | `stream_options.include_usage` olmadan yeniden denenir. |
| `HTTP 400 ... tools` | Araçlar olmadan yeniden denenir; model sohbet moduna düşer. Agent modu için araç destekleyen bir model seçin. |
| `HTTP 400 ... temperature` | `temperature` gönderilmeden yeniden denenir. |

Durum satırı bir fallback uygulandığında bunu bildirir.

---

## Ajan nasıl çalışır

Agent modunda her mesaj için şu döngü işler:

1. Sistem istemi, editör bağlamı, konuşma geçmişi ve **araç tanımları** modele gönderilir.
2. Model yanıt verir. Yanıtta araç çağrıları varsa her biri için:
   - onay gerekiyorsa bir izin kartı gösterilir ve kararınız beklenir;
   - araç çalıştırılır ve sonucu (`ok`, `text`, `error`) modele geri gönderilir.
3. Model araç çağırmayı bırakana veya **Max tool steps per message** sınırına ulaşılana kadar döngü sürer. Sınıra ulaşılınca durum satırı bunu bildirir; "devam et" yazarak kaldığı yerden sürdürebilirsiniz.

Araç sonuçları, bağlamı şişirmemek için uzunsa kısaltılır (`ui/max_context_lines` ve araç içi sınırlar). Model gerektiğinde ayrıntıyı başka bir araçla ister.

### Editör bağlamı

**Attach editor context** açıkken her isteğe kısa bir "editörde şu an ne oluyor" bloğu eklenir:

- düzenlenen sahne ve onun ağacı (`include_scene_context`);
- seçili node'lar ve temel özellikleri (`include_selection`);
- script editöründe açık betik;
- istenirse proje ayarları (`include_project_settings`, büyük olabilir, varsayılan kapalı).

Blok kasıtlı olarak kısa tutulur. Ayrıntıyı model araçlarla ister.

### Onay (izin) sistemi

| Araç türü | Davranış |
|---|---|
| **Salt okunur** yerleşik araçlar (✅) | Onaysız çalışır (`auto_approve_safe_tools`). |
| **Değişiklik yapan** araçlar (✋) | İzin kartı çıkar (`confirm_mutations`). Ayar kapatılırsa sormadan çalışır. |
| **Duruma göre** araçlar (🔀) | Argümana göre karar verilir. Örneğin `dry_run=true` ile önizleme onaysız, uygulama onaylıdır. `game_command` için okuma/girdi komutları onaysız, diğerleri onaylıdır. |
| **Her zaman onaylı** araçlar (⚠️) | `godot_run_editor_script`. Hiçbir ayar bu onayı kapatamaz. |
| **MCP araçları** | `approve_mcp_tools` açıkken onay ister. Sunucu kartında *auto-approve* işaretliyse o sunucunun araçları sormadan çalışır. |

İzin kartındaki seçenekler:

- **Approve**: yalnızca bu çağrıyı onaylar.
- **Approve all this turn**: bu mesajın geri kalanındaki tüm çağrıları onaylar. "Her zaman onaylı" araçlar yine sorar.
- **Deny**: çağrıyı reddeder. Model bunu bir hata sonucu olarak görür ve başka yol dener.

> Onay ayarları (`confirm_mutations`, `approve_mcp_tools`, `auto_approve_safe_tools`) **proje dosyasıyla değiştirilemez**. Yalnızca kendi editörünüzden ayarlanabilir.

### Güvenlik kuralları

- **Dosya sınırları**:
  - dosya araçları yalnızca `res://` içinde çalışır; `..` ile dışarı çıkılamaz;
  - yazma yalnızca metin formatlarında ve boyut sınırıyla yapılır;
  - var olan dosyanın yanına `.bak` yedeği bırakılır.
- **Eklenti koruması**: `res://addons/ai_studio` içine yazılamaz. AI Studio `godot_manage_plugins` ile kendini kapatamaz.
- **Silme**: silinen dosyalar mümkünse işletim sisteminin çöp kutusuna gider.
- **Geri alma**: açık sahnedeki değişiklikler Undo/Redo geçmişine eklenir. Toplu animasyon değişiklikleri **tek bir** geri alma adımıdır.
- **Referans güncelleme yedekleri**: animasyon referansları başka dosyalarda değiştirildiğinde orijinaller `user://ai_studio/backups/refs_<zaman>/` altına kopyalanır.
- **Kaydedilmemiş sahneler**: diskteki sahne dosyası araçları, editörde açık ve kaydedilmemiş değişiklikleri olan bir sahneye dokunmaz.
- **Oyun köprüsü**:
  - yalnızca editörden başlatılan oyunlarda çalışır;
  - `127.0.0.1` üzerinde dinler;
  - oturum başına rastgele bir token ister;
  - export edilen oyunlarda autoload kendini hemen kaldırır.
- **Proje MCP sunucuları**: siz *Trust this project's servers* seçeneğini işaretlemeden başlamaz.
- **API anahtarları**:
  - asla proje klasörüne yazılmaz;
  - `store_keys_in_config` kapatılırsa hiç diske yazılmaz, yalnızca ortam değişkenlerinden okunur;
  - anahtar içeren yapılandırma dosyası Unix'te `chmod 600` ile korunur.


## Araç referansı

Toplam **183** yerleşik araç vardır. Varsayılan olarak modele **89** tanesi gösterilir. Kalan **94** oyun komutuna `game_commands` / `game_command` üzerinden erişilir, istenirse ayrı ayrı araç olarak da açılabilir. MCP sunucularının araçları bunlara eklenir.

Her aracın altında şunlar yer alır:

- izin durumu:
  - ✅ salt okunur;
  - ✋ onay ister;
  - 🔀 argümana göre değişir;
  - ⚠️ her zaman onay ister;
- Türkçe açıklama;
- parametre tablosu.

Parametre açıklamaları, modele gönderilen koddaki tanımın aynısıdır, bu yüzden İngilizce bırakılmıştır. Tablolar koddan otomatik üretildi.


### Kategori özeti

| Kategori | Araç sayısı | Araçlar |
|---|---|---|
| [Bağlam ve inceleme](#bağlam-ve-inceleme) | 8 | `godot_project_info`, `godot_scene_tree`, `godot_get_selection`, `godot_editor_state`, `godot_get_node`, `godot_project_settings`, `godot_class_reference`, `godot_capture_screenshot` |
| [Dosyalar](#dosyalar) | 6 | `godot_read_file`, `godot_list_dir`, `godot_find_files`, `godot_write_file`, `godot_rescan_filesystem`, `godot_manage_files` |
| [Açık sahneyi düzenleme (geri alınabilir)](#açık-sahneyi-düzenleme-geri-alınabilir) | 6 | `godot_add_node`, `godot_rename_node`, `godot_remove_node`, `godot_set_node_property`, `godot_instantiate_scene`, `godot_attach_script` |
| [Editörde gezinme ve oynatma](#editörde-gezinme-ve-oynatma) | 4 | `godot_open_scene`, `godot_save_scenes`, `godot_play_scene`, `godot_stop_playing` |
| [İskelet ve rig](#iskelet-ve-rig) | 2 | `godot_list_bones`, `godot_create_bone_map` |
| [Animasyon](#animasyon) | 7 | `godot_animation_info`, `godot_animation_tracks`, `godot_retarget_animation`, `godot_animation_rename`, `godot_animation_find_references`, `godot_animation_edit`, `godot_import_animation_names` |
| [3D sahne kurulumu](#3d-sahne-kurulumu) | 6 | `godot_mesh_info`, `godot_create_material`, `godot_set_material`, `godot_add_physics_body`, `godot_add_camera`, `godot_setup_3d_environment` |
| [Import ayarları](#import-ayarları) | 2 | `godot_get_import_settings`, `godot_set_import_settings` |
| [Sahne dosyaları (diskte)](#sahne-dosyaları-diskte) | 9 | `godot_read_scene`, `godot_create_scene`, `godot_scene_add_node`, `godot_scene_modify_node`, `godot_scene_remove_node`, `godot_scene_restructure`, `godot_scene_signals`, `godot_save_scene_as`, `godot_export_mesh_library` |
| [Kaynaklar (Resource) ve UID'ler](#kaynaklar-resource-ve-uidler) | 5 | `godot_create_resource`, `godot_read_resource`, `godot_modify_resource`, `godot_get_uid`, `godot_update_uids` |
| [Betikler ve shader'lar](#betikler-ve-shaderlar) | 3 | `godot_validate_scripts`, `godot_create_script`, `godot_create_shader` |
| [Proje yapılandırması](#proje-yapılandırması) | 7 | `godot_set_project_setting`, `godot_set_main_scene`, `godot_manage_autoloads`, `godot_manage_input_map`, `godot_manage_layers`, `godot_manage_plugins`, `godot_manage_translations` |
| [Export ve CI](#export-ve-ci) | 3 | `godot_manage_export_presets`, `godot_export_project`, `godot_manage_ci` |
| [Editör betiği ve editör günlüğü](#editör-betiği-ve-editör-günlüğü) | 2 | `godot_run_editor_script`, `godot_editor_log` |
| [Oyun köprüsü: günlük kullanılan komutlar](#oyun-köprüsü-günlük-kullanılan-komutlar) | 19 | `godot_game_bridge`, `game_commands`, `game_command`, `game_screenshot`, `game_click`, `game_key_press`, `game_mouse_move`, `game_get_ui`, `game_get_scene_tree`, `game_eval`, `game_get_property`, `game_set_property`, `game_call_method`, `game_get_node_info`, `game_performance`, `game_wait`, `game_input_action`, `game_get_logs`, `game_get_errors` |
| [Oyun köprüsü: tüm komutlar](#oyun-köprüsü-tüm-çalışma-zamanı-komutları) | 94 | varsayılan olarak `game_command` ile |


### Bağlam ve inceleme

Projeyi, açık sahneyi, seçimi ve motor API'sini okuyan araçlar. Hepsi salt okunurdur.

#### `godot_project_info`

✅ **Salt okunur**, onaysız çalışır.

Projenin genel görünümü: motor sürümü, proje adı, ana sahne, ayar özeti, üst düzey klasörler, sahne ve betik sayıları, autoload'lar ve input action'ları. Modelin projeyi tanımak için genelde ilk çağırdığı araçtır.

_Parametre almaz._

#### `godot_scene_tree`

✅ **Salt okunur**, onaysız çalışır.

Editörde açık olan sahnenin node ağacını verir: node türleri, adları, bağlı betikler ve seçili node işaretleri. `max_depth` ile derinlik sınırlanabilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `max_depth` | integer |  | `8` | How deep to descend (default 8, max 32). |

#### `godot_get_selection`

✅ **Salt okunur**, onaysız çalışır.

Editörde o an seçili node'ları ve bunların önemli özelliklerini listeler. "Seçtiğim node'u düzelt" gibi isteklerde kullanılır.

_Parametre almaz._

#### `godot_editor_state`

✅ **Salt okunur**, onaysız çalışır.

Editörün durumu: düzenlenen sahne, açık sahneler, kaydedilmemiş sahneler, FileSystem panelinde seçili dosyalar ve oyunun çalışıp çalışmadığı.

_Parametre almaz._

#### `godot_get_node`

✅ **Salt okunur**, onaysız çalışır.

Tek bir node'un ayrıntıları: sınıfı, betiği, özellik değerleri, bağlantılarıyla sinyalleri ve çocuklarının adları.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Path relative to the edited scene root, e.g. 'Player/Sprite2D'. Empty = the scene root. |
| `include_properties` | boolean |  | `true` | Include full property list (can be long). |

#### `godot_project_settings`

✅ **Salt okunur**, onaysız çalışır.

ProjectSettings değerlerini okur. Glob desteği vardır (ör. `display/*`, `input/*`).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `max_results` | integer |  | `60` | Maximum entries (default 60). |
| `pattern` | string |  | `"application/*"` | Glob pattern, default 'application/*'. |

#### `godot_class_reference`

✅ **Salt okunur**, onaysız çalışır.

Çalışan editörün ClassDB'sinden motor sınıf referansı: kalıtım, metotlar, özellikler, sinyaller, sabitler. Model emin olmadığı bir API'ye kod yazmadan önce bunu kullanır; böylece Godot sürümüne uymayan kod yazma riski azalır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `class_name` | string | evet |  | Engine class, e.g. 'CharacterBody2D'. |
| `member` | string |  |  | Optional: only show this method/property/signal/constant. |
| `show_inherited` | boolean |  | `false` | Include inherited members (default false). |

#### `godot_capture_screenshot`

✅ **Salt okunur**, onaysız çalışır.

Editörün 2D/3D görünümünün PNG ekran görüntüsünü alır ve dosya yolunu döndürür. Görsel anlayan modeller için kullanışlıdır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `view` | string |  | `"3d"` | '3d' or '2d'. |


### Dosyalar

`res://` altındaki metin dosyalarını okuma, arama, yazma ve dosya yönetimi.

#### `godot_read_file`

✅ **Salt okunur**, onaysız çalışır.

Projedeki bir metin dosyasını okur (`res://`). Satır aralığı desteklenir; çok büyük dosyalar kısaltılır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `path` | string | evet |  | res:// path, e.g. 'res://scripts/player.gd'. |
| `line_count` | integer |  | `0` | How many lines to return (default 0 = all). |
| `start_line` | integer |  | `1` | First line (1-based, default 1). |

#### `godot_list_dir`

✅ **Salt okunur**, onaysız çalışır.

Bir proje klasöründeki dosya ve klasörleri listeler; istenirse alt klasörlere de iner.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `path` | string |  | `"res://"` | res:// directory (default 'res://'). |
| `recursive` | boolean |  | `false` | Descend into subfolders (default false). |

#### `godot_find_files`

✅ **Salt okunur**, onaysız çalışır.

Dosyaları ad veya yol desenine göre, istenirse içerdikleri metne göre (grep gibi) bulur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `pattern` | string | evet |  | Glob for the path, e.g. '*.gd' or 'scenes/**/*.tscn'. |
| `contains` | string |  |  | Optional text that the file must contain. |
| `max_results` | integer |  | `60` | Maximum results (default 60). |

#### `godot_write_file`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Projede bir metin dosyası oluşturur veya üzerine yazar (yalnızca `res://`, yalnızca metin formatları, boyut sınırlı). Var olan dosyanın yanına `.bak` yedeği bırakır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `content` | string | evet |  | Full new file content. |
| `path` | string | evet |  | res:// path to write. |

#### `godot_rescan_filesystem`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Editörden dosya sistemini yeniden taramasını ister. Dosyalar editör dışında üretildiğinde işe yarar.

_Parametre almaz._

#### `godot_manage_files`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Proje içinde dosya siler, taşır/yeniden adlandırır, kopyalar veya klasör oluşturur. Taşırken `.import` ve `.uid` yan dosyalarını da taşır, böylece referanslar bozulmaz. Silinen dosyalar mümkünse sistem çöp kutusuna gider.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `delete` / `move` / `copy` / `mkdir` | evet |  | What to do. |
| `path` | string | evet |  | res:// source file (or the folder for mkdir). |
| `new_path` | string |  |  | move/copy: res:// destination. |


### Açık sahneyi düzenleme (geri alınabilir)

Editörde açık olan sahne üzerinde çalışır. Her değişiklik editörün Undo/Redo geçmişine eklenir, Ctrl+Z ile geri alınabilir.

#### `godot_add_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahneye node ekler (geri alınabilir). Üst node yolu, sınıf adı, isteğe bağlı ad ve başlangıç özellikleri verilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `parent_path` | string | evet |  | Parent path relative to the scene root; '' or '.' means the root. |
| `type` | string | evet |  | Engine class, e.g. 'Node2D', 'Sprite2D', 'Label'. |
| `name` | string |  |  | Node name (optional). |
| `properties` | object |  |  | Optional properties to set, e.g. {"position": "Vector2(100, 50)"} |

#### `godot_rename_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahnedeki bir node'u yeniden adlandırır (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `new_name` | string | evet |  | New node name. |
| `node_path` | string | evet |  | Node path relative to the scene root. |

#### `godot_remove_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahneden bir node'u çocuklarıyla birlikte siler (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Node path relative to the scene root. |

#### `godot_set_node_property`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahnedeki bir node'un özelliğini ayarlar (geri alınabilir). Değerler Godot sabiti olarak ayrıştırılır: `Vector2(10, 20)`, `true`, `3.5`, `"metin"` hepsi çalışır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Node path relative to the scene root. |
| `property` | string | evet |  | Property name, e.g. 'position' or 'text'. |
| `value` | string | evet |  | New value as a Godot literal or JSON. |

#### `godot_instantiate_scene`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir `.tscn` sahnesini açık sahnedeki bir node'un çocuğu olarak örnekler (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `parent_path` | string | evet |  | Parent node path relative to the scene root ('' = root). |
| `scene_path` | string | evet |  | res:// path to the .tscn/.scn file. |
| `name` | string |  |  | Optional instance name. |

#### `godot_attach_script`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Gerekirse bir GDScript dosyası oluşturur ve açık sahnedeki bir node'a bağlar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Node path relative to the scene root. |
| `script_path` | string | evet |  | res:// path of the .gd file, e.g. 'res://scripts/player.gd'. |
| `content` | string |  |  | Script source. If empty and the file exists, the existing script is attached. |


### Editörde gezinme ve oynatma

Sahne/betik açma, kaydetme, oyunu başlatma ve durdurma.

#### `godot_open_scene`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Editörde bir sahne açar; istenirse bir betiği de script editöründe belirli bir satırda açar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string | evet |  | res:// path of the scene. |
| `line` | integer |  | `0` | Line to jump to (1-based). |
| `script_path` | string |  |  | Optional res:// path of a script to open. |

#### `godot_save_scenes`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahneyi, istenirse tüm açık sahneleri kaydeder.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `all` | boolean |  | `false` | Save every open scene instead of only the edited one. |

#### `godot_play_scene`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahneyi editörden çalıştırır (oyunu başlatır). Yol boş bırakılırsa düzenlenen sahne çalışır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string |  |  | Optional res:// path of the scene to run. |

#### `godot_stop_playing`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Çalışan oyunu durdurur.

_Parametre almaz._


### İskelet ve rig

Kemikleri inceleme ve humanoid BoneMap üretme.

#### `godot_list_bones`

✅ **Salt okunur**, onaysız çalışır.

Bir iskeletin tüm kemiklerini listeler: indeks, ad, üst kemik, rest transform ve istenirse SkeletonProfileHumanoid'deki karşılığı. Düzenlenen sahnede veya herhangi bir `res://` sahne/modelde (.tscn, .glb, .fbx, .blend...) çalışır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `classify` | boolean |  | `false` | Also report the humanoid profile bone each bone most likely corresponds to. |
| `include_rest` | boolean |  | `true` | Include the rest position/rotation of each bone. |
| `skeleton_node` | string |  |  | Path of the Skeleton3D inside that scene (default: the first one found). |
| `source` | string |  |  | res:// scene or model to inspect (default: the edited scene). |

#### `godot_create_bone_map`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir iskeleti SkeletonProfileHumanoid'e eşleyen bir BoneMap kaynağı (`.tres`) oluşturur. Eşleme, kemik adı sezgileriyle yapılır (Mixamo, Blender/Rigify, Unreal, Godot humanoid, genel). İstenirse modelin `.import` dosyasına `retarget/bone_map` yazar; böylece Godot animasyonları otomatik retarget eder.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `output_path` | string | evet |  | Where to save the BoneMap, e.g. res://models/hero_bonemap.tres. |
| `extra_aliases` | object |  |  | {ProfileBone: 'alias1, alias2'} extra name aliases. |
| `manual` | object |  |  | {ProfileBone: skeleton bone name} overrides for the heuristic matching. |
| `profile` | string |  |  | 'humanoid' (default) or a res:// path to a custom SkeletonProfile. |
| `rest_fixer` | boolean |  | `true` | With write_import, also enable retarget/rest_fixer. |
| `skeleton_node` | string |  |  | Path of the Skeleton3D (default: the first one found). |
| `source` | string |  |  | res:// scene/model that contains the skeleton (default: the edited scene). |
| `write_import` | boolean |  | `false` | Also set retarget/bone_map in the model's .import file. |


### Animasyon

Animasyonları inceleme, retarget etme, yeniden adlandırma ve yerinde düzenleme. İçe aktarılan modellerdeki animasyon adlarını kalıcı olarak düzeltme.

#### `godot_animation_info`

✅ **Salt okunur**, onaysız çalışır.

Bir sahnedeki ya da animasyon kaynağı/kütüphanesindeki animasyonlara genel bakış: her AnimationPlayer, kütüphaneleri, animasyonları, uzunluk, döngü modu ve track sayıları.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string |  |  | Only inspect this AnimationPlayer (default: all of them). |
| `source` | string |  |  | res:// scene, .res/.tres Animation or AnimationLibrary (default: the edited scene). |

#### `godot_animation_tracks`

✅ **Salt okunur**, onaysız çalışır.

Bir animasyonun track'lerini listeler (yol, tür, anahtar sayısı) ve her track yolunu bir sahneye karşı kontrol eder: var olmayan node ve kemikleri raporlar. Retarget edilmiş bir animasyonun neden hiçbir şey oynatmadığını bu araç açıklar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `animation` | string | evet |  | Animation name to inspect. |
| `check_against` | string |  |  | Scene/model used for the path check (default: 'source'). |
| `names_only` | boolean |  | `false` | Return just the track paths, no diagnostics. |
| `node_path` | string |  |  | AnimationPlayer node path (default: the first one). |
| `source` | string |  |  | res:// scene the animation lives in or targets (default: the edited scene). |

#### `godot_retarget_animation`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir animasyonu başka bir iskelette oynayacak şekilde yeniden yazar: node yolu ön ekini değiştirir ve/veya kemik adlarını hedef rig'e çevirir (BoneMap ile ya da hedef iskeletin kemik adlarını humanoid profil üzerinden eşleyerek). Yeni bir Animation kaynağı kaydeder, orijinale dokunmaz.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `animation` | string | evet |  | Animation name inside the player/library. |
| `animation_path` | string |  |  | res:// .res/.tres animation, or the AnimationLibrary to take it from. |
| `bone_map_path` | string |  |  | BoneMap (.tres) describing the TARGET skeleton; bone names are translated through it. |
| `dry_run` | boolean |  | `false` | Report the changes without writing a file. |
| `extra_aliases` | object |  |  | {ProfileBone: 'alias1, alias2'} extra name aliases. |
| `from_prefix` | string |  |  | Node path prefix used by the animation, e.g. 'Skeleton3D' or 'Armature/Skeleton3D'. |
| `node_path` | string |  |  | AnimationPlayer node path inside that scene. |
| `output_path` | string |  |  | Where to save the retargeted Animation (default: <animation>_retargeted.tres). |
| `source` | string |  |  | Scene to read the animation from (used when animation_path is empty). |
| `target_skeleton` | string |  |  | Skeleton3D path inside target_source. |
| `target_source` | string |  |  | Scene/model containing the TARGET skeleton (alternative to bone_map_path). |
| `to_prefix` | string |  |  | Replacement prefix, e.g. 'Armature/Skeleton3D'. |

#### `godot_animation_rename`

🔀 **Duruma göre**: `dry_run=true` iken salt okunur (önizleme), aksi halde onay ister.

Animasyonları ya da animasyon kütüphanelerini yeniden adlandırır. AnimationPlayer/AnimationTree, AnimationLibrary dosyası veya SpriteFrames (AnimatedSprite2D/3D) üzerinde çalışır.

Yeniden adlandırma yolları:

- `renames`: kesin eşleme.
- `cleanup: strip_prefix`: `Armature|Run` → `Run`.
- `cleanup: snake_case`: `Armature|Run Fast` → `run_fast`.
- `pattern`/`replacement`: regex.

Geçersiz karakterleri (`/ : , [`) ve mevcut adlarla çakışmaları reddeder. `update_references` açıkken (varsayılan) şunları da günceller:

- aynı sahnede: `autoplay` ve atanmış animasyon, AnimationTree düğümleri (durum makinesi, blend tree, blend space), AnimatedSprite `animation`/`autoplay` özellikleri;
- projenin geri kalanında: betiklerdeki `play("eski")` tarzı kullanımlar ve diğer sahnelerdeki `animation = "eski"` özellikleri.

Eski ad başka bir sahne/kaynakta hâlâ tanımlıysa o dosyaya ve belirsiz betik satırlarına dokunmaz, yalnızca raporlar. Açık sahnedeki değişiklik Ctrl+Z ile geri alınabilir. `.glb`/`.fbx` içindeki adlar için `godot_import_animation_names` kullanılmalıdır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `cleanup` | string: `none` / `strip_prefix` / `snake_case` |  | `"none"` | Automatic clean-up for names without an exact rename: strip_prefix drops everything up to the last '\|' ("Armature\|Run" -> "Run"); snake_case also lowercases and joins words with '_' ("Armature\|Run Fast" -> "run_fast"). |
| `dry_run` | boolean |  | `false` | Only show what would change. |
| `library` | string |  |  | Only this animation library ("" = the default library). Omit for all libraries. |
| `node_path` | string |  |  | Only this AnimationPlayer / AnimationTree / AnimatedSprite node (default: all in the scene). |
| `pattern` | string |  |  | Optional regex applied after cleanup, e.g. "^CharacterArmature_" or "\\s+". |
| `renames` | object |  |  | Exact renames, old -> new, e.g. {"mixamo_com": "run", "Armature\|Take 001": "idle"}. Keys may also be "library/anim". |
| `replacement` | string |  |  | Replacement for 'pattern' ($1 groups allowed; default empty). |
| `source` | string |  |  | Scene (.tscn) or AnimationLibrary / SpriteFrames resource (.tres/.res). Default: the scene open in the editor (undoable). |
| `target` | string: `animations` / `libraries` |  | `"animations"` | Rename animations (default) or the library keys of the players. |
| `update_references` | boolean |  | `true` | Also rewrite the old names elsewhere: autoplay / assigned animation, AnimationTree nodes and AnimatedSprite properties in the scene, and play("old")-style uses in scripts, scenes and resources across the project. |

#### `godot_animation_find_references`

🔀 **Duruma göre**: arama salt okunur, `apply=true` onay ister.

Animasyon adlarının projede nerede kullanıldığını bulur (`res://addons` taranmaz). Her sonucun bir türü vardır:

- `use`: `play`/`queue`/`travel` gibi bir çağrı ya da `animation`/`autoplay` özelliği;
- `maybe`: satırda animasyon anahtar kelimesi olmayan eşleşen bir metin;
- `definition`: kütüphane veya SpriteFrames içindeki tanım;
- `state`: durum makinesi durum adı.

`renames` ve `apply=true` verilirse `use` eşleşmelerini yeni adlara çevirir. Tanımlara ve durum adlarına dokunmaz. Değişen dosyaların yedeği `user://ai_studio/backups/` altına alınır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `any_library` | boolean |  | `false` | Also match the name under any library prefix ("run" matches "moves/run"). |
| `apply` | boolean |  | `false` | Rewrite the matches to the new names from 'renames'. |
| `include_possible` | boolean |  | `false` | When applying, also rewrite 'maybe' matches (a string equal to the name in a line without animation keywords). |
| `names` | array<string> |  |  | Animation names to look for ("run" or "library/run"). Not needed when 'renames' is given. |
| `renames` | object |  |  | Exact renames, old -> new, e.g. {"mixamo_com": "run", "Armature\|Take 001": "idle"}. Keys may also be "library/anim". |

#### `godot_animation_edit`

🔀 **Duruma göre**: `dry_run=true` iken salt okunur, aksi halde onay ister.

Mevcut animasyonları yerinde düzenler (kopya oluşturmaz):

- track yolu ön ekini değiştirir (`Armature/Skeleton3D` → `Skeleton3D`);
- kemik track'lerindeki kemik adlarını değiştirir (kesin eşleme veya regex, ör. `^mixamorig[:_]` kaldırma);
- var olmayan node, kemik, blend shape veya özelliğe işaret eden track'leri ya da regex'e uyan track'leri siler;
- döngü modunu, uzunluğu ve oynatma hızını ayarlar (hız, anahtar zamanlarına işlenir);
- animasyonu aynı oynatıcının başka bir kütüphanesine ya da bir `.tres` AnimationLibrary dosyasına kopyalar veya taşır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `animation` | string | evet |  | Animation name ("run" or "library/run"), or "*" for every animation in scope. |
| `bone_pattern` | string |  |  | Regex applied to bone names in bone tracks, e.g. "^mixamorig[:_]". |
| `bone_renames` | object |  |  | Bone renames in 3D bone tracks, old -> new. |
| `bone_replacement` | string |  |  | Replacement for bone_pattern (default empty). |
| `copy_to` | string |  |  | Copy the animation to this library of the same player (created if missing) or to a res://...tres AnimationLibrary (created if missing). |
| `dry_run` | boolean |  | `false` | Only report what would change. |
| `length` | number |  |  | Set the length in seconds. |
| `library` | string |  |  | Only this library ("" = default). Omit for all. |
| `loop_mode` | string: `none` / `linear` / `pingpong` |  |  | Set the loop mode. |
| `move` | boolean |  | `false` | With copy_to: remove it from the original library (a move). |
| `new_name` | string |  |  | With copy_to: name in the target library (default: same name). |
| `node_path` | string |  |  | Only this AnimationPlayer/AnimationTree (default: all). |
| `overwrite` | boolean |  | `false` | With copy_to: replace an existing animation of that name. |
| `path_prefix_from` | string |  |  | Track-path prefix to replace, e.g. "Armature/Skeleton3D". |
| `path_prefix_to` | string |  |  | New prefix (empty = remove the prefix). |
| `remove_missing_tracks` | boolean |  | `false` | Remove tracks whose node, bone or property does not exist (needs a scene source). |
| `remove_tracks_matching` | string |  |  | Remove tracks whose path matches this regex. |
| `source` | string |  |  | Scene (.tscn) or AnimationLibrary / Animation resource. Default: the scene open in the editor (undoable). |
| `speed` | number |  |  | Playback speed factor baked into the keys (2 = twice as fast; scales key times and length). |

#### `godot_import_animation_names`

🔀 **Duruma göre**: `action=list` salt okunur, diğer eylemler onay ister.

İçe aktarılan bir modelden gelen animasyon adlarını düzeltir (`mixamo.com`, `Armature|Take 001`, `CharacterArmature|Run`...). Bu adları sahnede değiştirmek kalıcı olmaz, çünkü her yeniden içe aktarma onları geri getirir. Eylemler:

- `list`: adları listeler; kural verilirse yeni adları önizler.
- `apply`: kurallarınızı içeren küçük bir `EditorScenePostImport` betiği yazar, modelin import ayarlarına bağlar ve modeli yeniden içe aktarır. Betik önizlemeyle aynı kodu içerdiği için sonuç birebir aynı olur.
- `extract`: yeniden adlandırılmış kopyaları bir AnimationLibrary dosyasına kaydeder. Bu dosya modelden bağımsızdır.
- `remove`: betiğin bağlantısını kaldırır ve betiği çöpe atar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `model` | string | evet |  | res:// path of the imported model (.glb, .gltf, .fbx, .blend, .dae). |
| `action` | string: `list` / `apply` / `extract` / `remove` |  | `"list"` | list: show the animation names (and a preview when rules are given). apply: write a post-import script that renames them on every import, hook it into the model's import settings and reimport. extract: save renamed copies to an AnimationLibrary .tres. remove: unhook and trash the generated script. |
| `cleanup` | string: `none` / `strip_prefix` / `snake_case` |  | `"none"` | Automatic clean-up for names without an exact rename: strip_prefix drops everything up to the last '\|' ("Armature\|Run" -> "Run"); snake_case also lowercases and joins words with '_' ("Armature\|Run Fast" -> "run_fast"). |
| `output` | string |  |  | extract: AnimationLibrary path (default: next to the model, <name>_animations.tres). |
| `pattern` | string |  |  | Optional regex applied after cleanup, e.g. "^CharacterArmature_" or "\\s+". |
| `renames` | object |  |  | Exact renames, old -> new, e.g. {"mixamo_com": "run", "Armature\|Take 001": "idle"}. Keys may also be "library/anim". |
| `replace_existing` | boolean |  | `false` | apply: replace an import script that was not generated by AI Studio. |
| `replacement` | string |  |  | Replacement for 'pattern' ($1 groups allowed; default empty). |
| `script_path` | string |  |  | apply: where to write the post-import script (default: next to the model, <name>_anim_names.gd). |


### 3D sahne kurulumu

Mesh inceleme, materyal, fizik gövdesi, kamera ve ortam ışığı.

#### `godot_mesh_info`

✅ **Salt okunur**, onaysız çalışır.

Bir mesh'i inceler: yüzeyler, vertex/yüz sayıları, boyut (AABB), materyaller, blend shape'ler ve skinned mesh'in bağlı olduğu iskelet. Sahnedeki bir node'u ya da mesh kaynak yolunu kabul eder.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `mesh_path` | string |  |  | Instead of a node: a res:// mesh resource (.res/.mesh/.obj). |
| `node_path` | string |  |  | MeshInstance3D node path. |
| `source` | string |  |  | res:// scene containing the node (default: the edited scene). |
| `surface_limit` | integer |  | `8` | How many surfaces to describe in detail (default 8). |

#### `godot_create_material`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Albedo, metallic, roughness, emission, şeffaflık, cull ve UV ayarlarıyla, istenirse dokularla bir StandardMaterial3D (`.tres`) oluşturur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `output_path` | string | evet |  | res:// path for the material, e.g. res://materials/rock.tres. |
| `albedo_color` | string |  |  | Colour: '#rrggbb', '#rrggbbaa' or 'r,g,b,a'. |
| `albedo_texture` | string |  |  | res:// texture path. |
| `cull_mode` | string |  |  | back \| front \| disabled |
| `emission_color` | string |  |  | Emission colour; enables emission. |
| `emission_energy` | number |  |  | Emission strength (default 1). |
| `metallic` | number |  |  | 0-1. |
| `normal_texture` | string |  |  | res:// texture path. |
| `roughness` | number |  |  | 0-1. |
| `shading_mode` | string |  |  | per_pixel (default) \| unshaded |
| `textures` | object |  |  | {material property: res:// texture path}, e.g. {'roughness_texture': '...'}. |
| `transparency` | string |  |  | disabled \| alpha \| alpha_scissor \| alpha_hash \| depth_prepass |
| `uv1_scale` | string |  |  | UV1 scale as 'x,y' (e.g. '2,2'). |
| `vertex_color_use_as_albedo` | boolean |  | `false` | Multiply albedo by vertex colours. |

#### `godot_set_material`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahnedeki bir MeshInstance3D'ye materyal atar: tek bir yüzeye ya da tüm yüzeylere (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `material_path` | string | evet |  | res:// material resource. |
| `node_path` | string | evet |  | MeshInstance3D node path. |
| `surface` | integer |  | `-1` | -1 (default) = every surface, otherwise a surface index. |

#### `godot_add_physics_body`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahneye StaticBody3D / RigidBody3D / Area3D / CharacterBody3D ve uygun bir CollisionShape3D ekler. Şekil bir MeshInstance3D'nin sınırlarına otomatik oturtulabilir (kutu, kapsül, küre, silindir) ya da mesh'ten üretilebilir (trimesh, convex). Katman ve maskeler ayarlanabilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `body_type` | string |  |  | static \| rigid \| area \| character (default character). |
| `collision_layer` | integer |  | `1` | Collision layer bits (default 1). |
| `collision_mask` | integer |  | `1` | Collision mask bits (default 1). |
| `fit_to` | string |  |  | MeshInstance3D whose bounds define the shape (default: the first mesh under parent). |
| `floor_snap_length` | number |  |  | CharacterBody3D floor snap length (default 0.3). |
| `height` | number |  |  | Explicit height for capsule/cylinder. |
| `mass` | number |  |  | Rigid body mass. |
| `name` | string |  |  | Node name (default: the body type). |
| `offset` | string |  |  | Shape offset as 'x,y,z'. |
| `parent_path` | string |  |  | Where to add the body (default: the scene root). |
| `radius` | number |  |  | Explicit radius for sphere/capsule/cylinder. |
| `shape` | string |  |  | box \| sphere \| capsule \| cylinder \| trimesh \| convex \| none (default box). |
| `size` | string |  |  | Explicit size as 'x,y,z' (overrides fit_to). |

#### `godot_add_camera`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Açık sahneye bir Camera3D ekler; istenirse bir node'a veya noktaya çevirir, FOV ve `current` ayarlarını yapar (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `current` | boolean |  | `true` | Make it the active camera of the scene. |
| `fov` | number |  |  | Field of view in degrees (default 70). |
| `look_at` | string |  |  | Node path or 'x,y,z' point to look at. |
| `name` | string |  |  | Node name (default: Camera3D). |
| `parent_path` | string |  |  | Parent node (default: the scene root). |
| `position` | string |  |  | Position as 'x,y,z'. |

#### `godot_setup_3d_environment`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir 3D sahneyi tek adımda aydınlatır. Gölgeli bir DirectionalLight3D ile prosedürel gökyüzü, ortam ışığı, isteğe bağlı sis ve tonemapping içeren bir WorldEnvironment ekler (geri alınabilir).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `ambient_energy` | number |  |  | Ambient light multiplier (default 1.0). |
| `background` | string |  |  | sky (default) \| color \| clear. |
| `background_color` | string |  |  | Colour when background=color. |
| `fog` | boolean |  | `false` | Enable depth fog. |
| `fog_color` | string |  |  | Fog colour. |
| `fog_density` | number |  |  | Fog density (default 0.01). |
| `ground_color` | string |  |  | Ground colour of the procedural sky. |
| `parent_path` | string |  |  | Parent node (default: the scene root). |
| `replace_existing` | boolean |  | `false` | Replace an existing light/environment instead of adding more. |
| `shadows` | boolean |  | `true` | Enable sun shadows. |
| `sky_horizon_color` | string |  |  | Horizon colour of the procedural sky. |
| `sky_top_color` | string |  |  | Zenith colour of the procedural sky. |
| `sun_color` | string |  |  | Sun colour (default white). |
| `sun_energy` | number |  |  | Sun energy (default 1.0). |
| `sun_rotation_degrees` | string |  |  | Sun rotation as 'x,y,z' degrees (default '-45,-35,0'). |
| `tonemap` | string |  |  | linear \| reinhard \| filmic \| aces \| agx (default filmic). |


### Import ayarları

Asset'lerin `.import` dosyalarını okuma ve değiştirme.

#### `godot_get_import_settings`

✅ **Salt okunur**, onaysız çalışır.

Bir asset'in (model, doku, ses...) `.import` dosyasını okur: importer, tür ve 3D modellerin retarget ayarları dahil tüm import parametreleri.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `resource_path` | string | evet |  | res:// path of the source asset, e.g. res://models/hero.glb. |
| `filter` | string |  |  | Only keys containing this text (glob-ish, e.g. 'retarget'). |
| `section` | string |  |  | params (default) \| all. |

#### `godot_set_import_settings`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir asset'in import parametrelerini `.import` dosyasını düzenleyerek değiştirir. Değerler Godot sabiti olarak ayrıştırılır; istenirse asset hemen yeniden içe aktarılır. Örnek parametreler: `retarget/bone_map`, `retarget/rest_fixer`, `meshes/generate_lods`, fizik gövdeleri.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `resource_path` | string | evet |  | res:// path of the source asset. |
| `settings` | object | evet |  | {import parameter: value}, e.g. {'retarget/bone_map': 'res://hero_bonemap.tres'}. |
| `reimport` | boolean |  | `true` | Ask the editor to reimport the asset afterwards. |
| `section` | string |  |  | params (default) \| remap \| deps. |


### Sahne dosyaları (diskte)

`.tscn` dosyalarını editörde açmadan düzenler. Sahne açıksa değişiklikten sonra yeniden yüklenir. Kaydedilmemiş değişiklikleri olan açık sahnelere dokunulmaz.

#### `godot_read_scene`

✅ **Salt okunur**, onaysız çalışır.

Bir `.tscn`/`.scn` dosyasını açmadan okur: her node'un türü ve üst yolu, örneklenen alt sahneler, gruplar, dosyada saklanan özellikler ve tüm sinyal bağlantıları.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string | evet |  | res:// path of the scene. |
| `include_properties` | boolean |  | `true` | Include stored property values. |

#### `godot_create_scene`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Tek bir kök node'u olan yeni bir sahne dosyası oluşturur (sahne açılmaz). Sonra `godot_scene_add_node` ile node eklenebilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string | evet |  | res:// path of the new .tscn. |
| `overwrite` | boolean |  | `false` | Replace an existing file. |
| `root_name` | string |  |  | Root node name (default: from the file name). |
| `root_type` | string |  | `"Node2D"` | Root node class or global script class. |

#### `godot_scene_add_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne **dosyasına** node ekler ya da başka bir sahneyi örnekler. Sahne açık olsa da olmasa da çalışır; açıksa ekleme sonrası yeniden yüklenir. Kaydedilmemiş değişikliği olan açık bir sahneye dokunmaz.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `name` | string | evet |  | Node name. |
| `scene_path` | string | evet |  | res:// path of the scene. |
| `parent_path` | string |  |  | Parent node path inside the scene ('' or '.' = root, e.g. 'Player/Body'). |
| `properties` | object |  |  | Property values keyed by property name. Values may be JSON (numbers, bools, {x,y}/{x,y,z} vectors, {r,g,b,a} or "#rrggbb" colors) or Godot literals as strings, e.g. "Vector2(10, 20)" or "res://icon.svg" for resources. |
| `scene_instance` | string |  |  | Instead of 'type': res:// path of a scene to instance here. |
| `type` | string |  |  | Node class or global script class, e.g. 'Sprite2D'. |

#### `godot_scene_modify_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne dosyasındaki node'un özelliklerini ayarlar. Değerler özelliğin gerçek türüne çevrilir. `script` ile betik bağlanabilir (`''` bağlantıyı kaldırır) ve `"texture": "res://img.png"` gibi doku atanabilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Node path inside the scene ('' = root). |
| `properties` | object | evet |  | Property values keyed by property name. Values may be JSON (numbers, bools, {x,y}/{x,y,z} vectors, {r,g,b,a} or "#rrggbb" colors) or Godot literals as strings, e.g. "Vector2(10, 20)" or "res://icon.svg" for resources. |
| `scene_path` | string | evet |  | res:// path of the scene. |

#### `godot_scene_remove_node`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne dosyasından bir node'u çocuklarıyla birlikte siler.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Node path inside the scene. |
| `scene_path` | string | evet |  | res:// path of the scene. |

#### `godot_scene_restructure`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne dosyası içinde node'u yeniden adlandırır (`rename`), çoğaltır (`duplicate`), başka bir üst node'a taşır (`move`) ya da sırasını değiştirir (`reorder`). Taşımada sahiplik (owner) doğru ayarlanır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `rename` / `duplicate` / `move` / `reorder` | evet |  | What to do. |
| `node_path` | string | evet |  | Node path inside the scene. |
| `scene_path` | string | evet |  | res:// path of the scene. |
| `index` | integer |  | `-1` | reorder: new child index (-1 = last). |
| `new_name` | string |  |  | rename: the new name; duplicate: optional name of the copy. |
| `new_parent_path` | string |  |  | move: path of the new parent. |

#### `godot_scene_signals`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne dosyasında saklanan kalıcı sinyal bağlantılarını listeler, ekler veya kaldırır. Eklerken kaynak node'da sinyalin gerçekten var olduğunu kontrol eder.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `add` / `remove` | evet |  | What to do. |
| `scene_path` | string | evet |  | res:// path of the scene. |
| `method` | string |  |  | Method on the target. |
| `signal_name` | string |  |  | Signal name, e.g. 'pressed'. |
| `source_path` | string |  |  | Emitting node path ('' = root). |
| `target_path` | string |  |  | Receiving node path ('' = root). |

#### `godot_save_scene_as`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahne dosyasını yeniden kaydeder, istenirse yeni bir yola kopya olarak. Yeniden kaydetme UID'leri ve dosya formatını da günceller.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string | evet |  | res:// path of the scene. |
| `new_path` | string |  |  | Optional res:// target path. |

#### `godot_export_mesh_library`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir sahneden GridMap için MeshLibrary oluşturur. MeshInstance3D içeren her çocuk bir öğe olur; varsa CollisionShape3D'si de alınır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `output_path` | string | evet |  | Where to save the MeshLibrary (.tres/.res). |
| `scene_path` | string | evet |  | res:// scene containing the meshes. |
| `items` | array<string> |  |  | Only these child names (default: all). |


### Kaynaklar (Resource) ve UID'ler

`.tres` kaynakları oluşturma, okuma, değiştirme ve UID yönetimi.

#### `godot_create_resource`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Herhangi bir sınıftan Resource oluşturup kaydeder: StandardMaterial3D, Theme, Environment, Curve, AudioStreamRandomizer, özel Resource betik sınıfları... Başlangıç özellikleri verilebilir. Theme öğeleri `Button/colors/font_color` biçiminde ayarlanabilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `resource_path` | string | evet |  | res:// path to save to (.tres or .res). |
| `resource_type` | string | evet |  | Class name or global script class. |
| `overwrite` | boolean |  | `false` | Replace an existing file. |
| `properties` | object |  |  | Property values keyed by property name. Values may be JSON (numbers, bools, {x,y}/{x,y,z} vectors, {r,g,b,a} or "#rrggbb" colors) or Godot literals as strings, e.g. "Vector2(10, 20)" or "res://icon.svg" for resources. |

#### `godot_read_resource`

✅ **Salt okunur**, onaysız çalışır.

Bir kaynak dosyasını okur: sınıfı, betiği ve saklanan tüm özellik değerleri. Theme'lerde öğeler de listelenir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `resource_path` | string | evet |  | res:// path of the resource. |

#### `godot_modify_resource`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir kaynak dosyasının özelliklerini değiştirip kaydeder. Theme öğeleri `Button/colors/font_color` ya da `Label/font_sizes/font_size` biçiminde ayarlanabilir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `properties` | object | evet |  | Property values keyed by property name. Values may be JSON (numbers, bools, {x,y}/{x,y,z} vectors, {r,g,b,a} or "#rrggbb" colors) or Godot literals as strings, e.g. "Vector2(10, 20)" or "res://icon.svg" for resources. |
| `resource_path` | string | evet |  | res:// path of the resource. |

#### `godot_get_uid`

✅ **Salt okunur**, onaysız çalışır.

Bir dosyanın UID'sini (`uid://...`) editörün önbelleğinden veya `.uid` yan dosyasından verir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `path` | string | evet |  | res:// path of the file. |

#### `godot_update_uids`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir klasördeki tüm sahne ve kaynakları yeniden kaydederek UID referanslarını yeniler; betik ve shader'lar için eksik `.uid` dosyalarını oluşturur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `folder` | string |  | `"res://"` | res:// folder to process. |


### Betikler ve shader'lar

GDScript doğrulama, betik ve shader oluşturma.

#### `godot_validate_scripts`

✅ **Salt okunur**, onaysız çalışır.

GDScript dosyalarını motorun kendi derleyicisiyle, çalıştırmadan derler ve ayrıştırma/tür hatalarını satır numarasıyla raporlar. Doğrudan dosya yolları verilebilir ya da kapsam seçilebilir: `scope='changed'` (git'e göre değişenler) veya `'all'`.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `paths` | array<string> |  |  | res:// .gd files to check (overrides scope). |
| `scope` | string: `changed` / `all` |  |  | 'changed' = files changed according to git (default), 'all' = every .gd in the project (max 60). |

#### `godot_create_script`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Şablondan (extends, class_name, metot iskeletleri) ya da tam kaynak koddan bir GDScript (`.gd`) veya C# (`.cs`) dosyası oluşturur, ardından doğrular. İstenmedikçe üzerine yazmaz.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `path` | string | evet |  | res:// path ending in .gd or .cs. |
| `class_name` | string |  |  | Optional class_name (C#: must match the file name). |
| `extends` | string |  | `"Node"` | Base class. |
| `methods` | array<string> |  |  | Method stubs, e.g. ['_ready', '_process'] (C#: '_Ready', '_Process'). |
| `namespace` | string |  |  | C# only: optional namespace. |
| `overwrite` | boolean |  | `false` | Replace an existing file. |
| `source` | string |  |  | Full source; overrides the template. |

#### `godot_create_shader`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Kaynak koddan ya da verilen shader türünün şablonundan bir `.gdshader` dosyası oluşturur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `path` | string | evet |  | res:// path ending in .gdshader. |
| `overwrite` | boolean |  | `false` | Replace an existing file. |
| `shader_type` | string: `spatial` / `canvas_item` / `particles` / `sky` / `fog` |  |  | Template type when no source is given. |
| `source` | string |  |  | Full shader source (optional). |


### Proje yapılandırması

`project.godot` ayarları, ana sahne, autoload, input map, katmanlar, eklentiler, çeviriler.

#### `godot_set_project_setting`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Bir proje ayarını ayarlar veya siler ve `project.godot` dosyasını kaydeder (ör. `display/window/size/viewport_width = 1280`). Ayarın mevcut türü korunur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `name` | string | evet |  | Full setting path, e.g. 'application/config/name'. |
| `erase` | boolean |  | `false` | Remove the setting instead (back to its default). |
| `value` | string |  |  | New value as a Godot literal or JSON. Ignored when erase is true. |

#### `godot_set_main_scene`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

`application/run/main_scene` ayarını, yani F5'in çalıştırdığı sahneyi belirler.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `scene_path` | string | evet |  | res:// path of the scene. |

#### `godot_manage_autoloads`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Autoload singleton'larını listeler, ekler veya kaldırır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `add` / `remove` | evet |  | What to do. |
| `global` | boolean |  | `true` | add: make it a global variable (the usual choice). |
| `name` | string |  |  | Singleton name (add/remove). |
| `path` | string |  |  | add: res:// script or scene. |

#### `godot_manage_input_map`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Input action'larını listeler, ekler veya kaldırır; action'lara tuş, fare düğmesi, joypad düğmesi veya ekseni bağlar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `add` / `remove` / `clear_events` | evet |  | add creates the action if needed and appends the given bindings. |
| `action_name` | string |  |  | Input action name (add/remove/clear_events). |
| `deadzone` | number |  |  | Deadzone for a new action (default 0.2). |
| `joy_axes` | array<string> |  |  | Joypad axes as 'axis:direction', e.g. '0:-1' for left stick left. |
| `joy_buttons` | array<integer> |  |  | Joypad button indices (0 = A/Cross...). |
| `keys` | array<string> |  |  | Keys, e.g. ['W', 'Up', 'Space', 'Ctrl+S']. |
| `mouse_buttons` | array<integer> |  |  | Mouse buttons (1 left, 2 right, 3 middle, 4/5 wheel). |

#### `godot_manage_layers`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Render / fizik / navigasyon / avoidance katmanlarını listeler veya adlandırır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `set` | evet |  | What to do. |
| `layer` | integer |  | `1` | Layer number 1-32 (set). |
| `layer_type` | string: `render_2d` / `physics_2d` / `navigation_2d` / `render_3d` / `physics_3d` / `navigation_3d` / `avoidance` |  |  | Layer family (set). |
| `name` | string |  |  | Layer name (set); empty clears it. |

#### `godot_manage_plugins`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

`addons/` altındaki editör eklentilerini listeler, etkinleştirir veya devre dışı bırakır. AI Studio kendini devre dışı bırakamaz.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `enable` / `disable` | evet |  | What to do. |
| `plugin` | string |  |  | Plugin folder name under addons/ (enable/disable). |

#### `godot_manage_translations`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Projenin yerelleştirme ayarlarındaki çeviri dosyalarını (.po/.translation/.csv) listeler, ekler veya kaldırır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `add` / `remove` | evet |  | What to do. |
| `path` | string |  |  | res:// path of the translation (add/remove). |


### Export ve CI

Export preset'leri, headless export ve GitHub Actions/Docker dosyaları.

#### `godot_manage_export_presets`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

`export_presets.cfg` dosyasındaki export preset'lerini listeler, ekler veya kaldırır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `list` / `add` / `remove` | evet |  | What to do. |
| `export_path` | string |  |  | add: default output path, e.g. 'build/game.exe'. |
| `name` | string |  |  | Preset name (add/remove). |
| `platform` | string |  |  | add: platform, e.g. 'Windows Desktop', 'Linux', 'macOS', 'Web', 'Android'. |
| `runnable` | boolean |  | `false` | add: mark it runnable. |

#### `godot_export_project`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Projeyi bir preset ile, bu Godot binary'sini headless çalıştırarak export eder. Export şablonlarının kurulu olması gerekir; işlem dakikalar sürebilir. Sonunda çıktının boyutunu raporlar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `output_path` | string | evet |  | Output file; relative paths are relative to the project folder. |
| `preset` | string | evet |  | Export preset name. |
| `mode` | string: `release` / `debug` / `pack` |  |  | release (default), debug, or pack (.pck/.zip only). |

#### `godot_manage_ci`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Projeyi bu Godot sürümüyle headless export eden bir GitHub Actions workflow'u veya Dockerfile oluşturur ya da mevcut olanı okur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `read` / `create` | evet |  | What to do. |
| `target` | string: `github_actions` / `docker` | evet |  | Which file. |
| `godot_version` | string |  |  | Godot version, e.g. '4.7.2-stable' (default: this editor's version). |
| `overwrite` | boolean |  | `false` | Replace an existing file. |
| `presets` | array<string> |  |  | Export preset names to build (default: all presets). |


### Editör betiği ve editör günlüğü

Diğer araçların yetmediği yerde editörde kod çalıştırma ve editörün hata/uyarı günlüğünü okuma.

#### `godot_run_editor_script`

⚠️ **Her zaman onay ister**. "Değişikliklerden önce sor" kapalı olsa bile sorar.

Diğer araçların yetmediği işler için editörde tek seferlik bir GDScript çalıştırır: toplu düzenlemeler, editör API'leri, özel kontroller.

- Bir fonksiyon gövdesi (`func run()` olarak çalışır; `await` kullanılabilir, `return` ile sonuç döner) ya da `func run()` tanımlayan tam bir betik verilebilir.
- `EditorInterface` ve tüm motor API'leri kullanılabilir.
- Çıktılar (`print`), hatalar (satır numarasıyla) ve dönüş değeri geri gelir.

Korumalı alan (sandbox) ve zaman aşımı olmadığı için onaylar kapalı olsa bile **her zaman onay ister**.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `code` | string | evet |  | GDScript: a function body (indented or not) or a script with func run(). |

#### `godot_editor_log`

✅ **Salt okunur**, onaysız çalışır.

Editörün mesajlarını okur. Kaynaklar:

- `errors`: editördeki hata ve uyarılar (dosya ve satırıyla) ile debugger'ın Errors sekmesi (çalışan veya son oyun);
- `all`: `print` dahil tüm editör log kayıtları;
- `output`: Output panelinin metni; oyunun `print` çıktısı da burada görünür;
- `debugger`: yalnızca debugger'ın Errors sekmesi.

Betik veya sahne değiştirdikten sonra ya da bir şey sessizce çalışmadığında kullanılır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `clear` | boolean |  | `false` | Clear the collected editor log after reading. |
| `contains` | string |  |  | Only entries containing this text (case-insensitive). |
| `limit` | integer |  | `50` | Maximum entries/lines (newest). |
| `since_id` | integer |  | `0` | Only editor log entries with a larger id (ids are shown in the output). |
| `source` | string: `errors` / `all` / `output` / `debugger` |  | `"errors"` | errors: editor errors/warnings + debugger errors; all: every editor log entry incl. prints; output: the Output panel text; debugger: only the debugger's Errors tab. |


### Oyun köprüsü: günlük kullanılan komutlar

Editörden çalıştırılan oyunu inceleyen ve yöneten araçlar. Oyun köprüsünün etkin olması ve oyunun editörden çalışıyor olması gerekir (bkz. [Oyun köprüsü](#oyun-köprüsü)).

#### `godot_game_bridge`

🔀 **Duruma göre**: `action=status` salt okunur, diğer eylemler onay ister.

Oyun köprüsünün durumunu gösterir, köprüyü etkinleştirir veya kapatır. Köprü, yalnızca editörden başlatılan oyunlarda çalışan bir autoload'dır ve `game_*` araçları onunla konuşur. Etkinleştirdikten sonra oyun `godot_play_scene` ile (yeniden) başlatılmalıdır. Durum sorgusu onaysız çalışır; etkinleştirme ve kapatma onay ister.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string: `status` / `enable` / `disable` |  |  | Default: status. |

#### `game_commands`

✅ **Salt okunur**, onaysız çalışır.

Çalışma zamanı oyun komutlarını arar. `names` verilmezse her komutu tek satırlık açıklamasıyla listeler, `filter` ile listeyi süzer; `names` verilirse o komutların tam parametre şemalarını döndürür.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `filter` | string |  |  | Only list commands whose name or description contains this text. |
| `names` | array<string> |  |  | Command names, e.g. ['game_spawn_node', 'game_tween_property']. |

#### `game_command`

🔀 **Duruma göre**: okuma ve girdi simülasyonu komutları onaysız, diğerleri onay ister.

Editörden çalışan oyunda herhangi bir çalışma zamanı komutunu adıyla çalıştırır: node ekleme, tween, animasyon, fizik sorguları, ses, kamera, UI, tilemap, ışık, parçacık, ağ vb. Yalnızca okuyan ve girdi simüle eden komutlar onaysız çalışır, diğerleri onay ister.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `command` | string | evet |  | Command name, e.g. 'game_spawn_node' (the 'game_' prefix is optional). |
| `params` | object |  |  | Parameters as listed by game_commands (snake_case). |

#### `game_screenshot`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunun ekran görüntüsünü alır ve `user://ai_studio/shots/` altına PNG olarak kaydeder.

_Parametre almaz._

#### `game_click`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyun penceresinde bir konuma tıklar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `x` | number | evet |  | X coordinate to click |
| `y` | number | evet |  | Y coordinate to click |
| `button` | number |  |  | Mouse button (1=left, 2=right, 3=middle). Default: 1 |

#### `game_key_press`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyuna tuş basışı veya input action gönderir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string |  |  | Godot input action name (e.g. "move_forward", "ui_accept") |
| `key` | string |  |  | Key name (e.g. "W", "Space", "Escape", "Enter") |
| `pressed` | boolean |  |  | Press (true) or release (false). Default: true (auto-release) |

#### `game_mouse_move`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunda fareyi mutlak bir konuma ya da göreli olarak hareket ettirir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `x` | number | evet |  | Absolute X position |
| `y` | number | evet |  | Absolute Y position |
| `relative_x` | number |  |  | Relative X movement |
| `relative_y` | number |  |  | Relative Y movement |

#### `game_get_ui`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyundaki görünür UI öğelerini listeler.

_Parametre almaz._

#### `game_get_scene_tree`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunun canlı sahne ağacını verir.

_Parametre almaz._

#### `game_eval`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Çalışan oyunda GDScript çalıştırır; değer döndürmek için `return` kullanılır. Onay ister.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `code` | string | evet |  | GDScript code to execute. Use "return" to return values. |

#### `game_get_property`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunda herhangi bir node'un bir özelliğini yoluna göre okur.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Path to the node (e.g., "/root/Player", "/root/Main/Enemy") |
| `property` | string | evet |  | Property name to get (e.g., "position", "health", "visible") |

#### `game_set_property`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Çalışan oyunda bir node'un özelliğini ayarlar.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Path to the node |
| `property` | string | evet |  | Property name to set |
| `value` | string | evet |  | Value to set. Use objects for vectors/colors Pass JSON text (e.g. {"x":1,"y":2}, [1,2,3], 5, true) or a plain string. |
| `type_hint` | string |  |  | Optional type hint: "Vector2", "Vector3", "Color" |

#### `game_call_method`

✋ **Değişiklik yapar**, onay ister (ayarlardan kapatılabilir).

Çalışan oyunda herhangi bir node'un bir metodunu, isteğe bağlı argümanlarla çağırır.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `method` | string | evet |  | Method name to call |
| `node_path` | string | evet |  | Path to the node |
| `args` | string |  |  | Optional array of arguments to pass to the method Pass JSON text (e.g. {"x":1,"y":2}, [1,2,3], 5, true) or a plain string. |

#### `game_get_node_info`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunda bir node'un bilgileri: sınıfı, özellikleri, sinyalleri, metotları, çocukları.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `node_path` | string | evet |  | Path to the node (e.g., "/root/Player") |

#### `game_performance`

✅ **Salt okunur**, onaysız çalışır.

Performans ölçümleri: FPS, kare süresi, bellek, nesne ve node sayıları, çizim çağrıları.

_Parametre almaz._

#### `game_wait`

✅ **Salt okunur**, onaysız çalışır.

Çalışan oyunda N kare bekler (render veya fizik karesi).

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `frame_type` | string: `render` / `physics` |  |  | Frame to wait on: "physics" (fixed 60Hz ticks) or "render". Default: render |
| `frames` | number |  |  | Number of frames to wait. Default: 1 |

#### `game_input_action`

✅ **Salt okunur**, onaysız çalışır.

Çalışma zamanında InputMap action'larını ve action gücünü (strength) yönetir.

| Parametre | Tür | Zorunlu | Varsayılan | Açıklama (koddaki tanım) |
|---|---|---|---|---|
| `action` | string | evet |  | Action: set_strength, add_action, remove_action, list |
| `action_name` | string |  |  | Input action name |
| `key` | string |  |  | Key name (for add_action) |
| `strength` | number |  |  | Action strength 0.0-1.0 |

#### `game_get_logs`

✅ **Salt okunur**, onaysız çalışır.

Son çağrıdan bu yana oyunun yeni `print()` çıktısını verir.

_Parametre almaz._

#### `game_get_errors`

✅ **Salt okunur**, onaysız çalışır.

Son çağrıdan bu yana oyunun yeni hata ve uyarılarını verir: `push_error`, `push_warning`, betik ve motor hataları, betik dosyası ve satırıyla.

_Parametre almaz._


### Oyun köprüsü: tüm çalışma zamanı komutları

Aşağıdaki komutlar varsayılan olarak ayrı birer araç değildir. Model bunları iki şekilde kullanır:

1. `game_commands` ile arar ve parametre şemasını öğrenir;
2. `game_command` ile çalıştırır: `{"command": "game_spawn_node", "params": {...}}`.

**Ayarlar → "Expose every game command as its own tool"** açılırsa her biri ayrı araç olarak kaydedilir. Bu, araç sayısını 100'den fazla artırır; bazı sağlayıcılar en fazla 128 araç kabul eder.

✅ işaretli komutlar yalnızca okur veya oyuncu girdisi simüle eder, bu yüzden onaysız çalışır. Diğerleri onay ister.


#### Sahne ve node yönetimi

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_instantiate_scene` |  | Bir PackedScene yükleyip çalışan oyunda bir node'un çocuğu olarak ekler. | **`scene_path`**, `parent_path` |
| `game_remove_node` |  | Bir node'u oyunun sahne ağacından kaldırıp serbest bırakır. | **`node_path`** |
| `game_change_scene` |  | Çalışan oyunda başka bir sahne dosyasına geçer. | **`scene_path`** |
| `game_pause` |  | Oyunu duraklatır veya devam ettirir. | `paused` |
| `game_spawn_node` |  | Çalışma zamanında herhangi bir türde, özellikleriyle yeni bir node oluşturur. | **`type`**, `name`, `parent_path`, `properties` |
| `game_reparent_node` |  | Bir node'u başka bir üst node'a taşır (global transform korunabilir). | **`new_parent_path`**, **`node_path`**, `keep_global_transform` |
| `game_get_nodes_in_group` | ✅ | Bir gruptaki tüm node'ları listeler. | **`group`** |
| `game_find_nodes_by_class` | ✅ | Belirli bir sınıftaki tüm node'ları bulur. | **`class_name`**, `root_path` |
| `game_manage_group` |  | Node'u bir gruba ekler/gruptan çıkarır veya grupları listeler. | **`action`**, `group`, `node_path` |
| `game_process_mode` |  | Node'un process modunu ayarlar (pausable/always/disabled). | **`mode`**, **`node_path`** |
| `game_serialize_state` |  | Node ağacının durumunu JSON olarak kaydeder veya geri yükler. | `action`, `data`, `max_depth`, `node_path` |
| `game_script` |  | Node'lara betik bağlar, betiği kaldırır veya kaynağını getirir. | **`action`**, **`node_path`**, `class_name`, `source` |
| `game_resource` |  | Çalışma zamanında kaynak yükler, kaydeder veya bir özelliğe atar. | **`action`**, **`path`**, `node_path`, `property` |
| `game_create_timer` |  | Ayarlarıyla bir Timer node'u oluşturur. | `autostart`, `name`, `one_shot`, `parent_path`, `wait_time` |


#### Sinyaller

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_connect_signal` |  | Bir node'un sinyalini başka bir node'un metoduna bağlar. | **`method`**, **`node_path`**, **`signal_name`**, **`target_path`** |
| `game_disconnect_signal` |  | Bir sinyal bağlantısını kaldırır. | **`method`**, **`node_path`**, **`signal_name`**, **`target_path`** |
| `game_emit_signal` |  | Bir node'da, isteğe bağlı argümanlarla sinyal yayar. | **`node_path`**, **`signal_name`**, `args` |
| `game_list_signals` | ✅ | Bir node'daki tüm sinyalleri bağlantılarıyla listeler. | **`node_path`** |
| `game_await_signal` |  | Zaman aşımıyla bir sinyali bekler ve argümanlarını döndürür. | **`node_path`**, **`signal_name`**, `timeout` |


#### Girdi (input) simülasyonu

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_key_hold` | ✅ | Bir tuşu otomatik bırakmadan basılı tutar. | `action`, `key` |
| `game_key_release` | ✅ | Basılı tutulan tuşu bırakır. | `action`, `key` |
| `game_scroll` | ✅ | Bir konumda fare tekerleği olayı gönderir. | **`x`**, **`y`**, `amount`, `direction` |
| `game_mouse_drag` | ✅ | Fareyi iki nokta arasında N karede sürükler. | **`from_x`**, **`from_y`**, **`to_x`**, **`to_y`**, `button`, `steps` |
| `game_gamepad` | ✅ | Gamepad düğme veya eksen olayı gönderir. | **`index`**, **`type`**, **`value`**, `device` |
| `game_touch` | ✅ | Dokunma basma/bırakma/sürükleme ve jestleri simüle eder. | **`action`**, **`x`**, **`y`**, `index`, `steps`, `to_x`, `to_y` |
| `game_input_state` |  | Basılı tuşları, fare konumunu ve bağlı gamepad'leri sorgular; fare modunu ayarlar. | `action`, `mouse_mode`, `x`, `y` |


#### Animasyon ve tween

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_play_animation` |  | AnimationPlayer'ı oynatır, durdurur, duraklatır veya animasyonlarını listeler. | **`node_path`**, `action`, `animation` |
| `game_animation_control` |  | AnimationPlayer'da seek, queue, hız ayarı ve bilgi. | **`action`**, **`node_path`**, `animation_name`, `position`, `speed` |
| `game_animation_tree` |  | AnimationTree durum makinesinde travel yapar ve parametre ayarlar. | **`action`**, **`node_path`**, `param_name`, `param_value`, `state_name` |
| `game_create_animation` |  | Track ve anahtar karelerle yeni bir animasyon oluşturur. | **`animation_name`**, **`node_path`**, `length`, `library`, `loop_mode`, `tracks` |
| `game_tween_property` |  | Bir node özelliğini tween ile canlandırır (süre, geçiş, easing). | **`final_value`**, **`node_path`**, **`property`**, `duration`, `ease_type`, `trans_type` |
| `game_bone_pose` |  | Skeleton3D'de kemik pozlarını okur veya ayarlar. | **`node_path`**, `action`, `bone_index`, `bone_name`, `position`, `rotation`, `scale` |
| `game_skeleton_ik` |  | SkeletonIK3D'yi başlatır/durdurur, hedef konumunu ayarlar. | **`action`**, **`node_path`**, `target` |


#### Kamera, pencere ve render

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_get_camera` | ✅ | Aktif kameranın konumu, dönüşü ve boyutu. | – |
| `game_set_camera` |  | Aktif kamerayı taşır, döndürür; FOV/zoom ayarlar. | `fov`, `position`, `rotation`, `zoom` |
| `game_camera_attributes` |  | Kamerada DOF, pozlama ve otomatik pozlama ayarları. | `action`, `auto_exposure`, `auto_exposure_scale`, `dof_blur_amount`, `dof_blur_far`, `dof_blur_near`, `exposure_multiplier` |
| `game_window` |  | Pencere boyutu, tam ekran, başlık, konum, vsync okur/ayarlar. | `action`, `borderless`, `fullscreen`, `height`, `position`, `title`, `vsync`, `width` |
| `game_viewport` |  | SubViewport oluşturur veya yapılandırır. | `action`, `height`, `msaa`, `name`, `node_path`, `parent_path`, `transparent_bg`, `width` |
| `game_render_settings` |  | MSAA, FXAA, TAA, ölçekleme modu ve oranını okur/ayarlar. | `action`, `fxaa`, `msaa_2d`, `msaa_3d`, `scaling_mode`, `scaling_scale`, `taa` |
| `game_environment` |  | Environment ve post-processing ayarlarını okur/ayarlar. | `action`, `ambient_light_color`, `ambient_light_energy`, `background_color`, `background_mode`, `brightness`, `contrast`, `fog_density`, `fog_enabled`, `fog_light_color`, `glow_bloom`, `glow_enabled`, `glow_intensity`, `saturation`, `ssao_enabled`, `ssao_intensity`, `ssao_radius`, `ssr_enabled`, `tonemap_mode` |
| `game_sky` |  | Prosedürel/fiziksel Sky oluşturur veya yapılandırır. | **`action`**, `bottom_color`, `ground_color`, `sky_type`, `sun_energy`, `top_color` |
| `game_debug_draw` |  | 3D'de hata ayıklama çizgisi, küre veya kutu çizer. | **`action`**, `center`, `color`, `duration`, `from`, `radius`, `size`, `to` |
| `game_set_shader_param` |  | Bir node'un materyalinde shader parametresi ayarlar. | **`node_path`**, **`param_name`**, **`value`**, `type_hint` |
| `game_visual_shader` |  | VisualShader grafiği oluşturur/düzenler: düğüm ekler, bağlar, ayırır. | **`action`**, `from_node`, `from_port`, `node_class`, `node_path`, `position`, `shader_id`, `shader_type`, `to_node`, `to_port` |


#### 3D

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_mesh_instance` |  | Primitive mesh'li bir MeshInstance3D oluşturur. | **`mesh_type`**, **`parent_path`**, `height`, `material`, `name`, `radius`, `size` |
| `game_procedural_mesh` |  | Vertex verisinden ArrayMesh üretir. | **`parent_path`**, **`vertices`**, `indices`, `name`, `normals`, `uvs` |
| `game_csg` |  | Boolean işlemli CSG node'ları oluşturur/yapılandırır. | **`action`**, `csg_type`, `height`, `material`, `name`, `node_path`, `operation`, `parent_path`, `radius`, `size` |
| `game_multimesh` |  | Instancing için MultiMeshInstance3D oluşturur/yapılandırır. | **`action`**, `count`, `index`, `mesh_type`, `name`, `node_path`, `parent_path`, `transform` |
| `game_light_3d` |  | 3D ışık (directional/omni/spot) oluşturur/yapılandırır. | **`action`**, `color`, `energy`, `light_type`, `name`, `node_path`, `parent_path`, `range`, `shadows`, `spot_angle` |
| `game_gridmap` |  | GridMap hücrelerini ayarlar/okur/temizler, kullanılan hücreleri sorgular. | **`action`**, **`node_path`**, `item`, `orientation`, `x`, `y`, `z` |
| `game_3d_effects` |  | ReflectionProbe, Decal veya FogVolume oluşturur. | **`effect_type`**, **`parent_path`**, `intensity`, `name`, `size` |
| `game_gi` |  | VoxelGI veya LightmapGI oluşturur/yapılandırır. | **`gi_type`**, **`parent_path`**, `name`, `size` |
| `game_path_3d` |  | Path3D/Curve3D oluşturur ve eğri noktalarını yönetir. | **`action`**, `name`, `node_path`, `parent_path`, `point`, `points` |
| `game_navigation_3d` |  | NavigationRegion3D oluşturur/yapılandırır ve bake eder. | **`action`**, `agent_height`, `agent_radius`, `cell_size`, `name`, `node_path`, `parent_path` |
| `game_terrain` |  | Yükseklik verisinden arazi mesh'i oluşturur/değiştirir. | **`action`**, `color`, `depth`, `height_data`, `height_delta`, `max_height`, `name`, `node_path`, `parent_path`, `radius`, `width`, `x`, `z` |
| `game_set_particles` |  | GPUParticles2D/3D özelliklerini yapılandırır (miktar, ömür, tek seferlik, patlama, hız...). | **`node_path`**, `amount`, `emitting`, `explosiveness`, `lifetime`, `one_shot`, `process_material`, `randomness`, `speed_scale` |


#### 2D

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_canvas` |  | CanvasLayer ve CanvasModulate oluşturur/yapılandırır. | **`action`**, `color`, `layer`, `name`, `node_path`, `offset`, `parent_path`, `visible` |
| `game_canvas_draw` |  | 2D çizim: çizgi, dikdörtgen, daire, çokgen, metin, temizleme. | **`action`**, `center`, `color`, `filled`, `font_size`, `from`, `parent_path`, `points`, `position`, `radius`, `rect`, `text`, `to`, `width` |
| `game_light_2d` |  | 2D ışık ve ışık engelleyici (occluder) oluşturur/yapılandırır. | **`action`**, `color`, `energy`, `name`, `node_path`, `parent_path`, `points`, `range` |
| `game_parallax` |  | ParallaxBackground ve katmanlarını oluşturur/yapılandırır. | **`action`**, `mirroring`, `motion_offset`, `motion_scale`, `name`, `node_path`, `parent_path`, `scroll_base_offset`, `scroll_offset` |
| `game_shape_2d` |  | Line2D/Polygon2D noktalarını düzenler. | **`action`**, **`node_path`**, `color`, `point`, `points`, `width` |
| `game_path_2d` |  | Path2D/Curve2D yönetimi. | **`action`**, `name`, `node_path`, `parent_path`, `point`, `points` |
| `game_tilemap` |  | TileMapLayer hücrelerini okur veya ayarlar. | **`action`**, **`node_path`**, `cells`, `source_id`, `x`, `y` |


#### Fizik ve navigasyon

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_raycast` |  | Işın atar ve çarpışma sonuçlarını döndürür. | **`from`**, **`to`**, `collision_mask` |
| `game_physics_body` |  | Fizik gövdesi özellikleri: kütle, hız, sürtünme, yerçekimi ölçeği, dondurma... | **`node_path`**, `angular_damp`, `angular_velocity`, `bounce`, `freeze`, `friction`, `gravity_scale`, `linear_damp`, `linear_velocity`, `mass`, `sleeping` |
| `game_add_collision` |  | Bir fizik gövdesine çarpışma şekli ekler. | **`parent_path`**, **`shape_type`**, `collision_layer`, `collision_mask`, `disabled`, `shape_params` |
| `game_create_joint` |  | İki gövde arasında fizik eklemi oluşturur. | **`joint_type`**, **`parent_path`**, `damping`, `length`, `node_a_path`, `node_b_path`, `softness`, `stiffness` |
| `game_physics_3d` |  | Area3D sorguları ve 3D nokta/şekil kesişim testleri. | **`action`**, `collision_mask`, `from`, `node_path`, `to` |
| `game_physics_2d` |  | Area2D sorguları ve 2D nokta/şekil kesişim testleri. | **`action`**, `collision_mask`, `from`, `max_results`, `node_path`, `position`, `radius`, `shape_type`, `size`, `to` |
| `game_world_settings` |  | Yerçekimi, fizik FPS ve dünya ayarlarını okur/ayarlar. | `action`, `gravity`, `gravity_direction`, `physics_fps` |
| `game_navigate_path` |  | İki nokta arasında navigasyon yolu sorgular. | **`end`**, **`start`**, `optimize` |
| `game_time_scale` |  | Engine.time_scale ve zamanlama bilgisini okur/ayarlar. | `action`, `time_scale` |


#### Ses

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_get_audio` | ✅ | Ses bus düzeni ve çalan akışlar. | – |
| `game_audio_play` |  | AudioStreamPlayer'ı çalar, durdurur, duraklatır (ses, pitch, bus). | **`node_path`**, `action`, `bus`, `from_position`, `pitch`, `stream`, `volume` |
| `game_audio_bus` |  | Bir ses bus'ında ses düzeyi, mute veya solo. | `bus_name`, `mute`, `solo`, `volume` |
| `game_audio_effect` |  | Bus efektlerini ekler, kaldırır, yapılandırır. | **`action`**, `bus_name`, `effect_type`, `enabled`, `index`, `properties` |
| `game_audio_bus_layout` |  | Ses bus'ları oluşturur/kaldırır ve yönlendirir. | **`action`**, `bus_name`, `send_to` |
| `game_audio_spatial` |  | AudioStreamPlayer3D uzamsal özellikleri. | **`action`**, **`node_path`**, `attenuation_model`, `max_db`, `max_distance`, `unit_size` |
| `game_video` |  | VideoStreamPlayer'da oynatma, duraklatma, durdurma, seek. | **`action`**, `autoplay`, `loop`, `name`, `node_path`, `parent_path`, `position`, `video_path`, `volume` |


#### Kullanıcı arayüzü (UI)

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_ui_theme` |  | Bir Control'e theme override'ları uygular. | **`node_path`**, **`overrides`** |
| `game_ui_control` |  | Control'de odak, anchor, tooltip, mouse filter ayarlar. | **`action`**, **`node_path`**, `anchor_preset`, `min_size`, `mouse_filter`, `tooltip` |
| `game_ui_text` |  | LineEdit/TextEdit/RichTextLabel metin işlemleri. | **`action`**, **`node_path`**, `caret_position`, `selection_from`, `selection_to`, `text` |
| `game_ui_popup` |  | Popup/Dialog/Window gösterir, gizler. | **`action`**, **`node_path`**, `size`, `text`, `title` |
| `game_ui_tree` |  | Tree kontrolünde öğe okur, seçer, daraltır, ekler, kaldırır. | **`action`**, **`node_path`**, `column`, `item_path`, `text` |
| `game_ui_item_list` |  | ItemList/OptionButton öğelerini okur, seçer, ekler, kaldırır. | **`action`**, **`node_path`**, `index`, `text` |
| `game_ui_tabs` |  | TabContainer/TabBar'da aktif sekmeyi okur/ayarlar. | **`action`**, **`node_path`**, `index`, `title` |
| `game_ui_menu` |  | PopupMenu/MenuBar öğelerini ekler, kaldırır, okur. | **`action`**, **`node_path`**, `checked`, `id`, `index`, `text` |
| `game_ui_range` |  | ProgressBar/Slider/SpinBox/ColorPicker değerlerini okur/ayarlar. | **`action`**, **`node_path`**, `color`, `max_value`, `min_value`, `step`, `value` |


#### Ağ, yerelleştirme ve sistem

| Komut | | Ne yapar | Parametreler |
|---|---|---|---|
| `game_http_request` |  | Başlık ve gövdeyle HTTP GET/POST/PUT/DELETE isteği. | **`url`**, `body`, `headers`, `method`, `timeout` |
| `game_websocket` |  | WebSocket istemcisi: bağlan, ayrıl, mesaj gönder. | **`action`**, `message`, `url` |
| `game_multiplayer` |  | ENet multiplayer: sunucu/istemci oluştur, bağlantıyı kes. | **`action`**, `address`, `max_clients`, `port` |
| `game_rpc` |  | Node'larda RPC metotlarını çağırır veya yapılandırır. | **`action`**, **`method`**, **`node_path`**, `args`, `channel`, `mode`, `sync` |
| `game_locale` |  | Çalışma zamanında dil ayarını okur/ayarlar ve metin çevirir. | **`action`**, `key`, `locale` |
| `game_os_info` | ✅ | Platform, dil, ekran, ekran kartı ve bellek bilgisi. | – |


Kalın parametreler zorunludur. Tam şema için modelden `game_commands` çağırmasını isteyebilir ya da **Tools** sekmesinden `game_commands` aracını `{"names": ["game_tween_property"]}` argümanıyla çalıştırabilirsiniz.


---

## Oyun köprüsü

Oyun köprüsü, modelin **editörden çalıştırdığınız oyunu canlı olarak** görmesini ve yönetmesini sağlar. Komut seti [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) projesinden (MIT) uyarlanmıştır, ancak Node.js sunucusu gerektirmez: her şey eklentinin içinde çalışır.

### Nasıl çalışır

1. `godot_game_bridge` aracı `action=enable` ile çağrılır (onay ister). Bu, projeye `runtime/game_bridge_server.gd` dosyasını bir **autoload** olarak ekler.
2. Oyun editörden başlatılır: `godot_play_scene` veya F5/F6. Editör, oyuna ortam değişkenleriyle bir **port** (varsayılan `9090`) ve **oturuma özel rastgele bir token** iletir: `AI_STUDIO_BRIDGE`, `AI_STUDIO_BRIDGE_PORT`, `AI_STUDIO_BRIDGE_TOKEN`.
3. Oyundaki sunucu yalnızca `127.0.0.1` üzerinde dinler. Protokol satır başına bir JSON'dur:
   - istek: `{command, params, id, token}`;
   - yanıt: `{..., id}` veya `{error, id}`.

   Token'ı yanlış olan istekler reddedilir.
4. `game_*` araçları bu sunucuya komut gönderir. Komutlar sırayla işlenir; uzun komutlar için zaman aşımı 120 saniyedir.
5. Oyundaki `print()` çıktısı ve `push_error`/`push_warning`/betik hataları bir Logger ile yakalanır. Bunlar `game_get_logs` ve `game_get_errors` ile, betik dosyası ve satır numarasıyla okunur.

### Güvenlik

- Autoload yalnızca **editörden başlatılan** oyunlarda (`editor_runtime` özelliği ve editörden devralınan `AI_STUDIO_BRIDGE=1`) çalışır. **Export edilen oyunlarda kendini hemen kaldırır**; autoload projede kalsa bile yayımlanan oyununuz etkilenmez.
- Dış ağdan erişilemez (`127.0.0.1`). Aynı makinedeki başka süreçler token'ı bilmedikleri için komut gönderemez.
- `godot_game_bridge action=disable` autoload'ı projeden kaldırır.

### Araç görünürlüğü

110 komutun hepsi ayrı araç olsaydı bazı sağlayıcıların 128 araç sınırı aşılırdı. Bu yüzden varsayılan olarak:

- sık kullanılan **16 komut** ayrı araçtır: ekran görüntüsü, tıklama, tuş, fare, UI listesi, sahne ağacı, eval, özellik okuma/yazma, metot çağırma, node bilgisi, performans, bekleme, input action, loglar, hatalar;
- diğer **94 komuta** `game_commands` (arama ve şema) ve `game_command` (çalıştırma) ile erişilir;
- **Ayarlar → "Expose every game command as its own tool"** açılırsa hepsi ayrı araç olur;
- **Ayarlar → "Offer runtime game tools (game_*)"** kapatılırsa oyun araçları modele hiç gösterilmez.

### Tipik kullanım

```
Sen:  Oyunu çalıştır, ana menüde "Başla" düğmesine bas ve oyuncunun zıplayıp zıplamadığını kontrol et.
Model: godot_game_bridge(status) → gerekirse enable → godot_play_scene
       → game_get_ui → game_click(Başla) → game_wait(30)
       → game_key_press(action="jump") → game_get_property(Player, velocity)
       → game_screenshot → game_get_errors
```

---

## MCP sunucuları

AI Studio bir **MCP istemcisidir**. [Model Context Protocol](https://modelcontextprotocol.io) sunucularının araçlarını modele ekler.

- **Taşıma katmanları**:
  - **stdio**: komut, argümanlar, ortam değişkenleri ve çalışma klasörü verilir. Windows'ta varsayılan olarak *shell wrap* ile `cmd /c` üzerinden çalışır; `npx` gibi komutlar için gereklidir.
  - **HTTP (Streamable HTTP)**: URL ve isteğe bağlı başlıklar verilir. `application/json` ve `text/event-stream` (SSE) yanıtları desteklenir. `Mcp-Session-Id` otomatik taşınır.
- **Protokol sürümü**: `2025-11-25`.
- **Desteklenen istekler**:
  - `tools/list`, `tools/call`;
  - `notifications/tools/list_changed` (araç listesi otomatik yenilenir);
  - sunucudan gelen `roots/list`, `ping` ve `sampling/createMessage`.
- **Araç adları**: `mcp_<sunucu>_<araç>` biçimindedir. `[A-Za-z0-9_-]` dışındaki karakterler temizlenir ve ad 64 karaktere kısaltılır, çünkü bazı sağlayıcılar diğer adları reddeder.
- **Sunucu tanımı** (`config.cfg` veya `.ai_studio.json` içinde):

```json
{
  "enabled": true,
  "transport": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "."],
  "env": {},
  "cwd": "",
  "shell_wrap": false,
  "url": "",
  "headers": {},
  "tool_allow": [],
  "tool_deny": [],
  "auto_approve": false,
  "notes": ""
}
```

- `tool_allow` / `tool_deny`: sunucunun hangi araçlarının modele gösterileceğini süzer.
- `auto_approve`: bu sunucunun araçları onay sormadan çalışır.
- **Sampling**: sunucular modelden tamamlama isteyebilir. `mcp/allow_sampling` ile açılıp kapanır; yanıt uzunluğu `mcp/sampling_max_tokens` ile (varsayılan 2048) sınırlanır.
- **Zaman aşımları**: başlatma 15 sn (`startup_timeout_ms`), araç çağrısı 120 sn (`tool_timeout_ms`).

### Hermes Agent hazır ayarları

| Hazır ayar | Tanım |
|---|---|
| Hermes Agent (stdio) | `hermes mcp serve` |
| Hermes Agent (HTTP) | `http://127.0.0.1:8765/mcp`; sunucuyu `hermes serve-mcp --transport http --port 8765` ile başlatın |

Hermes'i [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) adresinden kurabilirsiniz.

---

## Ayarlar

Tüm ayarlar `user://ai_studio/config.cfg` dosyasında saklanır ve çoğu **Model** sekmesindeki *Agent behaviour* bölümünden değiştirilebilir.

### `general`

| Anahtar | Varsayılan | Arayüzdeki adı / açıklama |
|---|---|---|
| `mode` | `agent` | Chat sekmesindeki Agent/Chat seçimi. |
| `stream` | `true` | *Stream responses (recommended)*: yanıtlar akışlı gelir. |
| `temperature` | `0.4` | Örnekleme sıcaklığı. Reddeden sağlayıcılarda otomatik gönderilmez. |
| `max_tokens` | `0` | Yanıt başına en fazla token; `0` sağlayıcının varsayılanını kullanır. |
| `max_tool_steps` | `12` | *Max tool steps per message* (1–50). |
| `request_timeout_sec` | `180` | *Request timeout (seconds)*. |
| `confirm_mutations` | `true` | *Ask before tools change the project*. |
| `approve_mcp_tools` | `true` | *Ask before MCP tools run*. |
| `auto_approve_safe_tools` | `true` | Salt okunur yerleşik araçlar hiç sormaz. |
| `include_scene_context` | `true` | *Include the current scene tree in context*. |
| `include_selection` | `true` | *Include the selected nodes in context*. |
| `include_project_settings` | `false` | *Include project settings in context (large)*. |
| `save_sessions` | `true` | *Save conversations to user://ai_studio/sessions*. |
| `store_keys_in_config` | `true` | *Store the API key in the local config file*. Kapalıyken anahtarlar yalnızca ortam değişkenlerinden okunur. |
| `game_tools` | `true` | *Offer runtime game tools (game_\*)*. |
| `expose_all_game_commands` | `false` | *Expose every game command as its own tool* (+100 araç). |
| `system_prompt` | yerleşik | *System prompt*; *Reset to default* ile geri alınır. |

### `ui`

| Anahtar | Varsayılan | Açıklama |
|---|---|---|
| `show_tool_cards` | `true` | Araç kartlarını sohbette göster. |
| `max_context_lines` | `400` | Bağlam bloğunun en fazla satır sayısı. |
| `last_tab` | `0` | Son açık sekme (otomatik). |

### `mcp`

| Anahtar | Varsayılan | Açıklama |
|---|---|---|
| `enabled` | `true` | MCP desteği. |
| `auto_connect` | `true` | Editör açılınca etkin sunuculara bağlan. |
| `allow_project_servers` | `false` | *Trust this project's servers*. |
| `startup_timeout_ms` | `15000` | Sunucu başlatma zaman aşımı. |
| `tool_timeout_ms` | `120000` | Araç çağrısı zaman aşımı. |
| `protocol_version` | `2025-11-25` | İstenen MCP protokol sürümü. |
| `allow_sampling` | `true` | Sunucuların `sampling/createMessage` isteklerini yanıtla. |
| `sampling_max_tokens` | `2048` | Sampling yanıtı en fazla token. |
| `servers` | `{}` | Sunucu tanımları (bkz. [MCP sunucuları](#mcp-sunucuları)). |

### `providers/<id>`

Her sağlayıcı için `api_key`, `base_url`, `model` ve `extra_headers` ayrı saklanır. Ayrıca reddedilen istek alanlarıyla ilgili hatırlanan fallback bayrakları da burada tutulur; silinirlerse tam istekle yeniden başlanır.

---

## Projeye özel ayarlar: `.ai_studio.json`

Ekip olarak paylaşılacak, **gizli olmayan** ayarlar projenin köküne `res://.ai_studio.json` olarak konabilir:

```json
{
  "general": { "model": "premium-coding" },
  "providers": { "9router": { "base_url": "http://192.168.1.20:20128/v1" } },
  "mcp": { "servers": { "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "."] } } }
}
```

- **Ayarlayabilecekleri**: model seçimi, adresler, MCP sunucu tanımları ve diğer zararsız ayarlar.
- **Ayarlayamayacakları** (sessizce yok sayılır):
  - `api_key`;
  - `system_prompt`;
  - `confirm_mutations`, `approve_mcp_tools`, `auto_approve_safe_tools`;
  - `game_tools`, `expose_all_game_commands`;
  - MCP otomatik başlatma ve sampling izinleri.
- **Projedeki MCP sunucuları**: MCP sekmesinde **Trust this project's servers** işaretlenmeden **başlatılmaz**. Böylece bir projeyi açmak, makinenizde kendiliğinden bir süreç başlatamaz.

---

## Dosyaların saklandığı yerler

| Yol | İçerik |
|---|---|
| `user://ai_studio/config.cfg` | Ayarlar ve API anahtarları. Hiçbir zaman proje klasöründe değildir; Unix'te `chmod 600`. |
| `user://ai_studio/sessions/` | Kaydedilen konuşmalar. |
| `user://ai_studio/shots/` | Editör ve oyun ekran görüntüleri. |
| `user://ai_studio/backups/refs_<zaman>/` | Animasyon referansı güncellemelerinden önce alınan dosya yedekleri. |
| `<dosya>.bak` | `godot_write_file` ve bazı kaynak/import araçlarının üzerine yazdığı dosyanın önceki hâli. |
| `<model>_anim_names.gd` | `godot_import_animation_names action=apply` ile üretilen post-import betiği (modelin yanında). |
| `res://.ai_studio.json` | İsteğe bağlı, ekip ayarları. |

`user://` yolu işletim sistemine göre değişir. Örneğin Linux'ta `~/.local/share/godot/app_userdata/<Proje>/`, Windows'ta `%APPDATA%\Godot\app_userdata\<Proje>\`.

---

## Ortam değişkenleri

| Değişken | Amaç |
|---|---|
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `NOUS_API_KEY`, `OPENROUTER_API_KEY`, `NINE_ROUTER_API_KEY`, `ROUTER_API_KEY`, `AI_STUDIO_*_API_KEY` | Sağlayıcı anahtarları; yapılandırma dosyasından önce gelir (tam liste: [Sağlayıcılar](#sağlayıcılar-ve-modeller)). |
| `AI_STUDIO_SMOKE_TEST=1` | Editör açılınca kendi kendini test eder ve çıkar. |
| `AI_STUDIO_SMOKE_TEST_SCENE=res://...` | Smoke test sırasında bu sahneyi açıp düzenleme araçlarını da dener. |
| `AI_STUDIO_BRIDGE`, `AI_STUDIO_BRIDGE_PORT`, `AI_STUDIO_BRIDGE_TOKEN` | Editörün oyuna ilettiği köprü ayarları. Elle ayarlamanız gerekmez. |

---

## Kurulumu doğrulama (smoke test)

```bash
AI_STUDIO_SMOKE_TEST=1 godot --headless --editor --path /proje/yolu
```

Her kontrol için bir `ok` / `FAIL` satırı yazdırır, sonunda `=== smoke test: N passed, M failed ===` özetini verir. Hata yoksa `0`, varsa `1` koduyla çıkar. Kontrol edilenler:

- EditorInterface erişimi, eklenti ikonu;
- dock'un sahnede olması ve beş sekmesi (Chat/Model/MCP/Tools/Help), her sekmenin açılabilmesi;
- araç kaydının dolu olması (en az 20 araç) ve ajanın araçları sunması;
- LLM istemcisinin boşta olması, MCP yöneticisinin durum bildirmesi, sağlayıcının seçili olması;
- editör bağlamının üretilmesi;
- `godot_project_info` ve `godot_scene_tree` araçlarının editör içinde çalışması;
- bilgi olarak MCP sunucuları ve sundukları araç sayıları.

`AI_STUDIO_SMOKE_TEST_SCENE=res://level.tscn` verilirse o sahne açılır ve düzenleme araçları sırayla çalıştırılır: node, materyal, fizik, kamera, ışık, kaydetme.

---

## Örnek istekler ve iş akışları

**Projeyi tanıma**
- "Projeyi incele: ana sahne, autoload'lar, input action'lar ve klasör yapısı nedir?"
- "`Player` node'u neden zıplamıyor? Betiğini ve input map'i kontrol et."

**Sahne kurma**
- "Açık 3D sahneye 20×20 zemin, gölgeli güneş, gökyüzü ve oyuncuya bakan bir kamera ekle."
- "Seçili MeshInstance3D'ye mesh'ine uygun çarpışmalı bir StaticBody3D ekle."
- "`res://levels/level2.tscn` dosyasını açmadan içine `res://enemies/slime.tscn`'den üç tane ekle."

**Betikler**
- "Değişen tüm betikleri derle, hataları düzelt ve tekrar derle."
- "`CharacterBody2D` için basit bir platformer hareket betiği yaz ve `Player`'a bağla."

**Animasyon ve rig**
- "`character.glb` içindeki animasyon adları `Armature|Run` gibi. Hepsini `run` gibi snake_case yap. Kalıcı olsun ve betiklerdeki `play()` çağrılarını da güncelle."
  - Model `godot_import_animation_names` ile önce `list`, sonra `apply`; ardından `godot_animation_find_references` ile önce önizleme, sonra `apply` yapar.
- "`AnimationPlayer`'daki `Walk` animasyonunu `walk` yap ve AnimationTree'deki durumları da güncelle."
  - Model `godot_animation_rename` ile önce `dry_run`, sonra uygulama yapar.
- "Mixamo animasyonları karakterimde oynamıyor, neden?"
  - Model `godot_animation_tracks` → `godot_create_bone_map` → `godot_animation_edit` veya `godot_retarget_animation` kullanır.

**Proje ve export**
- "`pause` adında Escape'e bağlı bir input action ekle."
- "Windows ve Linux export preset'leri oluştur, Linux'u `build/` klasörüne export et."
- "Bu proje için her push'ta export eden bir GitHub Actions workflow'u yaz."

**Çalışan oyun**
- "Oyunu başlat, ekran görüntüsü al ve konsoldaki hataları göster."
- "Oyuncu 5 saniye sağa yürüsün, sonra FPS ve node sayısını raporla."

**Editör betiği ve günlük**
- "Projedeki tüm `Sprite2D` dokularında filtrelemeyi `nearest` yap." (`godot_run_editor_script` ile, her zaman onaylı)
- "Son değişiklikten sonra editörde hata var mı?" (`godot_editor_log`)

---

## Sorun giderme

| Belirti | Neden / çözüm |
|---|---|
| Eklenti listede görünmüyor | Klasör bir seviye fazla iç içe. Doğru yol `<proje>/addons/ai_studio/plugin.cfg`. |
| Eklenti yüklenirken betik hataları | Godot sürümü 4.7'den eski. 4.7+ kullanın. |
| `HTTP 401` / *Authentication failed* | Anahtar yanlış veya eksik. Anahtar önce ortam değişkenlerinden okunur; Model sekmesi kullanılan anahtarın kaynağını gösterir. |
| `/chat/completions` için `HTTP 404` | Adreste `/v1` eksik ya da panel portuna işaret ediyor. Adresi *Apply* ile uygulayıp düzeltilmiş değeri kontrol edin. |
| `HTTP 400 ... stream_options` / `tools` / `temperature` | Otomatik fallback uygulanır (bkz. [Otomatik geri çekilmeler](#otomatik-geri-çekilmeler-fallback)). |
| Model araç kullanmıyor | Mod *Chat* olabilir ya da model araç çağırmayı desteklemiyor olabilir. Durum satırında "retrying without tools" görüyorsanız başka bir model seçin. |
| Model yarıda duruyor | *Max tool steps per message* sınırına ulaşıldı. "Devam et" yazın veya sınırı artırın. |
| `game_*` araçları "The game is not running" diyor | `godot_game_bridge action=enable` çalıştırın, ardından oyunu **editörden** yeniden başlatın. |
| Sağlayıcı "too many tools" hatası veriyor | *Expose every game command as its own tool* seçeneğini kapatın veya MCP sunucularında `tool_allow` kullanın. |
| Proje MCP sunucusu başlamıyor | MCP sekmesinde *Trust this project's servers* işaretli değil. |
| Windows'ta `npx` MCP sunucusu başlamıyor | Sunucu kartında *shell wrap*'i açın. |
| Animasyon adları yeniden içe aktarmada geri geliyor | Sahnede değil import'ta düzeltin: `godot_import_animation_names action=apply`. |
| Referans güncellemesi bazı dosyaları atladı | Eski ad o dosyada hâlâ başka bir animasyon olarak tanımlı ya da satır belirsiz. Rapor bunları listeler; elle kontrol edin veya `godot_animation_find_references` kullanın. |
| Yanlış bir değişikliği geri almak | Açık sahne: Ctrl+Z. Dosyalar: `.bak` veya `user://ai_studio/backups/`. Silinenler: çöp kutusu. |

---

## Dosya yapısı

```
addons/ai_studio/
├── plugin.cfg
├── ai_studio_plugin.gd          EditorPlugin giriş noktası (dock, servisler, smoke test)
├── core/
│   ├── ai_config.gd             ayarlar, anahtarlar, .ai_studio.json, MCP sunucu tanımları
│   ├── providers.gd             sağlayıcı tablosu (adresler, protokoller, env değişkenleri)
│   ├── llm_client.gd            OpenAI / Anthropic / Gemini istemcisi, fallback'ler
│   ├── http_stream.gd           SSE akış okuyucu
│   ├── http_util.gd             HTTP yardımcıları
│   ├── mcp/                     MCP istemcisi, yönetici, stdio ve HTTP taşıma katmanları
│   ├── util/                    ortak yardımcılar
│   └── agent/
│       ├── agent_session.gd     ajan döngüsü, onaylar, araç adımları
│       ├── editor_context.gd    her isteğe eklenen editör bağlamı
│       ├── godot_tools.gd       araç kaydı + bağlam, dosya, sahne, gezinme araçları
│       ├── godot_3d_tools.gd    rig, animasyon, 3D, import araçları
│       ├── godot_mcp_tools.gd   sahne dosyası, kaynak, betik, proje, export araçları
│       ├── godot_anim_tools.gd  animasyon adı, referans, düzenleme, editör betiği, günlük
│       ├── anim_name_rules.gd   animasyon adı kuralları (önizleme = import betiği)
│       ├── editor_log.gd        editör hata/uyarı günlüğü (Logger)
│       ├── godot_game_bridge.gd oyun köprüsü istemcisi ve game_* araçları
│       └── godot_game_catalog.gd 110 oyun komutunun kataloğu
├── runtime/
│   ├── game_bridge_server.gd    oyun içi köprü sunucusu (autoload)
│   └── LICENSE.godot-mcp.txt
├── ui/                          dock, chat, model ayarları, MCP görünümü, markdown, ikonlar
└── docs/
    ├── providers.md             sağlayıcılar, 9Router, ortam değişkenleri (İngilizce)
    └── tools.md                 araçlar ve güvenlik kuralları (İngilizce)
```

---

## Bu sürümdeki değişiklikler

- **godot-mcp araçları eklentiye taşındı**: Node.js sunucusu ve ek Godot süreci gerekmez.
  - Sahne dosyaları, kaynaklar, betikler, proje yapılandırması ve export için 28 editör aracı eklendi.
  - 110 çalışma zamanı komutuyla oyun köprüsü eklendi.
- **Animasyon adı araçları**:
  - animasyon, kütüphane ve SpriteFrames adlarını tüm referanslarıyla yeniden adlandırma;
  - içe aktarılan modellerdeki adları üretilen bir post-import betiğiyle kalıcı olarak düzeltme;
  - animasyonları yerinde düzenleme: track yolları, kemikler, bozuk track'ler, döngü, hız, kopyalama/taşıma.
- **Editör araçları**: `godot_run_editor_script` ve `godot_editor_log`.
- **9Router ve model kimlikleri**:
  - 9Router hazır ayarı eklendi;
  - serbest model kimlikleri, router takma adları ve combo adları güvenilir biçimde kaydediliyor ve sağlayıcı başına saklanıyor.
- **Adres düzeltme**: yolu olmayan adreslere `/v1` ekleniyor.
- **Otomatik yeniden deneme**: reddedilen alanlar (`stream_options`, `tools`, `temperature`) olmadan yeniden deneniyor ve bu tercih hatırlanıyor.
- **Proje dosyası kısıtlamaları**:
  - projeyle gelen MCP sunucuları izinsiz başlamıyor;
  - `.ai_studio.json` anahtarları, sistem istemini ve onay ayarlarını değiştiremiyor.
- **Godot 4.7 uyumluluk düzeltmeleri**:
  - Variant tür çıkarımı ve `substr` düzeltmeleri;
  - `llm_client.gd`'deki eksik `return` düzeltildi (`ai_studio_plugin.gd:25` "Nonexistent function 'new'" hatası).

---

## Lisans ve teşekkür

- Oyun köprüsünün komut seti ve oyun içi sunucusu [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) projesinden uyarlanmıştır: MIT Lisansı, © Tugcan Topaloglu ve Solomon Elias. Tam lisans metni: [`addons/ai_studio/runtime/LICENSE.godot-mcp.txt`](addons/ai_studio/runtime/LICENSE.godot-mcp.txt).
- [9Router](https://github.com/decolua/9router), [Hermes Agent](https://github.com/NousResearch/hermes-agent) ve [Model Context Protocol](https://modelcontextprotocol.io) ilgili projelerin kendi lisanslarına tabidir.
