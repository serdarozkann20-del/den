# AI Studio (Godot editör eklentisi) — Depo İncelemesi

Tarih: 2026-09-23 · Kapsam: `serdarozkann20-del/den` @ `b156d0a` (main) · Yöntem: statik kod incelemesi
(Godot kurulu olmadığı için **çalıştırmalı test yapılmadı**).

---

## 1. Özet (kısa)

| Konu | Durum |
|---|---|
| Proje türü | Godot 4.7+ editör eklentisi (`EditorPlugin`), GDScript |
| Depodaki dosyalar | 6 dosya: `plugin.cfg`, `ai_studio_plugin.gd` (+`.uid`), `icon.svg` (+`.import`), `README.md` |
| Eklenti çalışır mı? | **Hayır.** Giriş betiği 9 `class_name`'e referans veriyor, bu sınıfların kaynağı depoda yok |
| Kaynak kod nerede? | Depodan **silinen** `ai_studio-1.0.0.zip` içinde (8.606 satır, 22 `.gd`); Git nesnesi hâlâ GitHub'da duruyor |
| Kod kalitesi (zip içeriği) | **Yüksek.** Katmanlı mimari, undo/redo, onay akışı, şema temizleme, iyi yorumlanmış |
| Dokümantasyon | README, repoda **bulunmayan** 6 `docs/*.md` ve `tools/check_install.sh` dosyasına atıf yapıyor |

**En kritik iki gerçek:** (1) depo hâliyle kurulamaz, (2) depo hâliyle dağıtılamaz (dosya düzeni
`addons/ai_studio/` bekleyen Godot kurulumuna uygun değil).

---

## 2. Depo envanteri ve Git geçmişi

Yerel geçmiş tek commit'e sıkıştırılmış; GitHub'daki gerçek geçmiş 3 commit:

| Commit | İçerik |
|---|---|
| `647cbb98` | `ai_studio-1.0.0.zip` eklendi (105.894 B) |
| `7d5de4f1` | README + eklenti dosyaları kök dizine yüklendi |
| `b156d0a1` | `ai_studio-1.0.0.zip` **silindi** |

Zip silinmiş olsa da blob nesnesi hâlâ erişilebilir durumda:
`5a294101bd593a15b4b814049b279991a8346404` — içeriği tam eklenti kaynak ağacı:

```
addons/ai_studio/            54 girdi, 22 .gd, 8.606 satır, 411 KB
├── ai_studio_plugin.gd      (depodaki kopyayla birebir aynı)
├── plugin.cfg, icon.svg, README.md
├── core/
│   ├── ai_config.gd          AIStudioConfig        445 satır
│   ├── llm_client.gd         AIStudioLLMClient     803
│   ├── providers.gd          AIStudioProviders     200
│   ├── http_stream.gd        AIStudioHttpStream    277   (iş parçacığı + SSE)
│   ├── http_util.gd          AIStudioFetch         145
│   ├── util/editor_env.gd    AIStudioEditorEnv      29
│   ├── mcp/  json_rpc · mcp_client · mcp_manager · transport_stdio · transport_http
│   └── agent/ agent_session · editor_context · godot_tools · godot_3d_tools (1.944 satır)
└── ui/ ai_dock · chat_view · settings_view · mcp_view · markdown · icons
```

> Zip'i yeniden üretmek gerekmiyor: `git checkout 647cbb98 -- ai_studio-1.0.0.zip` yerine doğrudan
> blob çekilip açılabilir. Zip'in kök seviyesi zaten `addons/` (README'nin uyardığı "bir seviye
> derin" hatasının kaynağı bu).

---

## 3. Neden depo hâliyle çalışmıyor

`ai_studio_plugin.gd` yüklenirken şu sınıfları çözmeye çalışıyor, hiçbiri depoda tanımlı değil:

| `class_name` | Olması gereken dosya | Depoda |
|---|---|---|
| `AIStudioConfig` | `core/ai_config.gd` | ✗ |
| `AIStudioLLMClient` | `core/llm_client.gd` | ✗ |
| `AIStudioMcpManager` | `core/mcp/mcp_manager.gd` | ✗ |
| `AIStudioGodotTools` | `core/agent/godot_tools.gd` | ✗ |
| `AIStudioAgentSession` | `core/agent/agent_session.gd` | ✗ |
| `AIStudioEditorContext` | `core/agent/editor_context.gd` | ✗ |
| `AIStudioEditorEnv` | `core/util/editor_env.gd` | ✗ |
| `AIStudioIcons` | `ui/icons.gd` | ✗ |
| `AIStudioDock` | `ui/ai_dock.gd` | ✗ |

