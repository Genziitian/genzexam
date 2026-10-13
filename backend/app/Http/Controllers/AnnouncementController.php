<?php

namespace App\Http\Controllers;

use App\Models\Announcement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnnouncementController extends Controller
{
    private const FIELDS = ['id', 'title', 'body', 'link_url', 'link_label', 'tone', 'is_active', 'starts_at', 'ends_at', 'sort_order', 'created_at', 'updated_at'];

    /** Public: what the dashboard slider shows. */
    public function live(): JsonResponse
    {
        $rows = Announcement::query()->live()
            ->orderBy('sort_order')->orderByDesc('id')->limit(10)
            ->get(['id', 'title', 'body', 'link_url', 'link_label', 'tone']);
        return response()->json(['announcements' => $rows]);
    }

    public function index(): JsonResponse
    {
        $rows = Announcement::query()->orderBy('sort_order')->orderByDesc('id')->get(self::FIELDS);
        return response()->json(['announcements' => $rows]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $data['created_by'] = $request->user()->id;
        $row = Announcement::create($data);
        return response()->json(['announcement' => $row->only(self::FIELDS)], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $row = Announcement::findOrFail($id);
        $row->update($this->validated($request, true));
        return response()->json(['announcement' => $row->fresh()->only(self::FIELDS)]);
    }

    public function destroy(int $id): JsonResponse
    {
        Announcement::findOrFail($id)->delete();
        return response()->json(['ok' => true]);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';
        $data = $request->validate([
            'title' => [$req, 'string', 'max:140'],
            'body' => ['nullable', 'string', 'max:400'],
            'link_url' => ['nullable', 'string', 'max:500', 'regex:#^(https://|/)#'],
            'link_label' => ['nullable', 'string', 'max:40'],
            'tone' => ['sometimes', 'string', 'in:brand,green,amber,dark'],
            'is_active' => ['sometimes', 'boolean'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
            'sort_order' => ['sometimes', 'integer', 'min:-1000', 'max:1000'],
        ]);
        return $data;
    }
}
