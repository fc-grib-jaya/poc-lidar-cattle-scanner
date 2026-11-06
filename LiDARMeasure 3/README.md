# LiDAR Measure — PoC MVVM

Aplikasi iOS native SwiftUI + ARKit + RealityKit untuk mengukur jarak 3D antara dua titik yang dipilih pada benda diam. Mulai dengan kardus/kotak sepatu. Target iOS 17+, perangkat fisik dengan LiDAR. Tidak ada dependensi eksternal.

## Menjalankan

1. Buka `LiDARMeasure.xcodeproj` dengan Xcode yang menyediakan SDK iOS 17 atau lebih baru.
2. Pilih target LiDARMeasure → Signing & Capabilities. Pilih Development Team dan ubah Bundle Identifier menjadi unik.
3. Sambungkan iPhone/iPad ber-LiDAR, aktifkan Developer Mode bila diminta, lalu pilih sebagai run destination.
4. Run dan izinkan kamera. Simulator tidak menyediakan pengukuran LiDAR.
5. Letakkan kardus di tempat terang, lalu gerakkan perangkat perlahan sampai tracking siap.
6. Dari jarak sekitar 0,2–3 m, ketuk dua titik di permukaan kardus. Titik dan garis kuning berada di dunia AR; angka cm ditampilkan pada kartu di bawah layar.
7. Ulangi untuk sisi lain. Gunakan Batalkan terakhir atau Reset scan sesuai kebutuhan. Toggle mesh menampilkan rekonstruksi lingkungan dari ARKit.

Ketuk sedikit ke dalam permukaan dekat sudut, bukan di luar siluet: pixel depth dekat tepi dapat mengenai latar belakang. Angka menunjukkan jarak lurus antartitik, bukan panjang mengikuti lengkungan, bukan dimensi otomatis.

## Arsitektur

- Model — `Models/Measurement.swift`: titik awal/akhir dalam meter, jarak Euclidean, format cm.
- ViewModel — `ViewModels/MeasurementViewModel.swift`: pilihan titik, daftar hasil, undo/reset, status UI.
- View — `Views/MeasurementView.swift`: SwiftUI untuk kontrol dan hasil.
- AR adapter — `Views/ARMeasurementView.swift`: lifecycle ARSession, input sentuhan, dan rendering RealityKit. Coordinator menyimpan objek framework agar ViewModel tidak bergantung pada ARView.
- Service — `Services/DepthSampler.swift`: konversi layar ke pixel depth, filter confidence, unprojection memakai intrinsics kamera, dan transformasi ke koordinat dunia.

Alur: sentuhan → depth + confidence dari ARFrame yang sama → koordinat kamera → koordinat dunia → ViewModel → Model → garis AR dan hasil SwiftUI.

Pembacaan memakai sceneDepth aktual, confidence minimal medium, dan rentang depth 0,2–3 m sebagai filter PoC. Tidak ada fallback ke estimasi bidang saat depth tidak tersedia. Angka rentang tersebut adalah kebijakan aplikasi, bukan jaminan akurasi sensor. Mesh adalah rekonstruksi seluruh lingkungan; aplikasi belum melakukan segmentasi objek. Mesh dapat dibekukan, dipreview, dan diekspor ke OBJ.

## Validasi pada perangkat

1. Ukur tiga sisi kardus dengan penggaris dan catat sebagai referensi.
2. Pilih titik yang sama sebanyak 10 kali untuk setiap sisi pada beberapa jarak, misalnya 0,5 m, 1 m, dan 1,5 m.
3. Catat hasil, error absolut `abs(hasil - referensi)`, rata-rata error, dan variasinya. Presisi tampilan 0,1 cm bukan klaim akurasi 0,1 cm.
4. Uji portrait/landscape dan titik dekat tepi untuk memeriksa pemetaan sentuhan/depth.
5. Uji undo ketika satu titik dipilih, undo hasil lengkap, reset setelah beberapa hasil, penolakan izin kamera, interupsi aplikasi, serta perangkat tanpa LiDAR.
6. Aktifkan mesh lalu bergerak pelan mengelilingi kardus; periksa garis tetap menempel dan tidak bergeser nyata.

