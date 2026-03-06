Rencana Implementasi: Auth, Role, dan Admin Dashboard
Menambahkan sistem autentikasi (Register/Login/Logout), kontrol akses berbasis peran (Admin & User), dan desain ulang dashboard menjadi layout admin modern dengan sidebar, header, dan halaman konten yang bersih.

Proposed Changes
Auth System
[MODIFY] 
routes/web.php
Tambah grup route auth (login, register, logout).
Proteksi route dashboard menggunakan middleware auth dan role:admin.
[NEW] app/Http/Middleware/RoleMiddleware.php
Middleware baru untuk mengecek kolom role pada user yang sedang login.
Jika bukan admin, redirect ke halaman 403 Forbidden.
[MODIFY] 
database/migrations/0001_01_01_000000_create_users_table.php
Menambah kolom role (enum: admin, user, default: user) pada tabel users.
[NEW] Migration baru add_role_to_users_table
Alternatif: buat migration baru untuk menambah kolom role tanpa merubah migration awal (lebih aman untuk production).
[MODIFY] 
app/Models/User.php
Tambah role ke array $fillable.
Tambah helper method isAdmin() untuk kemudahan pengecekan role.
Views & Layout
[NEW] resources/views/layouts/admin.blade.php
Layout utama Admin Dashboard dengan:

Sidebar tetap (fixed) di kiri — berisi logo, menu navigasi.
Header di atas — berisi nama user, tombol logout, dan breadcrumb.
Konten area utama (@yield('content')).
Desain modern: dark sidebar, light content area, menggunakan Tailwind CSS CDN.

Menu sidebar yang akan direncanakan:

📊 Dashboard (Overview/Statistik)
📋 Trade History (Tabel log trading)
⚙️ Settings (placeholder untuk fitur berikutnya)
[MODIFY] 
resources/views/dashboard.blade.php
Ubah untuk menggunakan @extends('layouts.admin') dan @section('content').
Pisahkan konten statistik & tabel ke halaman yang lebih terstruktur.
[NEW] resources/views/auth/login.blade.php
Halaman login yang bersih dan modern (full page, centered form, dark theme).
[NEW] resources/views/auth/register.blade.php
Halaman registrasi.
Controllers
[NEW] app/Http/Controllers/Auth/AuthController.php
Method showLogin(), login(), showRegister(), register(), logout().
Implementasi validasi, autentikasi via Auth::attempt(), dan redirect.
[MODIFY] 
app/Http/Controllers/DashboardController.php
Tidak ada perubahan logika — hanya pastikan route sudah terlindungi middleware auth.
Seeder
[MODIFY] 
database/seeders/DatabaseSeeder.php
Tambah seeder untuk membuat satu akun Admin awal secara otomatis saat migrate:fresh --seed.
Verification Plan
Automated Tests
php artisan migrate:fresh --seed — memastikan tabel users + kolom role + admin seeder berjalan.
Tes akses /dashboard tanpa login → harus redirect ke /login.
Tes login dengan akun user biasa (role: user) → harus redirect ke halaman 403.
Tes login dengan akun admin → harus berhasil masuk ke dashboard.
Manual Verification
Cek tampilan visual sidebar, header, dan cards di browser.
Tes form register dan login end-to-end.
Tes tombol Logout.
Push ke GitHub → CI/CD auto-deploy → cek di jurnaltradingku.my.id.

