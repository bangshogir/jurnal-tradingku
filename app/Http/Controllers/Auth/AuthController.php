<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class AuthController extends Controller
{
    // ─── Login ────────────────────────────────────────────────
    public function showLogin()
    {
        if (Auth::check()) {
            return Auth::user()->isAdmin() ? redirect()->route('admin.dashboard') : redirect()->route('dashboard');
        }
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        if (Auth::attempt($credentials, $request->boolean('remember'))) {
            $request->session()->regenerate();

            if (Auth::user()->isAdmin()) {
                return redirect()->intended(route('admin.dashboard'));
            }

            return redirect()->intended(route('dashboard'));
        }

        return back()->withErrors(['email' => 'Email atau password salah.'])->onlyInput('email');
    }

    // ─── Register ─────────────────────────────────────────────
    public function showRegister()
    {
        if (Auth::check()) {
            return Auth::user()->isAdmin() ? redirect()->route('admin.dashboard') : redirect()->route('dashboard');
        }
        return view('auth.register');
    }

    public function register(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users,email',
            'password' => ['required', 'confirmed', Password::min(8)],
        ]);

        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
            'role'     => 'user', // default: user (admin dibuat via seeder)
        ]);

        Auth::login($user);

        return redirect()->route('dashboard')->with('success', 'Akun berhasil dibuat. Selamat datang!');
    }

    // ─── Logout ───────────────────────────────────────────────
    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect()->route('login');
    }
}