Sonuç: Godot eklentiyi etkinleştirmeye çalıştığında `_enter_tree()` içindeki ilk satırda
(`AIStudioConfig.new()`) ayrıştırma/çözümleme hatası alır; eklenti **yüklenmez**. README'nin
"Plugin görünmüyorsa arşivi bir seviye fazla derine açmış olabilirsiniz" notu bu tabloyu
gizliyor: sorun açma derinliği değil, dosyaların hiç olmaması.

Ek olarak README'de adı geçen ve depoda **bulunmayan** dosyalar:
`docs/providers.md`, `docs/mcp.md`, `docs/tools.md`, `docs/3d.md`, `docs/testing.md`,
`docs/install-troubleshooting.md`, `tools/check_install.sh`.

---

## 4. Mimari (zip içeriğinden)

```
EditorPlugin (ai_studio_plugin.gd)
 ├── AIStudioConfig          user://ai_studio/config.cfg · env öncelikli anahtarlar · res://.ai_studio.json
 ├── AIStudioLLMClient       openai | anthropic | gemini tel formatları, SSE akışı, araç çağrıları
 │    └── AIStudioHttpStream  worker Thread + HTTPClient, SSE/NDJSON, iptal & zaman aşımı
 ├── AIStudioMcpManager      sunucu başına 1 AIStudioMcpClient, mcp_<sunucu>_<araç> yönlendirme
 │    └── transport_stdio (OS.execute_with_pipe + 2 okuma iş parçacığı) | transport_http (Streamable HTTP)
 ├── AIStudioAgentSession    mesaj listesi + araç döngüsü + onay politikası (chat/agent modu)
 ├── AIStudioGodotTools      23 araç · AIStudioGodot3DTools 13 araç  → toplam 36
 └── AIStudioDock            5 sekme: Chat · Model · MCP · Tools · Help
```

Doğrulanan README iddiaları: **36 yerleşik araç** (23 çekirdek + 13 3B/rig/animasyon/materyal/fizik/import)
✓ · **9 sağlayıcı** (OpenAI, Anthropic, Google native, Google OpenAI-uyumlu, Nous Portal, OpenRouter,
Hermes Agent yerel proxy, Ollama, LM Studio, Custom) ✓ · stdio+HTTP MCP ✓ · Hermes Agent hazır ayarları ✓ ·
5 sekme ✓ · smoke test gömülü ✓ · anahtarların projede tutulmaması ✓.

İyi mühendislik örnekleri: `_validate_project_path()` (res:// kilidi, `..`, `.godot/`, `.git/` ve
eklentinin kendi klasörüne yazma engeli), `EditorUndoRedoManager` ile geri alınabilir sahne düzenlemeleri,
`_clean_schema()`/`_gemini_schema()` ile sağlayıcıya göre şema sadeleştirme, anthropic için ardışık
rol birleştirme, `AIStudioEditorEnv` ile editör dışı çalıştırmalarda güvenli düşüş, `_restrict_permissions()`
ile config dosyasına `chmod 600`.

---

## 5. Kod bulguları

### 5.1 Yüksek önem — `.ai_studio.json` klonlanan projede komut çalıştırabiliyor (güvenlik)

`AIStudioConfig.mcp_servers()` proje dosyasındaki `mcp.servers` tanımlarını birleştiriyor;
`connect_all()` bunları `auto_connect` (varsayılan **açık**) ile, düzenleyici projeyi açtıktan ~1 sn sonra
**onay sormadan** başlatıyor. Klonlanan güvenilmeyen bir projedeki `.ai_studio.json`:

```json
{ "mcp": { "servers": { "x": { "command": "sh", "args": ["-c", "…"] } } } }
```

…kullanıcının makinesinde komut çalıştırır. `normalise_server()` `enabled`'ı varsayılan `true`,
`transport`'u `command` varsa `stdio` yapar; yani tanımın tek satır olması yeterli.
Depo kökenli MCP tanımları için en azından "bir kez onayla" akışı veya varsayılan kapalı olması önerilir.

### 5.2 Orta önem — gerçek hatalar

