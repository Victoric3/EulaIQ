class AudioCollection {
  final String id;
  final String title;
  final String? description;
  final String? userQuery;
  final List<Audio> audios;
  final DateTime createdAt;
  final AudioCreator? creator;
  final String type; // "added" or "generated"
  final String access; // "private" or "public"
  final List<String> textChunks;
  final int? playtime;
  final int playCount;
  final double rating;
  final int likeCount;
  final int commentCount;
  final String status; // "pending", "processing", "complete", "error"
  final double? progress;
  final String? processingStatus;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? error;
  final String? imageUrl;
  final String? associatedEbookId;

  AudioCollection({
    required this.id,
    required this.title,
    this.description,
    this.userQuery,
    this.audios = const [],
    required this.createdAt,
    this.creator,
    this.type = "generated",
    this.access = "public",
    this.textChunks = const [],
    this.playtime,
    this.playCount = 0,
    this.rating = 5.0,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.status,
    this.progress,
    this.processingStatus,
    this.startTime,
    this.endTime,
    this.error,
    this.imageUrl,
    this.associatedEbookId,
  });

  factory AudioCollection.fromJson(Map<String, dynamic> json) {
    List<Audio> audiosList = [];
    if (json['audios'] != null) {
      audiosList = (json['audios'] as List)
          .map((audio) => Audio.fromJson(audio))
          .toList();
    }

    return AudioCollection(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      userQuery: json['userQuery'],
      audios: audiosList,
      createdAt: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt']) 
              : DateTime.now()),
      creator: json['createdBy'] != null && json['createdBy'] is Map 
          ? AudioCreator.fromJson(json['createdBy']) 
          : (json['creator'] != null ? AudioCreator.fromJson(json['creator']) : null),
      type: json['type'] ?? 'generated',
      access: json['access'] ?? 'public',
      textChunks: json['textChunks'] != null 
          ? List<String>.from(json['textChunks']) 
          : [],
      playtime: json['playtime'],
      playCount: json['playCount'] ?? 0,
      rating: (json['rating'] ?? 5.0).toDouble(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      status: json['status'] ?? 'pending',
      progress: json['progress']?.toDouble(),
      processingStatus: json['processingStatus'],
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      error: json['error'],
      imageUrl: json['imageUrl'],
      associatedEbookId: json['associatedEbook'],
    );
  }

  // Helper method to map API status to UI status
  String get uiStatus {
    if (status == 'complete') return 'completed';
    if (status == 'processing') return 'generating';
    if (status == 'error') return 'failed';
    if (status == 'pending') return 'pending';
    return status;
  }
  
  // Helper to get main audio URL if available
  String? get mainAudioUrl {
    if (audios.isNotEmpty) {
      return audios.first.audioUrl;
    }
    return null;
  }
  
  // Helper to get total duration from all audio segments
  int get totalDuration {
    if (playtime != null && playtime! > 0) {
      return playtime!;
    }
    
    if (audios.isNotEmpty) {
      return audios.fold(0, (total, audio) => total + audio.audioDuration);
    }
    
    return 0;
  }
}

class Audio {
  final String? id;
  final String title;
  final String? text;
  final String audioUrl;
  final int audioDuration;
  final String? audioCollectionId;
  final DateTime createdAt;
  final int index;
  final String voice;
  final String type;
  final List<AudioSegment> segments;

  Audio({
    this.id,
    required this.title,
    this.text,
    required this.audioUrl,
    required this.audioDuration,
    this.audioCollectionId,
    required this.createdAt,
    required this.index,
    this.voice = 'default voice',
    this.type = 'head',
    this.segments = const [],
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    List<AudioSegment> segmentsList = [];
    if (json['segments'] != null) {
      segmentsList = (json['segments'] as List)
          .map((segment) => AudioSegment.fromJson(segment))
          .toList();
    }

    return Audio(
      id: json['_id'],
      title: json['title'] ?? 'Untitled Audio',
      text: json['text'],
      audioUrl: json['audioUrl'] ?? '',
      audioDuration: json['audioDuration'] ?? 0,
      audioCollectionId: json['audioCollection'],
      createdAt: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      index: json['index'] ?? 0,
      voice: json['voice'] ?? 'default voice',
      type: json['type'] ?? 'head',
      segments: segmentsList,
    );
  }
}

class AudioSegment {
  final String url;
  final String voice;
  final int duration;
  final String? text;

  AudioSegment({
    required this.url,
    required this.voice,
    required this.duration,
    this.text,
  });

  factory AudioSegment.fromJson(Map<String, dynamic> json) {
    return AudioSegment(
      url: json['url'] ?? '',
      voice: json['voice'] ?? 'default',
      duration: json['duration'] ?? 0,
      text: json['text'],
    );
  }
}

class AudioCreator {
  final String id;
  final String username;
  final String? photo;

  AudioCreator({
    required this.id,
    required this.username,
    this.photo,
  });

  factory AudioCreator.fromJson(Map<String, dynamic> json) {
    return AudioCreator(
      id: json['_id'] ?? '',
      username: json['username'] ?? 'Unknown User',
      photo: json['photo'],
    );
  }
}