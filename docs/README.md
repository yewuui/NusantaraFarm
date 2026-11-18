# Dokumentasi Rancangan Game — Nusantara Farm: Petualangan Desa

> **Status:** Spesifikasi PRD & Arsitektur Teknis Final (Siap Produksi Aset, Audio, & Implementasi Godot 4)  
> **Engine Target:** Godot Engine 4.x (`GL Compatibility`)  
> **Platform Target:** Android (Mobile) & PC (Windows/Linux) — Cross-platform & Co-op LAN  
> **Resolusi Native Pixel Art:** `480 x 270 px` (16:9), Tile `16 x 16 px`, Karakter `16 x 32 px`

---

## 1. Peta Navigasi Dokumen

Suite dokumentasi ini berfungsi sebagai **Single Source of Truth** untuk membangun ulang *Nusantara Farm: Petualangan Desa* secara matang, terstruktur, dan modular.

| No | Dokumen | Fokus Utama | Target Pembaca |
| :-: | :--- | :--- | :--- |
| 0 | **[README.md](./README.md)** | Ringkasan visi, struktur dokumen, dan evaluasi transisi dari prototype awal | Seluruh Tim |
| 1 | **[01_PRD_Nusantara_Farm.md](./01_PRD_Nusantara_Farm.md)** | Product Requirements Document & Game Design Document lengkap (loop gameplay, musim, ekonomi konsinyasi, sosial/NPC, K3LH, peta zona, balancing, UI/UX, roadmap Fase 1 & 2) | Game Designer, Programmer, UI/UX, QA |
| 2 | **[02_Arsitektur_Godot_dan_Multiplayer_LAN.md](./02_Arsitektur_Godot_dan_Multiplayer_LAN.md)** | Blueprint teknis Godot 4, struktur folder, Autoloads, Custom Resources, arsitektur Co-op LAN/Hotspot ala Minecraft (`ENet` + UDP Discovery), dan skema Save/Load | Programmer Godot & Network |
| 3 | **[03_Spesifikasi_Asset_dan_Audio.md](./03_Spesifikasi_Asset_dan_Audio.md)** | Katalog lengkap kebutuhan aset pixel art (ukuran piksel, jumlah frame animasi, tileset, potret NPC, UI) serta daftar BGM, Ambience, dan SFX per kejadian | Pixel Artist, Sound Designer |

---

## 2. Latar Belakang & Konteks Tim

Game ini berangkat dari rancangan awal tugas DDPK 1 **Kelompok 2 (X RPL 1, SMKN 1 Bantul, 2026)** dengan anggota:
- Azka Chirza Saifani Chasan
- Kalis Lintang Pradipta
- Muhammad Aziz Nugroho

Tujuan utama proyek adalah menghadirkan game simulasi pertanian santai (*cozy farming sim*) ala *Stardew Valley* yang berpadu dengan manajemen produksi bertahap ala *Hay Day*, namun berakar kuat pada **kearifan lokal, komoditas tropis, arsitektur pedesaan, dan nilai K3LH Indonesia**.

---

## 3. Ringkasan Keputusan Desain Kunci

1. **Mode Pemain Fleksibel (Solo & Co-op LAN/Hotspot):**
   - Pemain dapat memilih avatar **Budi** atau **Mitha** saat mulai bermain.
   - Mendukung **1–4 pemain** melalui jaringan Wi-Fi atau Hotspot lokal (gaya *LAN World* di Minecraft: ada Host pemilik world + auto-discovery UDP / Direct IP).
   - **Data Milik World (Shared):** Kebun utama, bangunan, progresi unlock zona, **World Level**, Eco-Meter & Reputasi Desa.
   - **Data Milik Pribadi (Per Pemain):** Koin, Tas Pinggang (*inventory*), Stamina, Keahlian individual (`Cangkul`, `Siram`, `Panen`, `Produksi`, dll.), serta tingkat hati NPC.
