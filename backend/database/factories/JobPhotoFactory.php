<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Job;
use App\Models\JobPhoto;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<JobPhoto>
 */
class JobPhotoFactory extends Factory
{
    protected $model = JobPhoto::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'category' => 'DIGER',
            'file_path' => 'company/fake/jobs/fake/photos/'.fake()->uuid().'.jpg',
        ];
    }
}
