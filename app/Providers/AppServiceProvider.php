<?php

namespace App\Providers;

use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Behind Dokploy the container speaks HTTP; force https:// for asset()/Vite/@vite URLs.
        if ($this->shouldForceHttps()) {
            URL::forceScheme('https');
        }
    }

    private function shouldForceHttps(): bool
    {
        if (config('app.force_https')) {
            return true;
        }

        return str_starts_with((string) config('app.url'), 'https://');
    }
}
