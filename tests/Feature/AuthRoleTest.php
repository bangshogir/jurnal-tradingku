<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthRoleTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_redirects_to_login_without_auth(): void
    {
        $response = $this->get(route('dashboard'));
        $response->assertRedirect('/login');
    }

    public function test_dashboard_redirects_to_login_at_root_without_auth(): void
    {
        $response = $this->get('/');
        $response->assertRedirect('/login');
    }

    public function test_user_cannot_access_admin_dashboard(): void
    {
        $user = User::factory()->create(['role' => 'user']);
        
        $response = $this->actingAs($user)->get(route('admin.dashboard'));
        $response->assertStatus(403);
    }

    public function test_user_can_access_user_dashboard(): void
    {
        $user = User::factory()->create(['role' => 'user']);
        
        $response = $this->actingAs($user)->get(route('dashboard'));
        $response->assertStatus(200);
        $response->assertViewIs('dashboard');
    }

    public function test_admin_can_access_admin_dashboard(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        
        $response = $this->actingAs($admin)->get(route('admin.dashboard'));
        $response->assertStatus(200);
        $response->assertViewIs('admin.dashboard');
    }
}

