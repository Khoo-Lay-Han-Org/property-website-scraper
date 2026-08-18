<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;
use Rector\Php74\Rector\Closure\ClosureToArrowFunctionRector;

// Paths mirror phpstan.neon minus config/, which is all array literals
// Rector has nothing useful to say about.
return RectorConfig::configure()
    ->withPaths([
        __DIR__.'/app',
        __DIR__.'/bootstrap/app.php',
        __DIR__.'/database',
        __DIR__.'/routes',
        __DIR__.'/tests',
    ])
    ->withPreparedSets(
        deadCode: true,
        codeQuality: true,
    )
    ->withPhpSets()
    // Laravel's registration closures (routes, rate limiters, macros) read
    // better as multi-line closures than as wrapped arrow functions, and
    // Rector emits `fn()` where Pint's laravel preset wants `fn ()`.
    ->withSkip([
        ClosureToArrowFunctionRector::class,
    ]);