2. **Waktu, Musim Tropis & Tidur Opsional:**
   - `1 hari in-game = 24 menit real-time` (`1 jam = 1 menit waktu nyata`).
   - **2 Musim Tropis:** Musim Kemarau (14 hari) dan Musim Penghujan (14 hari).
   - Tidur di Joglo **hanya bisa dilakukan pada malam hari** (`18:00–05:59`) dan bersifat opsional:
     - Semua pemain online tidur bersama = skip waktu ke `06:00` esok hari, tanaman bertumbuh, stok pasar segar, auto-save.
     - Tidur sendirian saat teman lain masih bermain = hanya memulihkan Stamina & menghapus debuff tanpa memaksa skip waktu.
     - Begadang melewati batas malam (`>= 00:00`) = terkena **debuff Mengantuk** (layar agak gelap, gerak melambat, stamina lebih boros).
3. **Ekonomi Khas Pasar Desa:**
   - Selain **Peti Panen** di kebun (cair saat ganti hari), pemain dapat menjual lewat **Sistem Titip Jual / Konsinyasi ke NPC Pasar** (barang diserahkan, koin diterima beberapa jam in-game kemudian dengan margin harga lebih tinggi).
4. **K3LH Terintegrasi ke Gameplay:**
   - **Kesehatan:** Pengingat istirahat aktif tiap 60 menit real-time (dapat dikonfigurasi di Pengaturan).
   - **Keselamatan:** 100% bebas kekerasan (*zero combat*, termasuk di area Tambang).
   - **Lingkungan:** **Eco-Meter** desa; penebangan tanpa replanting menurunkan Eco-Meter → memicu teguran Kepala Desa, boros Stamina, denda reboisasi, serta turunnya Reputasi Desa (pulih lewat menanam ulang pohon atau membantu Quest warga).
5. **Roadmap Terukur (2 Fase):**
   - **Fase 1 (Inti / v1.0):** Bertani 5 komoditas tropis utama + tanaman pendukung, Produksi olahan di Joglo, Hutan & Replanting, Konsinyasi Pasar & Peti Panen, NPC & Quest, Festival Panen Desa (Tumpeng), dan Multiplayer Co-op LAN.
   - **Fase 2 (Ekspansi / v1.1+):** Memancing di Sungai/Pantai, Tambang damai tanpa monster di Pegunungan, serta Beternak unggas (Ayam/Bebek penghasil Telur).

---

## 4. Evaluasi & Pembelajaran dari Prototype Awal (`D:\NusantaraFarm\Nusantara-Farm`)

Sebelum menyusun PRD ini, prototype Godot awal telah diaudit untuk memetakan hal yang perlu dipertahankan dan hal yang harus dirombak total:

| Komponen Prototype Lama | Kondisi di Prototype Awal | Arah Perbaikan di Versi Rebuild |
| :--- | :--- | :--- |
| **Kontrol & Input** | `MobileInput` + `joystick.gd` sudah bisa membaca mouse/sentuhan sekaligus berdampingan dengan input keyboard (`WASD`) | Dipertahankan dan disempurnakan menjadi sistem *Input Auto-Switch* (PC Keyboard/Mouse + Android Virtual Joystick & tombol aksi kontekstual). |
| **Karakter Budi & Mitha** | `character_body_2d.gd` (Budi) dan `wedok.gd` (Mitha) dikendalikan di 1 PC secara lokal dengan animasi 4 arah + diam | Dijadikan pilihan avatar pemain di Single-Player maupun Co-op LAN 1–4 pemain; skrip pemain disatukan ke satu scene `Player.tscn` yang dapat berganti *SpriteFrames* secara dinamis. |
| **Perpindahan Map** | Menggunakan `get_tree().change_scene_to_file()` penuh antara `map.tscn` dan `map 2.tscn` | Dirombak menjadi arsitektur `WorldManager` + `ZoneLoader` agar state kebun/mesin tidak hilang saat berpindah map dan mendukung pemain Co-op berada di zona yang berbeda secara bersamaan. |
| **Visual & Aset Sementara** | Campuran gambar resolusi tidak seragam dan fallback kode `hutan_draw.gd` | Distandarkan penuh ke viewport `480x270`, grid `16x16 px`, filter `Nearest`, dan `TileMapLayer` Godot 4 yang konsisten sesuai [03_Spesifikasi_Asset_dan_Audio.md](./03_Spesifikasi_Asset_dan_Audio.md). |
| **Arsitektur Data & Multiplayer** | Belum ada `DataManager`, `TimeManager`, sistem save, maupun jaringan | Dibangun di atas Autoload singletons terpisah, `Custom Resource`, `ENetMultiplayerPeer` otoritatif, dan sistem save JSON modular per world & per UUID pemain. |
