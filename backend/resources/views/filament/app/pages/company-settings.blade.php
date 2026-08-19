<x-filament-panels::page>
    <form wire:submit="save">
        {{ $this->form }}

        <x-filament::button type="submit" class="mt-6">
            Kaydet
        </x-filament::button>
    </form>
</x-filament-panels::page>
