<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

class GoogleController extends Controller
{
    /**
     * Redirect the user to the Google authentication page.
     */
    public function redirectToGoogle()
    {
        return Socialite::driver('google')->redirect();
    }

    /**
     * Obtain the user information from Google.
     */
    public function handleGoogleCallback()
    {
        try {
            $googleUser = Socialite::driver('google')->user();

            // Check if a user with this email already exists
            $user = User::where('email', $googleUser->getEmail())->first();

            if ($user) {
                // Link google_id if it's missing (user registered normally before)
                if (empty($user->google_id)) {
                    $user->update([
                        'google_id' => $googleUser->getId(),
                        'avatar' => $googleUser->getAvatar(),
                    ]);
                }
                
                Auth::login($user);
                return redirect()->intended('/dashboard');
            } else {
                // Create a new user
                $newUser = User::create([
                    'name' => $googleUser->getName(),
                    'email' => $googleUser->getEmail(),
                    'google_id' => $googleUser->getId(),
                    'avatar' => $googleUser->getAvatar(),
                    // Password can be left null as per our new DB schema
                ]);

                Auth::login($newUser);
                return redirect()->intended('/dashboard');
            }
        } catch (\Exception $e) {
            return redirect('/login')->withErrors(['oauth' => 'Terdapat kesalahan saat login dengan Google: ' . $e->getMessage()]);
        }
    }
}
