<div class="mt-4 flex flex-col items-stretch gap-y-3">
    <div class="flex items-center gap-x-3">
        <span class="h-px flex-1 bg-gray-200 dark:bg-white/10"></span>
        <span class="text-xs font-medium text-gray-500 dark:text-gray-400">veya</span>
        <span class="h-px flex-1 bg-gray-200 dark:bg-white/10"></span>
    </div>

    <x-filament::button tag="a" href="{{ route('auth.google.redirect') }}" color="gray" outlined class="w-full justify-center">
        Google ile devam et
    </x-filament::button>
</div>
