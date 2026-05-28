class GroupPhotoModel {
  const GroupPhotoModel({
    required this.id,
    required this.groupId,
    required this.uploadedBy,
    required this.uploaderEmoji,
    required this.imageUrl,
    required this.storagePath,
    required this.createdAt,
  });

  factory GroupPhotoModel.fromJson(Map<String, dynamic> json) {
    return GroupPhotoModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      uploadedBy: json['uploaded_by']?.toString() ?? '',
      uploaderEmoji: json['uploader_emoji']?.toString() ?? '🙂',
      imageUrl: json['image_url']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  final String id;
  final String groupId;
  final String uploadedBy;
  final String uploaderEmoji;
  final String imageUrl;
  final String storagePath;
  final DateTime createdAt;

  GroupPhotoModel copyWith({
    String? id,
    String? groupId,
    String? uploadedBy,
    String? uploaderEmoji,
    String? imageUrl,
    String? storagePath,
    DateTime? createdAt,
  }) {
    return GroupPhotoModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploaderEmoji: uploaderEmoji ?? this.uploaderEmoji,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
