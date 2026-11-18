# Spesifikasi Kebutuhan Aset Pixel Art & Audio — Nusantara Farm: Petualangan Desa

Dokumen ini menjadi daftar belanja produksi (*asset & audio checklist*) untuk dikerjakan secara terpisah sebelum atau bersamaan dengan implementasi di Godot 4. Seluruh ukuran, format, jumlah *frame*, dan konvensi penamaan telah disesuaikan dengan standar viewport **`480 x 270 px`** dan grid **`16 x 16 px`**.

---

## Daftar Isi
1. [Standar Teknis Ekspor Pixel Art](#1-standar-teknis-ekspor-pixel-art)
2. [Aset A: Karakter Playable (Budi & Mitha)](#2-aset-a-karakter-playable-budi--mitha)
3. [Aset B: NPC Warga Desa & Potret Dialog](#3-aset-b-npc-warga-desa--potret-dialog)
4. [Aset C: Tileset Lingkungan & Bangunan](#4-aset-c-tileset-lingkungan--bangunan)
5. [Aset D: Tanaman, Pohon & Tahap Pertumbuhan](#5-aset-d-tanaman-pohon--tahap-pertumbuhan)
6. [Aset E: Ikon Item, Stasiun Produksi & VFX](#6-aset-e-ikon-item-stasiun-produksi--vfx)
7. [Aset F: UI, HUD, Peta & Layar Menu](#7-aset-f-ui-hud-peta--layar-menu)
8. [Spesifikasi Audio: BGM, Ambience & SFX](#8-spesifikasi-audio-bgm-ambience--sfx)

---

## 1. Standar Teknis Ekspor Pixel Art

- **Format File:** `.png` (32-bit RGBA, latar belakang transparan penuh, **tanpa** *anti-aliasing* atau blur di tepi piksel).
- **Skala Kerja:** Gambar selalu di skala **1x piksel asli** (misal tile `16x16` digambar benar-benar pada kanvas `16x16 px`, **bukan** `160x160` yang diperbesar). Godot akan melakukan *upscale* secara tajam melalui filter `Nearest`.
- **Format Sprite Sheet:** Disusun rapi dalam grid seragam (kolom = frame animasi, baris = arah atau state) dengan jarak `0 px` (*no padding/margin* agar mudah di-slice di `AnimatedSprite2D`).
- **Pivot Karakter:** Kaki karakter selalu menapak di tengah-bawah sel kanvas (`16x32` → kaki berada di `x=8, y=31`).
- **Palet Warna Acuan (Dari Mockup Proposal):**
  - Tropis hangat dan ramah: hijau dedaunan sawah cerah, cokelat tanah subur, genteng terakota kemerahan, kayu jati & bambu keemasan, aksen biru/merah/ungu kain batik pada atap pasar & pakaian warga.
  - Hindari hitam pekat `#000000` untuk outline bila memungkinkan; gunakan cokelat tua / hijau sangat gelap agar terasa hangat dan organik ala *Stardew Valley*.

---

## 2. Aset A: Karakter Playable (Budi & Mitha)

Karakter menggunakan kanvas **`16 x 32 px`** per frame (bagian badan `16x24`, sisa atas untuk topi caping & ruang ayunan tangan/alat). Jika memakai animasi cangkul/siraman yang lebar, gunakan kanvas **`32 x 32 px`** per frame dengan karakter tetap berpusat di tengah.

| ID Aset | Nama File Rekomendasi | Ukuran Frame | Arah & Jumlah Frame | Prioritas | Keterangan |
| :--- | :--- | :---: | :--- | :-: | :--- |
| `CHR_BUDI_BASE` | `res://assets/characters/budi_movement.png` | `16x32 px` | **4 Arah** (Bawah, Atas, Kanan, Kiri*). Idle: `2 frame`, Jalan: `4 frame` | **Fase 1** | Pemuda bertopi caping, kemeja kerja cokelat/krem, celana biru. (*Kiri bisa flip horizontal dari Kanan*). |
| `CHR_BUDI_TOOLS` | `res://assets/characters/budi_tools.png` | `32x32 px` | **4 Arah** x `3 frame` per aksi: Cangkul, Siram (Gembor), Tebang (Kapak), Tanam/Panen | **Fase 1** | Alat digambar menyatu atau terpisah layer agar mudah di-upgrade warna alatnya. |
| `CHR_BUDI_SLEEPY` | `res://assets/characters/budi_sleepy.png` | `16x32 px` | Bawah/Depan: `3 frame` menguap + mata sayu | **Fase 1** | Diputar sesekali saat terkena **Debuff Mengantuk**. |
| `CHR_MITHA_BASE` | `res://assets/characters/mitha_movement.png` | `16x32 px` | **4 Arah**: Idle `2 frame`, Jalan `4 frame` | **Fase 1** | Pemudi bertopi caping/pita desa, baju pedesaan selaras dengan Budi. |
| `CHR_MITHA_TOOLS` | `res://assets/characters/mitha_tools.png` | `32x32 px` | **4 Arah** x `3 frame` per aksi (Cangkul, Siram, Kapak, Tanam/Panen) | **Fase 1** | Sama dengan set aksi Budi. |
| `CHR_MITHA_SLEEPY` | `res://assets/characters/mitha_sleepy.png` | `16x32 px` | Depan: `3 frame` menguap | **Fase 1** | Animasi Debuff Mengantuk untuk Mitha. |
| `CHR_COOP_TINT` | *(Opsi Palet / Ikon Caping)* | `16x16 px` | 4 warna penanda topi/pita (Merah, Biru, Hijau, Kuning) | **Fase 1** | Opsional jika 2+ pemain Co-op memilih karakter yang sama agar tetap mudah dibedakan. |
| `CHR_PHASE2_ACT` | `*_fishing.png`, `*_mining.png` | `32x32 px` | Lempar & tarik pancing (`4 frame`), ayun beliung (`3 frame`) x 4 arah | **Fase 2** | Untuk Budi & Mitha saat Memancing & Menambang. |

### Potret Wajah Karakter Playable
- `PRT_BUDI` & `PRT_MITHA`: Ukuran **`48 x 48 px`** (masing-masing 3 ekspresi: `normal`, `senang`, `mengantuk`) untuk layar *Profil Pak Tani*, *Buat Karakter*, *Lobby LAN*, dan *Peta Besar* (pin ikon mini `16x16 px`).

---

## 3. Aset B: NPC Warga Desa & Potret Dialog

Setiap NPC membutuhkan **Sprite Dunia (`16 x 32 px`)** dan **Potret Dialog (`48 x 48 px`)** dengan bingkai bahu hingga kepala.

| ID Aset | Nama NPC | Sprite Dunia (`16x32 px`) | Potret Dialog (`48x48 px`) | Prioritas | Catatan Desain Visual |
| :--- | :--- | :--- | :--- | :-: | :--- |
| `NPC_PAK_TANI` | **Pak Tani (Mbah Karto)** | Idle `2f`, Jalan `4f` (4 arah) | `normal`, `senang`, `serius` | **Fase 1** | Kakek berjenggot putih rapi, baju lurik hijau-cokelat. |
| `NPC_NISRINA` | **Nisrina** | Idle `2f`, Jalan `4f`, Jaga Kios `2f` | `normal`, `senang`, `ramah` | **Fase 1** | Wanita berkebaya batik biru, rambut kepang samping dengan bunga kamboja/melati. |
| `NPC_KADES` | **Kepala Desa (Pak Kades)** | Idle `2f`, Jalan `4f` (4 arah) | `normal`, `senang`, `tegas/kecewa` (untuk teguran Eco-Meter!) | **Fase 1** | Pria berwibawa berkumis/janggut putih, baju adat/batik desa cokelat. |
| `NPC_LEON` | **Mas Leon (Pedagang Pasar)** | Idle `2f`, Menimbang/Catat `2f` | `normal`, `senang`, `sibuk` | **Fase 1** | Pemuda pedagang pasar dengan celemek/kemeja pasar dan catatan barang. |
| `NPC_BAHRI` | **Pak Bahri (Nelayan)** | Idle `2f`, Jalan `4f` | `normal`, `senang` | **Fase 1** | Ikat kepala biru, celana pendek/sarung kerja, membawa jaring (di Fase 2). |
| `NPC_VILLAGERS` | **Warga Figuran (4–6 orang)** | Idle `2f` (untuk meramaikan Pasar & Festival) | Tidak wajib (opsional 1 potret generik) | **Fase 1** | Bapak berblangkon, Ibu berkebaya, dan 2 anak desa agar Pasar & Festival Panen terasa hidup. |

---

## 4. Aset C: Tileset Lingkungan & Bangunan

Seluruh *tile* dasar menggunakan modul **`16 x 16 px`**. Bangunan & objek besar boleh berukuran kelipatan 16 px (`48x64`, `80x80`, dsb.).

| ID Aset | Nama Tileset / Objek | Ukuran | Detail Bagian yang Harus Dibuat | Prioritas |
| :--- | :--- | :---: | :--- | :-: |
| `TIL_TERRAIN_MAIN` | Tileset Tanah & Alam | `16x16 px` grid | Rumput hijau 3 variasi, jalan tanah desa (autotile tepi rumput), tanah cangkul kering, tanah cangkul basah, tepi batu tebing, pasir pantai, lumut hutan. | **Fase 1** |
| `TIL_WATER` | Tileset Sungai & Laut | `16x16 px` (`3 frame`) | Air sungai jernih mengalir (`3 frame` animasi), tepian sungai, ombak pantai tropis (`3 frame`), jembatan kayu utuh & **jembatan rusak** (sebelum zona Pantai dibuka). | **Fase 1** |
| `TIL_FENCE_PATH` | Pagar, Jalan & Tanda | `16x16 px` | Pagar bambu & pagar kayu (autotile), papan nama kayu, gapura/gerbang penutup jalur terkunci (semak penghalang Hutan, gerbang rusak Sawit, longsor batu Tambang). | **Fase 1** |
| `BLD_JOGLO_EXT` | Rumah Joglo (Eksterior) | `96x80 px` (6x5 tile) | Atap limasan/joglo genteng terakota merah, dinding kayu jati, tangga teras, lampu teras menyala saat malam (`2 frame`). | **Fase 1** |
| `BLD_JOGLO_INT` | Interior Rumah Joglo | Tileset `16x16 px` | Lantai papan kayu hangat, dinding kayu jendela berjeruji, kasur anyaman/bantal, meja makan kayu, lemari dapur, karpet anyaman. | **Fase 1** |
| `BLD_PASAR_KIOS` | Kios Pasar & Balai Desa | `64x64 px` / `80x80 px` | Kios kayu dengan **tenda kain motif batik** (merah, biru, hijau, ungu), keranjang buah/kopi/pisang, Gapura Desa berukir genteng, Balai Desa + papan pengumuman Quest. | **Fase 1** |
| `PRP_FESTIVAL` | Dekorasi Festival Panen | Beragam (`16x16`–`64x64`) | Spanduk `"FESTIVAL PANEN DESA"`, panggung gazebo kecil, **Nasi Tumpeng Raksasa**, lampion warna-warni (`2 frame` nyala), umbul-umbul batik. | **Fase 1** |
| `TIL_TAMBANG` | Tileset Gua Tambang | `16x16 px` grid | Mulut gua eksterior, lantai batu gelap, dinding gua, tangga turun, batu biasa, urat bijih (Besi, Batubara, Emas), obor dinding menyala (`3 frame`). | **Fase 2** |
| `BLD_COOP` | Kandang Unggas | `64x48 px` & interior | Kandang kayu beratap rumbia, tempat makan unggas, sarang jerami telur. | **Fase 2** |

---

## 5. Aset D: Tanaman, Pohon & Tahap Pertumbuhan

| ID Aset | Nama Komoditas / Pohon | Ukuran per Stage | Jumlah Stage / Frame | Prioritas |
| :--- | :--- | :---: | :---: | :-: |
| `CRP_PADI` | **Padi Lokal** | `16x24 px` | 5 stage: Benih → Tunas hijau → Rumpun muda → Berbulir hijau → **Kuning emas siap panen** | **Fase 1** |
| `CRP_PISANG` | **Pohon Pisang Raja** | `32x40 px` | 5 stage: Tunas → Batang muda → Daun lebar → Tandan bunga/pisang hijau → **Tandan pisang kuning siap panen** | **Fase 1** |
| `CRP_KOPI` | **Semak Kopi Nusantara** | `16x24 px` | 5 stage: Bibit → Semak kecil → Semak rimbun → Berbuah ceri hijau → **Ceri kopi merah siap panen** | **Fase 1** |
| `CRP_KELAPA` | **Pohon Kelapa Hijau** | `32x48 px` | 5 stage: Tunas kelapa → Pohon pendek → Pohon tinggi tanpa buah → **Berbuah kelapa siap panen** | **Fase 1** |
| `CRP_SAWIT` | **Pohon Kelapa Sawit** | `32x48 px` | 5 stage: Bibit polibag → Pelepah muda → Batang kokoh → **Tandan buah merah-jingga siap panen** | **Fase 1** |
| `CRP_CABAI` | **Cabai & Rempah** | `16x24 px` | 4 stage: Benih → Tunas → Berbunga → **Buah cabai merah cerah** | **Fase 1** |
| `TRE_HUTAN` | **Pohon Hutan Tropis (Replanting)** | `32x48 px` | 4 stage: Bibit tanam ulang → Pohon muda → **Pohon rimbun dewasa** → **Tunggul bekas tebang** (+ animasi goyang `3 frame` saat ditebang) | **Fase 1** |
| `ENV_FORAGE` | Objek Liar & Gulma | `16x16 px` | Rumput liar, ranting jatuh, batu kecil, kerang pantai, jamur hutan | **Fase 1** |

---

## 6. Aset E: Ikon Item, Stasiun Produksi & VFX

### 6.1 Ikon Item Tas Pinggang & UI (`16 x 16 px` per ikon)
Disarankan disatukan dalam satu atlas `items_sheet.png` (`16x16 px` grid):
- **Alat (Tools):** Gembor (Watering Can), Cangkul (Hoe), Kapak (Axe), Sabit, dan *(Fase 2)* Pancingan Bambu, Beliung (Pickaxe).
- **Benih & Bibit (Seeds):** Kantong Benih Padi, Tunas Pisang, Bibit Kopi, Tunas Kelapa, Bibit Sawit, Benih Cabai, **Bibit Pohon Hutan (Replanting)**.
- **Hasil Panen & Alam:** Ikat Padi, Sisir Pisang, Biji Kopi, Kelapa Utuh & Belah, Tandan Sawit, Cabai/Bumbu, Kayu Hutan, Garam Laut.
- **Produk Olahan Joglo:** Bungkus **Keripik Pisang**, Karung **Beras Pulen**, **Kopi Sangrai**, Cangkir **Kopi Seduh**, Botol **Minyak Sawit**, Mangkuk **Santan Kelapa**, **Nasi Tumpeng Desa**.
- **Bahan Toko:** Minyak Goreng Dasar, Gula Jawa.
- **Fase 2:** Ikan Lele, Nila, Kakap, Udang, Ikan Bakar; Batu Kali, Batubara, Bijih Besi, Emas; Telur Ayam, Telur Bebek, Telur Asin, Pakan Dedak.

### 6.2 Stasiun Produksi, Objek Kebun & Partikel VFX
| ID Aset | Nama Objek / Efek | Ukuran | Frame / State | Prioritas |
| :--- | :--- | :---: | :--- | :-: |
| `OBJ_STATIONS` | Stasiun Joglo (Wajan, Lesung, Tungku Sangrai, Perasan, Dapur Besar) | `32x32 px` | Idle (`1f`), Aktif memasak/mengolah (`3f` asap/api), **Selesai** (ikon melayang siap ambil) | **Fase 1** |
| `OBJ_CHEST_BIN` | **Peti Panen (Shipping Bin)** & **Peti Kayu Bersama** | `32x24 px` | Tertutup (`1f`), Terbuka (`2f`) | **Fase 1** |
| `VFX_FARM` | Efek Aksi & Lingkungan | `16x16 px` | Percikan air siraman (`4f`), serpihan tanah cangkul (`3f`), daun jatuh saat tebang pohon (`4f`), kilau item matang (`3f`), ikon `Zzz` / mata kantuk (`3f`), ikon gelembung `!` & `♥` | **Fase 1** |
| `OBJ_ANIMAL` | Ayam Kampung & Bebek Lokal | `16x16 px` | Idle, Jalan, Makan (`2–3f` x 4 arah) | **Fase 2** |

---

## 7. Aset F: UI, HUD, Peta & Layar Menu

| ID Aset | Elemen Antarmuka | Ukuran | Detail & Referensi Visual | Prioritas |
| :--- | :--- | :---: | :--- | :-: |
| `UI_MAIN_BG` | Latar Main Menu | `480x270 px` | Pemandangan gunung berapi berasap tipis di senja hari, sawah terasering hijau, dan rumah Joglo dengan pohon pisang & kelapa; logo tulisan *"Nusantara Farm: Petualangan Desa"*. | **Fase 1** |
| `UI_WORLD_MAP` | **Peta Besar Desa Nusantara** | `400x210 px` | Ilustrasi peta top-down 6 zona (Kebun, Desa & Pasar, Hutan, Kebun Sawit, Pantai, Pegunungan & Tambang) dibingkai bambu, plus pin wajah Budi/Mitha (`16x16 px`). | **Fase 1** |
| `UI_FRAMES` | 9-Slice Frame & Tombol | `24x24`–`48x48 px` | Bingkai bambu tradisional (panel menu & dialog), papan kayu hangat (tombol menu, label koin/cuaca), slot kotak tas pinggang & highlight merah/emas slot aktif. | **Fase 1** |
| `UI_ICONS` | Ikon HUD & K3LH | `16x16 px` | Koin Emas, Bintang Level, Ikon Stamina (Daun/Petir), Hati Penuh & Kosong (`12x12`), Eco-Meter (Pohon hijau/kuning/merah), Ikon Mata Mengantuk, Tas Pinggang, Toko Pasar, Peta, Gerigi Pengaturan. | **Fase 1** |
| `UI_WEATHER` | Ikon Cuaca | `24x16 px` | Cerah (Matahari), Berawan, Hujan Ringan, Hujan Deras / Mendung. | **Fase 1** |
| `UI_TOUCH` | Kontrol Layar Sentuh Android | `48x48` & `28x28 px` | Ring dasar joystick bambu/transparan, knob joystick, tombol Aksi Alat, tombol Interaksi, ikon kontekstual (Tangan/Bicara/Cangkul). | **Fase 1** |
| `UI_FONT` | Font Pixel | `.ttf` / `.fnt` | Font pixel tajam (ukuran dasar `8px` / `16px`) yang terbaca jelas di `480x270`, mendukung angka dan tanda baca lengkap. | **Fase 1** |

---

## 8. Spesifikasi Audio: BGM, Ambience & SFX

Seluruh audio disiapkan oleh Sound Designer dalam format:
- **BGM & Ambience (Musik/Latar Panjang):** `.ogg` (*Vorbis*, diset *Loop = On* di Godot), **44.1 kHz Stereo**, dinormalisasi di kisaran `-14 LUFS` hingga `-16 LUFS` agar tidak menenggelamkan SFX.
- **Sound Effects (SFX Pendek):** `.wav` (16-bit PCM) atau `.ogg` pendek dengan *trim* hening di awal (`< 5 ms`) agar responsif saat tombol/alat ditekan.

### 8.1 Daftar BGM (Musik Latar Adaptif)

| ID Audio | Nama Track | Durasi / Loop | Nuansa & Instrumen Khas Indonesia | Pemicu Scene / Kondisi | Prioritas |
| :--- | :--- | :---: | :--- | :--- | :-: |
| `BGM_MENU` | *Pagi di Terasering* | 60–90 dtk (Loop) | Hangat, nostalgik; perpaduan gitar akustik, suling bambu, dan sentuhan chiptune lembut 16-bit. | Main Menu, Buat Karakter, Lobby LAN. | **Fase 1** |
| `BGM_FARM_DAY` | *Senandung Kebun Padi* | 90–120 dtk (Loop) | Ceria, santai, ritme sedang; angklung/marimba kayu + bass akustik ringan. | Rumah & Kebun (Pagi–Sore). | **Fase 1** |
| `BGM_VILLAGE_MARKET` | *Ramai Pasar Desa* | 90 dtk (Loop) | Hidup & ramah; kendang pelan, gambang/saron ringan, petikan dawai ceria. | Desa Utama & Area Pasar. | **Fase 1** |
| `BGM_FOREST` | *Rindang Hutan Tropis* | 90 dtk (Loop) | Tenang, misterius namun damai; seruling pelan, pad udara lembut, perkusi kayu jarang. | Hutan Tropis & Perkebunan Sawit. | **Fase 1** |
| `BGM_NIGHT` | *Malam Berkunang* | 60–90 dtk (Loop) | Minimalis, sangat menenangkan; petikan kecapi/siter pelan dan tempo lebih lambat (redup saat Debuff Mengantuk). | Seluruh zona pada Malam Hari (`19:00–05:59`) & Interior Joglo malam. | **Fase 1** |
| `BGM_BEACH` | *Angin Pesisir Nusantara* | 90 dtk (Loop) | Segar, berayun; akustik santai berpadu instrumen pukul lembut. | Zona Pantai & Laut. | **Fase 1** |
| `BGM_FESTIVAL` | *Syukur Panen Raya* | 60–90 dtk (Loop) | Meriah, penuh sukacita; gamelan pentatonik ritmis + kendang pesta desa. | Event Festival Panen Desa (Tumpeng). | **Fase 1** |
| `BGM_MINE` | *Gema Pegunungan* | 75 dtk (Loop) | Tenang & berfokus (bukan horor); gong lembut jarang & resonansi gua damai. | Zona Pegunungan & Tambang. | **Fase 2** |

### 8.2 Daftar Ambience (Lapisan Suara Alam)

| ID Audio | Nama File | Kondisi Pemutaran | Keterangan Suara | Prioritas |
| :--- | :--- | :--- | :--- | :-: |
| `AMB_MORNING` | `amb_morning_village.ogg` | Pagi (`06:00–10:00`) cerah | Kicau burung tropis & kokok ayam desa kejauhan. | **Fase 1** |
| `AMB_RIVER` | `amb_river_flow.ogg` | Dekat sungai di Kebun / Jembatan | Gemericik aliran air sungai (dipakai dengan volume berbasis jarak/2D). | **Fase 1** |
| `AMB_RAIN` | `amb_tropical_rain.ogg` | Saat cuaca **Hujan** | Suara rintik hujan tropis di dedaunan & atap genteng Joglo (meredam pelan saat masuk ruangan). | **Fase 1** |
| `AMB_NIGHT` | `amb_night_crickets.ogg` | Malam (`18:30–05:00`) | Suara jangkrik dan kodok sawah malam yang damai. | **Fase 1** |
| `AMB_OCEAN` | `amb_beach_waves.ogg` | Di zona Pantai & Laut | Deburan ombak tenang berirama. | **Fase 1** |

### 8.3 Daftar Sound Effects (SFX)

| ID Audio | Kategori | Nama / Kejadian | Deskripsi Suara & Catatan Teknis | Prioritas |
| :--- | :--- | :--- | :--- | :-: |
| `SFX_STEP_GRASS` | Gerak | Langkah di rumput/kebun | 3 variasi singkat suara injakan rumput lembut (diacak pitch `0.95–1.05`). | **Fase 1** |
| `SFX_STEP_WOOD` | Gerak | Langkah di lantai Joglo / Jembatan | 3 variasi ketukan kayu ringan. | **Fase 1** |
| `SFX_HOE` | Bertani | Mencangkul tanah | Hentakan logam-kayu ke tanah lembap (*thud* renyah). | **Fase 1** |
| `SFX_WATER` | Bertani | Menyiram dengan gembor | Percikan air segar berdurasi ~0.6 dtk. | **Fase 1** |
| `SFX_SEED` | Bertani | Menanam benih | Taburan halus / bunyi tanah ditepuk. | **Fase 1** |
| `SFX_HARVEST` | Bertani | Memanen tanaman | Suara *"pop"* renyah + petik daun yang memuaskan. | **Fase 1** |
| `SFX_AXE_HIT` | Hutan | Mengayun kapak ke pohon | 3 variasi pukulan kayu keras (*chop*). | **Fase 1** |
| `SFX_TREE_FALL` | Hutan | Pohon tumbang & Replanting | Derit kayu tumbang + gedebuk daun (tumbang); bunyi tanah subur lembut (replanting). | **Fase 1** |
| `SFX_CRAFT_START` | Produksi | Mulai masak/olah di Joglo | Desis minyak wajan / tumbukan lesung awal. | **Fase 1** |
| `SFX_CRAFT_DONE` | Produksi | Produk olahan selesai | Dering panci/lonceng dapur hangat menandakan barang siap diambil. | **Fase 1** |
| `SFX_COINS` | Ekonomi | Koin masuk / Klaim Konsinyasi | Denting koin emas ceria (`2–3` koin beruntun). | **Fase 1** |
| `SFX_CONSIGN_NOTIF` | Ekonomi | Notif dagangan Pasar laku | Nada singkat 2 not ramah seperti pesan masuk desa. | **Fase 1** |
| `SFX_DIALOG_BLIP` | Sosial | Ketik teks dialog (*typewriter*) | Blip retro lembut (pitch sedikit lebih rendah untuk Pak Tani/Kades, lebih tinggi untuk Nisrina). | **Fase 1** |
| `SFX_HEART_UP` | Sosial | Poin hati NPC naik / Hadiah disukai | Jingle 3 nada hangat. | **Fase 1** |
| `SFX_LVL_UP` | Progresi | World Level Naik / Keahlian Naik | Fanfare pendek kemenangan ala 16-bit Nusantara. | **Fase 1** |
| `SFX_UI_CLICK` | UI | Klik tombol kayu & buka/tutup Tas | Ketukan bambu/kayu ringan (`click`) & sret ritsleting kain tas pinggang. | **Fase 1** |
| `SFX_K3LH_BELL` | K3LH | Reminder Istirahat 60 Menit | Lonceng angklung lembut & tidak mengagetkan. | **Fase 1** |
| `SFX_ECO_WARN` | K3LH | Teguran Eco-Meter < 50 | Nada peringatan kayu rendah (*alert* tegas tapi tidak kasar). | **Fase 1** |
| `SFX_YAWN` | Status | Debuff Mengantuk aktif | Efek suara menguap singkat atau desiran pelan saat vignette kantuk muncul. | **Fase 1** |
| `SFX_DOOR` | Zona | Buka/tutup pintu Joglo | Derit pintu kayu ringan saat berpindah ke interior. | **Fase 1** |
| `SFX_FISH_CAST` | Fase 2 | Lempar kail, strike `!`, tarik ikan | Desir senar, cipratan air, dan bunyi *reel* pancing. | **Fase 2** |
| `SFX_PICKAXE` | Fase 2 | Memecah batu tambang | Denting logam beliung mengenai batu & pecahnya kerikil. | **Fase 2** |
| `SFX_POULTRY` | Fase 2 | Suara Ayam & Bebek | Kokok/kotek ayam kampung & kwek bebek peliharaan saat diberi makan. | **Fase 2** |
