<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Job;
use App\Models\JobNote;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<JobNote>
 */
class JobNoteFactory extends Factory
{
    protected $model = JobNote::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'note' => fake()->sentence(),
        ];
    }
}