| # | Yer | Bulgu |
|---|---|---|
| a | `llm_client.gd:291` | Yorum "sağlayıcı `stream_options`'u anlamazsa `_retry_hint()` içindeki yeniden deneme halleder" diyor; **`_retry_hint()` diye bir fonksiyon yok**. Yani `{"stream_options": {"include_usage": true}}` her OpenAI-uyumlu uca koşulsuz gönderiliyor; alanı reddeden uçlarda (eski Ollama/LM Studio sürümleri, bazı proxy'ler) 400 riski var ve iddia edilen geri düşüş yok. |
| b | `ai_config.gd:get_value()` | `data` her zaman `DEFAULTS` ağacını içerdiği için `sec.has(key)` daima doğru; **`res://.ai_studio.json` içindeki `general`/`ui`/`mcp` skaler geçersiz kılmaları hiçbir zaman uygulanmıyor** (ör. takım geneli `mcp.auto_connect=false` sessizce yok sayılır). Geçersiz kılma yalnızca `mcp.servers` ve `providers.<id>` için (o da config'te yoksa) işliyor — yani hem ölü özellik hem de 5.1'deki vektör. |
| c | `agent_session.gd:80` | `is_waiting_for_approval()` içindeki `_current_calls` hiçbir yerde atanmıyor → fonksiyon pratikte yalnızca `_decisions`'a bakıyor, adı vaat ettiği durumu yanlış raporluyor (ölü alan). |
| d | `mcp_manager.gd:281` | `state == STATE_ERROR or state == STATE_CLOSED and detail != "disconnected"` — operatör önceliği okuyucuyu yanıltıyor; parantezlenmeli. Niyet "kapandı **ve** sebebi kullanıcı değilse hata" ise davranış doğru ama kırılgan. |
| e | `ai_config.gd:137-147` | Her `save()` çağrısında (MCP düzenleme, sekme değişimi vb. dahil) `chmod` için yeni işlem başlatılıyor; ayrıca `store_keys_in_config=false` iken de çalışıyor. Sadece dosya gerçekten yazıldığında ve yalnızca POSIX'te çalıştırmak yeterli olurdu. |
| f | `ai_config.gd:load_from_disk()` | `ConfigFile` bölümleri `mcp` ve `mcp/servers/<ad>` olarak iki biçimde yazılıyor; yükleme, bölümlerin geliş sırasına göre `loaded["mcp"]` sözlüğünü tümden ezebiliyor. Bugün ConfigFile'ın sözlüğü geri okuması sayesinde çalışıyor (kırılgan, sıraya bağlı). Tek biçime indirgemek (yalnızca `mcp/servers/<ad>` bölümleri) daha sağlam. |
| g | `http_stream.gd:join()` | `join(ms: int = 3000)` parametresi hiç kullanılmıyor; `wait_to_finish()` zaman aşımı olmadan bekliyor. İş parçacığı kendi içinde son teslim tarihine sahip olduğu için pratikte kilitlenme beklenmez, ama imza yanıltıcı. |

### 5.3 Düşük önem / iyileştirme

- `AIStudioFetch.use_threads = true` + her istek için ağaçtan düğüm ekleme/çıkarma: yoğun araç
  döngülerinde gereksiz yük. `HTTPRequest` yeniden kullanılabilir ya da `HTTPClient` yoluna birleştirilebilir.
- `_restrict_permissions()` dışında config dosyası bütünlüğü yok; `save()` dönen hatayı çoğu çağrı
  yerinde kontrol etmiyor (`set_value(..., autosave=true)` sonucu yutuyor) — kullanıcıya "kaydedilemedi" uyarısı çıkmıyor.
- `AIStudioConfig.redact()` var ama ayar ekranındaki anahtar alanı hariç hiçbir yerde kullanılmıyor;
  `key_source()` iyi bir fikir, arayüzde de gösterilmeli.
- `providers.gd` `hints` alanları zamanla eskiyecek (`gpt-5.1`, `claude-sonnet-4-6`, `gemini-3.1-pro`);
  kod bunu "sadece kolaylık, beyaz liste değil" diye işaretlemiş — doğru yaklaşım, ama README'de de bu
  belirtilmeli ki kullanıcı liste güncel değilken panik yapmasın.
- Test altyapısı iddiası (`docs/testing.md`: "mock sunucular, smoke test, install check") repoda
  **hiç yok**. Gömülü smoke test (`AI_STUDIO_SMOKE_TEST=1`) ve `AI_STUDIO_SMOKE_TEST_SCENE` senaryosu
  gerçekten etkileyici; bunları bir CI işine bağlayacak Godot ikili dosyası ve test betiği eksik.

---

## 6. Doğrulama durumu ve sınırlar

- Godot 4.7 sandbox'ta **kurulu değil** → `--headless --editor` smoke testi, davranış testleri ve
  özellikle 4.7'ye özgü API'ler (`OS.execute_with_pipe`, `EditorInterface.get_editor_undo_redo()`,
  `EditorToaster`) bu incelemede **çalıştırılamadı**. Bu API'lerin varlığı koddaki kullanımla
  tutarlı, ancak çalışma zamanı doğrulaması yapılmadı.
- ZIP içeriği `refs/remotes/origin/main` ile karşılaştırıldı; kökteki `ai_studio_plugin.gd`,
  `README.md`, `plugin.cfg`, `icon.svg` dosyaları zip kopyalarıyla **aynı** (yalnızca içerik eksik).
- İnceleme statiktir: yukarıdaki hatalar kod okumasıyla çıkarıldı, dinamik olarak üretilmedi.

---

## 7. Önerilen sıra

1. **Kaynağı geri getir** — `addons/ai_studio/…` düzenini depoya yaz (zip'ten), kökteki kopyaları
   kaldır. Böylece depo hem Godot'a doğrudan `addons/ai_studio` olarak kopyalanabilir hale gelir
   hem de GitHub zip'i doğru kök seviyesini taşır.
2. **Güvenlik** — 5.1: depo kökenli MCP tanımları için onay adımı / varsayılan kapalı.
3. **5.2a ve 5.2b** — `stream_options` geri düşüşü ve proje geçersiz kılmalarının gerçekten uygulanması
   (ikisi de "dokümante edilmiş ama çalışmayan" davranış).
4. **Dokümanları yaz** — `docs/*.md`, `tools/check_install.sh`; README'deki bağlantılar böylece kırılmaz.
5. **Paketleme** — sürüm etiketi verildiğinde `addons/ai_studio` içeriğini `ai_studio-<sürüm>.zip`
   olarak üreten küçük bir GitHub Actions işi; 1.0.0 zip'i bu yüzden elle üretilmişti.
6. **Küçük temizlik** — `_current_calls` (c), parantez (d), `join(ms)` (g), chmod (e).

---

## 8. Düzeltme durumu (bu dalda yapıldı)

| Bulgu | Durum |
|---|---|
| 3 (kaynak dosyalar yok) | **Çözüldü** — 22 `.gd` dosyası `addons/ai_studio/` altına yazıldı, kökteki kopyalar kaldırıldı |
| 5.1 (proje dosyası komut çalıştırabiliyor) | **Çözüldü** — `mcp.allow_project_servers` varsayılan kapalı; proje sunucuları MCP sekmesinde "project file" rozetiyle listeleniyor ve ancak *Trust this project's servers* işaretlenince başlıyor |
| 5.2a (`_retry_hint` hayalet) | **Çözüldü** — gerçek geri düşüş zinciri: `stream_options` → `tools` → `temperature`, sağlayıcı başına hatırlanıyor (`omit_*`) |
| 5.2b (proje geçersiz kılmaları ölü) | **Çözüldü** — geçersiz kılmalar artık uygulanıyor; güvenlik anahtarları (`api_key`, `system_prompt`, onay anahtarları, MCP otomatik başlatma) kara listede |
| 5.2c (`_current_calls`) | **Çözüldü** — `_pending_approvals` ile gerçek durum |
| 5.2d (operatör önceliği) | **Çözüldü** — parantezlendi |
| 5.2e (her kayıtta chmod) | **Çözüldü** — yalnızca anahtar saklandığında çalışıyor |
| 5.2f (ConfigFile bölüm çakışması) | **Çözüldü** — sunucular tek biçimde yazılıyor, yükleme sıraya bağlı değil |
| 5.2g (`join(ms)`) | **Çözüldü** — zaman aşımına saygılı |
| 9Router + combo model | **Eklendi** — ayrı sağlayıcı ön ayarı, `/v1` normalizasyonu, serbest model girişi (Enter/odak kaybı/*Use typed model*), sağlayıcı başına model hatırlama, `docs/providers.md` |
| README'deki kırık doküman bağlantıları | **Kısmen** — `docs/providers.md` yazıldı; diğer rehberler ve `tools/check_install.sh` hâlâ yok, README yalnızca var olanları gösteriyor |
| Paketleme iş akışı (GitHub Actions) | Açık — öneri olarak duruyor |