Benda harus diam. Permukaan reflektif/transparan, titik tertutup, gerakan, dan tracking buruk dapat menghasilkan depth tidak valid atau pengukuran meleset. Angka ini belum layak menjadi dasar keputusan peternakan sebelum validasi lapangan.

## Status pemeriksaan

- Syntax Swift: lolos `swiftc -frontend -parse` untuk semua file.
- Struktur project: lolos `plutil -lint`.
- Tes executable Swift untuk validasi mesh, penggabungan indeks, output OBJ berbasis indeks 1, skala meter, nama file unik, dan penolakan mesh tidak valid: lolos. Jalankan `sh Tests/run.sh` dari folder proyek di Mac. File tes tidak disertakan pada target aplikasi.
- Build/type-check SDK iOS dan uji hardware belum dilakukan: lingkungan pembuat hanya menyediakan Command Line Tools, tanpa Xcode lengkap. Parsing tidak memverifikasi kecocokan API SDK atau signing.

## Referensi

- [Apple: sceneDepth](https://developer.apple.com/documentation/arkit/arconfiguration/framesemantics-swift.struct/scenedepth)
- [Apple: Displaying a point cloud using scene depth](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- [Apple: sceneReconstruction](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstruction)


## Scan → preview → export OBJ (fitur baru)

1. Tunggu tracking siap, arahkan ke benda diam, lalu tekan **Mulai scan**.
2. Kelilingi benda perlahan dengan mesh aktif untuk melihat permukaan yang tertangkap. Lakukan scan singkat untuk membatasi lingkungan yang ikut terambil.
3. Tekan **Selesai scan**. Snapshot mesh dibekukan dan halaman **Hasil scan 3D** terbuka. Geser untuk memutar dan cubit untuk zoom; kamera AR tidak diperlukan untuk melihat snapshot tersebut.
4. Tekan **Export OBJ**, tunggu selesai, lalu **Bagikan OBJ** → Save to Files atau AirDrop.
5. File juga disimpan dalam Documents/Scans di sandbox aplikasi. Setiap ekspor menghasilkan nama unik. Simpan melalui Share sebelum menghapus aplikasi.
6. Di Blender gunakan File → Import → Wavefront (.obj). Koordinat OBJ menggunakan meter dan Y-up. Sesuaikan pengaturan axis import bila perlu; jangan menerapkan skala tambahan tanpa alasan.
7. Tutup preview untuk kembali mengukur. **Mulai scan** mengganti snapshot aktif; file OBJ yang sudah diekspor tetap tersimpan. **Reset scan** membersihkan koordinat sesi AR beserta hasil aktif; ekspor hasil yang ingin disimpan terlebih dahulu.

Semua mesh lingkungan yang masih aktif pada sesi saat scan dimulai dapat ikut masuk. Ini belum merupakan scan objek tersegmentasi. Untuk membersihkan geometri sesi sebelumnya, gunakan **Reset scan**, pindah ke area benda yang dituju, lalu mulai lagi. Tidak ada crop, penutupan lubang, penyatuan vertex/retopology, normals tersimpan, tekstur foto, atau ekspor USDZ pada versi ini. Segitiga dari anchor digabung menggunakan offset indeks dan posisi dunia; permukaan yang bertumpuk belum direkonsiliasi. Model mungkin terbuka di sisi yang tidak terjangkau sensor. File OBJ dapat digunakan setelah aplikasi ditutup, dan dapat dibuka kembali melalui **Buka OBJ dari Files** setelah disimpan lewat Share. Snapshot yang belum diekspor tidak dipulihkan pada peluncuran berikutnya.

PoC menyelesaikan scan otomatis saat jumlah segitiga melewati 300.000 (setelah satu pembaruan anchor). Ini batas pengumpulan praktis, bukan jaminan batas memori. Scan lingkungan besar dapat menghabiskan memori; gunakan benda kecil dan scan singkat.

### Pemisahan MVVM tambahan

- **Model — ScannedMesh:** snapshot nilai vertex/segitiga tanpa dependensi ARKit atau UI.
- **ViewModel — ScanViewModel:** state scan, jumlah segitiga, hasil beku, status preview, dan proses ekspor asynchronous.
- **Service — MeshCaptureService:** salin buffer ARKit segera pada callback main queue; ganti mesh berdasarkan ID anchor dan hapus anchor yang dihapus. Konversi vertex memakai offset, stride, dan transform anchor.
- **Service — OBJExportService:** tulis geometri ke OBJ secara atomik. Penulisan berjalan di task background.
- **View — ARMeasurementView:** adapter ARSession dan event anchor; ViewModel tidak memiliki ARView/ARSession.
- **View — ModelPreviewView:** viewer SceneKit dengan kamera putar/zoom serta ShareLink untuk file hasil ekspor.

### Pemeriksaan hardware tambahan

- Scan kardus, selesai, gerakkan kamera menjauh: preview harus tetap menampilkan snapshot yang sama.
- Ekspor dan import OBJ ke Blender; periksa model terlihat, skala benar, dan semua bagian berada pada posisi yang sesuai.
- Ulangi scan, reset sesi, izin kamera ditolak, interupsi aplikasi, serta perangkat tanpa LiDAR. Pastikan ekspor kosong ditolak dan hasil lama tidak tercampur setelah reset.
- Ukur panjang referensi di Blender dan bandingkan dengan penggaris; mesh merupakan estimasi dan bukan jaminan akurasi ukur.


## Pembaruan folder Xcode dan viewer (1 November 2026)

Struktur Project Navigator sekarang memakai PBXGroup dengan path folder fisik. Models, ViewModels, Services, Views, dan Tests dapat dibuka sebagai folder di Xcode; nama file tidak lagi berisi awalan folder. File dalam Tests tidak ikut target aplikasi.

Setelah unzip versi terbaru, buka `LiDARMeasure.xcodeproj` dari folder yang baru diekstrak. Jika proyek lama masih terbuka, tutup dahulu agar Xcode tidak menampilkan referensi dari salinan lama. Tidak perlu membuat ulang folder atau menyeret file secara manual.

```text
LiDARMeasure/
├── LiDARMeasure.xcodeproj/
├── LiDARMeasureApp.swift
├── Models/
├── ViewModels/
├── Services/
├── Views/
├── Tests/
└── README.md
```

Viewer menampilkan hasil scan sebagai geometri abu-abu dengan flat normals dan pencahayaan agar bentuk permukaannya terbaca. Pilih **Solid** untuk permukaan penuh, **Wireframe** untuk garis segitiga, atau **Reset kamera** untuk mengembalikan sudut pandang. Mengubah mode tampilan tidak mengubah file hasil ekspor atau skala model. Ini tetap bukan model bertekstur foto.

Untuk membuka hasil lama: Export OBJ → Bagikan OBJ → Save to Files → tutup viewer → **Buka OBJ dari Files** → pilih file yang disimpan. Aplikasi membaca geometri OBJ dari file tersebut di background, bukan hanya menggunakan snapshot sesi sebelumnya. Reader hanya mendukung subset OBJ yang ditulis aplikasi ini: vertex `v x y z` dan face segitiga `f a b c` berindeks positif, tanpa material, UV, atau normals eksternal. File OBJ lain dapat ditolak. Batas impor: ukuran file 100 MB, 1 juta vertex, dan 500 ribu segitiga. Semua koordinat ditafsirkan sebagai meter.

Pemisahan tambahan MVVM:

- `ModelPreviewViewModel`: state mode Solid/Wireframe dan perintah reset kamera.
- `OBJImportService`: parsing dan validasi file menjadi `ScannedMesh`, tanpa dependensi UI/ARKit.
- `ScanViewModel`: orkestrasi import asynchronous, status, snapshot model, dan presentasi viewer.
- `ModelPreviewView`: rendering SceneKit, pencahayaan, dan interaksi kamera.

Referensi yang diberikan pengguna:

- [SwiftUI Lidar Scanning and File Export w/ ARKit pt. 1 — Kelvin](https://www.youtube.com/watch?v=At6zjsxh9AY)
- [SwiftUI Displaying LiDAR-Scanned Models Using SceneKit pt. 2 — Kelvin](https://www.youtube.com/watch?v=6NP3sHAxMz8)

Alur dasar yang diikuti adalah scan geometri → OBJ → viewer SceneKit. Implementasi ini merupakan pengembangan kode PoC kita sendiri, bukan salinan kode tutorial atau klaim reproduksi tampilan identik. Struktur folder dan semua referensi source telah diperiksa secara programatis; pengujian visual aplikasi iOS masih memerlukan Xcode lengkap dan perangkat fisik.
