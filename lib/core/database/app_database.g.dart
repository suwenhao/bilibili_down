// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTaskRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceInputMeta = const VerificationMeta(
    'sourceInput',
  );
  @override
  late final GeneratedColumn<String> sourceInput = GeneratedColumn<String>(
    'source_input',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bvidMeta = const VerificationMeta('bvid');
  @override
  late final GeneratedColumn<String> bvid = GeneratedColumn<String>(
    'bvid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cidMeta = const VerificationMeta('cid');
  @override
  late final GeneratedColumn<int> cid = GeneratedColumn<int>(
    'cid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epidMeta = const VerificationMeta('epid');
  @override
  late final GeneratedColumn<int> epid = GeneratedColumn<int>(
    'epid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publisherNameMeta = const VerificationMeta(
    'publisherName',
  );
  @override
  late final GeneratedColumn<String> publisherName = GeneratedColumn<String>(
    'publisher_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherIdMeta = const VerificationMeta(
    'publisherId',
  );
  @override
  late final GeneratedColumn<int> publisherId = GeneratedColumn<int>(
    'publisher_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionTitleMeta = const VerificationMeta(
    'collectionTitle',
  );
  @override
  late final GeneratedColumn<String> collectionTitle = GeneratedColumn<String>(
    'collection_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionLabelMeta = const VerificationMeta(
    'resolutionLabel',
  );
  @override
  late final GeneratedColumn<String> resolutionLabel = GeneratedColumn<String>(
    'resolution_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partIndexMeta = const VerificationMeta(
    'partIndex',
  );
  @override
  late final GeneratedColumn<int> partIndex = GeneratedColumn<int>(
    'part_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _qualityIdMeta = const VerificationMeta(
    'qualityId',
  );
  @override
  late final GeneratedColumn<int> qualityId = GeneratedColumn<int>(
    'quality_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityLabelMeta = const VerificationMeta(
    'qualityLabel',
  );
  @override
  late final GeneratedColumn<String> qualityLabel = GeneratedColumn<String>(
    'quality_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoCodecMeta = const VerificationMeta(
    'videoCodec',
  );
  @override
  late final GeneratedColumn<String> videoCodec = GeneratedColumn<String>(
    'video_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioCodecMeta = const VerificationMeta(
    'audioCodec',
  );
  @override
  late final GeneratedColumn<String> audioCodec = GeneratedColumn<String>(
    'audio_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioQualityIdMeta = const VerificationMeta(
    'audioQualityId',
  );
  @override
  late final GeneratedColumn<int> audioQualityId = GeneratedColumn<int>(
    'audio_quality_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedVideoSizeBytesMeta =
      const VerificationMeta('estimatedVideoSizeBytes');
  @override
  late final GeneratedColumn<int> estimatedVideoSizeBytes =
      GeneratedColumn<int>(
        'estimated_video_size_bytes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estimatedAudioSizeBytesMeta =
      const VerificationMeta('estimatedAudioSizeBytes');
  @override
  late final GeneratedColumn<int> estimatedAudioSizeBytes =
      GeneratedColumn<int>(
        'estimated_audio_size_bytes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dashOptionsJsonMeta = const VerificationMeta(
    'dashOptionsJson',
  );
  @override
  late final GeneratedColumn<String> dashOptionsJson = GeneratedColumn<String>(
    'dash_options_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraResourcesJsonMeta =
      const VerificationMeta('extraResourcesJson');
  @override
  late final GeneratedColumn<String> extraResourcesJson =
      GeneratedColumn<String>(
        'extra_resources_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _durationMillisecondsMeta =
      const VerificationMeta('durationMilliseconds');
  @override
  late final GeneratedColumn<int> durationMilliseconds = GeneratedColumn<int>(
    'duration_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temporaryDirectoryMeta =
      const VerificationMeta('temporaryDirectory');
  @override
  late final GeneratedColumn<String> temporaryDirectory =
      GeneratedColumn<String>(
        'temporary_directory',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PersistedDownloadBackend?, String>
  downloadBackend =
      GeneratedColumn<String>(
        'download_backend',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PersistedDownloadBackend?>(
        $DownloadTasksTable.$converterdownloadBackendn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskPhase, String> phase =
      GeneratedColumn<String>(
        'phase',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(DownloadTaskPhase.queued.name),
      ).withConverter<DownloadTaskPhase>($DownloadTasksTable.$converterphase);
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskPhase?, String>
  resumePhase =
      GeneratedColumn<String>(
        'resume_phase',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DownloadTaskPhase?>(
        $DownloadTasksTable.$converterresumePhasen,
      );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _downloadSpeedBytesPerSecondMeta =
      const VerificationMeta('downloadSpeedBytesPerSecond');
  @override
  late final GeneratedColumn<int> downloadSpeedBytesPerSecond =
      GeneratedColumn<int>(
        'download_speed_bytes_per_second',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    sourceInput,
    bvid,
    cid,
    epid,
    title,
    publisherName,
    publisherId,
    collectionTitle,
    contentType,
    description,
    resolutionLabel,
    publishedAt,
    coverUrl,
    partIndex,
    qualityId,
    qualityLabel,
    videoCodec,
    audioCodec,
    audioQualityId,
    estimatedVideoSizeBytes,
    estimatedAudioSizeBytes,
    dashOptionsJson,
    extraResourcesJson,
    durationMilliseconds,
    temporaryDirectory,
    outputPath,
    downloadBackend,
    phase,
    resumePhase,
    progress,
    downloadSpeedBytesPerSecond,
    retryCount,
    errorCode,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('source_input')) {
      context.handle(
        _sourceInputMeta,
        sourceInput.isAcceptableOrUnknown(
          data['source_input']!,
          _sourceInputMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceInputMeta);
    }
    if (data.containsKey('bvid')) {
      context.handle(
        _bvidMeta,
        bvid.isAcceptableOrUnknown(data['bvid']!, _bvidMeta),
      );
    }
    if (data.containsKey('cid')) {
      context.handle(
        _cidMeta,
        cid.isAcceptableOrUnknown(data['cid']!, _cidMeta),
      );
    }
    if (data.containsKey('epid')) {
      context.handle(
        _epidMeta,
        epid.isAcceptableOrUnknown(data['epid']!, _epidMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('publisher_name')) {
      context.handle(
        _publisherNameMeta,
        publisherName.isAcceptableOrUnknown(
          data['publisher_name']!,
          _publisherNameMeta,
        ),
      );
    }
    if (data.containsKey('publisher_id')) {
      context.handle(
        _publisherIdMeta,
        publisherId.isAcceptableOrUnknown(
          data['publisher_id']!,
          _publisherIdMeta,
        ),
      );
    }
    if (data.containsKey('collection_title')) {
      context.handle(
        _collectionTitleMeta,
        collectionTitle.isAcceptableOrUnknown(
          data['collection_title']!,
          _collectionTitleMeta,
        ),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('resolution_label')) {
      context.handle(
        _resolutionLabelMeta,
        resolutionLabel.isAcceptableOrUnknown(
          data['resolution_label']!,
          _resolutionLabelMeta,
        ),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('part_index')) {
      context.handle(
        _partIndexMeta,
        partIndex.isAcceptableOrUnknown(data['part_index']!, _partIndexMeta),
      );
    }
    if (data.containsKey('quality_id')) {
      context.handle(
        _qualityIdMeta,
        qualityId.isAcceptableOrUnknown(data['quality_id']!, _qualityIdMeta),
      );
    }
    if (data.containsKey('quality_label')) {
      context.handle(
        _qualityLabelMeta,
        qualityLabel.isAcceptableOrUnknown(
          data['quality_label']!,
          _qualityLabelMeta,
        ),
      );
    }
    if (data.containsKey('video_codec')) {
      context.handle(
        _videoCodecMeta,
        videoCodec.isAcceptableOrUnknown(data['video_codec']!, _videoCodecMeta),
      );
    }
    if (data.containsKey('audio_codec')) {
      context.handle(
        _audioCodecMeta,
        audioCodec.isAcceptableOrUnknown(data['audio_codec']!, _audioCodecMeta),
      );
    }
    if (data.containsKey('audio_quality_id')) {
      context.handle(
        _audioQualityIdMeta,
        audioQualityId.isAcceptableOrUnknown(
          data['audio_quality_id']!,
          _audioQualityIdMeta,
        ),
      );
    }
    if (data.containsKey('estimated_video_size_bytes')) {
      context.handle(
        _estimatedVideoSizeBytesMeta,
        estimatedVideoSizeBytes.isAcceptableOrUnknown(
          data['estimated_video_size_bytes']!,
          _estimatedVideoSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('estimated_audio_size_bytes')) {
      context.handle(
        _estimatedAudioSizeBytesMeta,
        estimatedAudioSizeBytes.isAcceptableOrUnknown(
          data['estimated_audio_size_bytes']!,
          _estimatedAudioSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('dash_options_json')) {
      context.handle(
        _dashOptionsJsonMeta,
        dashOptionsJson.isAcceptableOrUnknown(
          data['dash_options_json']!,
          _dashOptionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('extra_resources_json')) {
      context.handle(
        _extraResourcesJsonMeta,
        extraResourcesJson.isAcceptableOrUnknown(
          data['extra_resources_json']!,
          _extraResourcesJsonMeta,
        ),
      );
    }
    if (data.containsKey('duration_milliseconds')) {
      context.handle(
        _durationMillisecondsMeta,
        durationMilliseconds.isAcceptableOrUnknown(
          data['duration_milliseconds']!,
          _durationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('temporary_directory')) {
      context.handle(
        _temporaryDirectoryMeta,
        temporaryDirectory.isAcceptableOrUnknown(
          data['temporary_directory']!,
          _temporaryDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('download_speed_bytes_per_second')) {
      context.handle(
        _downloadSpeedBytesPerSecondMeta,
        downloadSpeedBytesPerSecond.isAcceptableOrUnknown(
          data['download_speed_bytes_per_second']!,
          _downloadSpeedBytesPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  DownloadTaskRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskRecord(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      sourceInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_input'],
      )!,
      bvid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bvid'],
      ),
      cid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cid'],
      ),
      epid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epid'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      publisherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher_name'],
      ),
      publisherId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}publisher_id'],
      ),
      collectionTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_title'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      resolutionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_label'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      partIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_index'],
      )!,
      qualityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality_id'],
      ),
      qualityLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_label'],
      ),
      videoCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_codec'],
      ),
      audioCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_codec'],
      ),
      audioQualityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_quality_id'],
      ),
      estimatedVideoSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_video_size_bytes'],
      ),
      estimatedAudioSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_audio_size_bytes'],
      ),
      dashOptionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dash_options_json'],
      ),
      extraResourcesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_resources_json'],
      )!,
      durationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_milliseconds'],
      ),
      temporaryDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporary_directory'],
      ),
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      downloadBackend: $DownloadTasksTable.$converterdownloadBackendn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}download_backend'],
        ),
      ),
      phase: $DownloadTasksTable.$converterphase.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}phase'],
        )!,
      ),
      resumePhase: $DownloadTasksTable.$converterresumePhasen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}resume_phase'],
        ),
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      downloadSpeedBytesPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_speed_bytes_per_second'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PersistedDownloadBackend, String, String>
  $converterdownloadBackend = const EnumNameConverter<PersistedDownloadBackend>(
    PersistedDownloadBackend.values,
  );
  static JsonTypeConverter2<PersistedDownloadBackend?, String?, String?>
  $converterdownloadBackendn = JsonTypeConverter2.asNullable(
    $converterdownloadBackend,
  );
  static JsonTypeConverter2<DownloadTaskPhase, String, String> $converterphase =
      const EnumNameConverter<DownloadTaskPhase>(DownloadTaskPhase.values);
  static JsonTypeConverter2<DownloadTaskPhase, String, String>
  $converterresumePhase = const EnumNameConverter<DownloadTaskPhase>(
    DownloadTaskPhase.values,
  );
  static JsonTypeConverter2<DownloadTaskPhase?, String?, String?>
  $converterresumePhasen = JsonTypeConverter2.asNullable($converterresumePhase);
}

class DownloadTaskRecord extends DataClass
    implements Insertable<DownloadTaskRecord> {
  /// 业务层生成且跨应用重启保持稳定的任务 ID。
  final String taskId;

  /// 用户粘贴的原始链接或 BV、AV、EP、SS 输入。
  final String sourceInput;

  /// 普通视频解析后的 BVID，番剧或解析前允许为空。
  final String? bvid;

  /// 选中分集对应的 CID，解析前允许为空。
  final int? cid;

  /// 番剧分集 EP ID，普通视频允许为空。
  final int? epid;

  /// 视频或分集标题。
  final String title;

  /// UP 主或内容发布者名称，接口未返回时允许为空。
  final String? publisherName;

  /// UP 主数字 ID，PGC 或旧任务允许为空。
  final int? publisherId;

  /// 合集、季度或视频主标题，用于后续本地重算命名规则。
  final String? collectionTitle;

  /// 解析时保存的普通投稿或 PGC 内容类型名称。
  final String? contentType;

  /// 视频或合集简介，接口未返回时允许为空。
  final String? description;

  /// 原始分辨率文本，例如 1920x1080。
  final String? resolutionLabel;

  /// 视频或分集发布时间，接口未返回时允许为空。
  final DateTime? publishedAt;

  /// 封面远程地址，接口未返回时允许为空。
  final String? coverUrl;

  /// 多 P 或合集中的显示顺序，从一开始计数。
  final int partIndex;

  /// 用户选择的 B 站清晰度代码。
  final int? qualityId;

  /// 清晰度显示名称，例如 1080P 高码率。
  final String? qualityLabel;

  /// 用户选择的视频编码名称，例如 AVC、HEVC 或 AV1。
  final String? videoCodec;

  /// 用户选择的音频编码或音质名称。
  final String? audioCodec;

  /// 用户实际选中的 B 站 DASH 音频质量代码。
  final int? audioQualityId;

  /// 解析时根据选中视频流码率和时长计算的预计字节数。
  final int? estimatedVideoSizeBytes;

  /// 解析时根据选中音频流码率和时长计算的预计字节数。
  final int? estimatedAudioSizeBytes;

  /// 解析时保存的不含临时 URL 的 DASH 候选流 JSON。
  final String? dashOptionsJson;

  /// 当前主任务勾选的封面、音频、弹幕和字幕 JSON 字符串数组。
  final String extraResourcesJson;

  /// 视频总时长毫秒数，用于计算 FFmpeg 合并进度。
  final int? durationMilliseconds;

  /// 下载和合并临时文件所在目录。
  final String? temporaryDirectory;

  /// 合并完成后交付给用户的最终文件路径。
  final String? outputPath;

  /// 当前任务使用的 aria2 或系统下载后端。
  final PersistedDownloadBackend? downloadBackend;

  /// 任务当前所处的业务阶段。
  final DownloadTaskPhase phase;

  /// 进入暂停前的阶段，恢复时用于返回正确流程位置。
  final DownloadTaskPhase? resumePhase;

  /// 任务总进度，取值范围为零到一。
  final double progress;

  /// 音视频分流当前网络速度之和，单位为字节每秒。
  final int downloadSpeedBytesPerSecond;

  /// 解析或下载失败后的累计重试次数。
  final int retryCount;

  /// 便于程序判断的稳定错误码。
  final String? errorCode;

  /// 面向日志和界面展示的错误说明。
  final String? errorMessage;

  /// 任务首次创建时间。
  final DateTime createdAt;

  /// 任务最近一次状态或进度更新时间。
  final DateTime updatedAt;

  /// 最终文件生成时间，未完成时为空。
  final DateTime? completedAt;
  const DownloadTaskRecord({
    required this.taskId,
    required this.sourceInput,
    this.bvid,
    this.cid,
    this.epid,
    required this.title,
    this.publisherName,
    this.publisherId,
    this.collectionTitle,
    this.contentType,
    this.description,
    this.resolutionLabel,
    this.publishedAt,
    this.coverUrl,
    required this.partIndex,
    this.qualityId,
    this.qualityLabel,
    this.videoCodec,
    this.audioCodec,
    this.audioQualityId,
    this.estimatedVideoSizeBytes,
    this.estimatedAudioSizeBytes,
    this.dashOptionsJson,
    required this.extraResourcesJson,
    this.durationMilliseconds,
    this.temporaryDirectory,
    this.outputPath,
    this.downloadBackend,
    required this.phase,
    this.resumePhase,
    required this.progress,
    required this.downloadSpeedBytesPerSecond,
    required this.retryCount,
    this.errorCode,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['source_input'] = Variable<String>(sourceInput);
    if (!nullToAbsent || bvid != null) {
      map['bvid'] = Variable<String>(bvid);
    }
    if (!nullToAbsent || cid != null) {
      map['cid'] = Variable<int>(cid);
    }
    if (!nullToAbsent || epid != null) {
      map['epid'] = Variable<int>(epid);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || publisherName != null) {
      map['publisher_name'] = Variable<String>(publisherName);
    }
    if (!nullToAbsent || publisherId != null) {
      map['publisher_id'] = Variable<int>(publisherId);
    }
    if (!nullToAbsent || collectionTitle != null) {
      map['collection_title'] = Variable<String>(collectionTitle);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || resolutionLabel != null) {
      map['resolution_label'] = Variable<String>(resolutionLabel);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['part_index'] = Variable<int>(partIndex);
    if (!nullToAbsent || qualityId != null) {
      map['quality_id'] = Variable<int>(qualityId);
    }
    if (!nullToAbsent || qualityLabel != null) {
      map['quality_label'] = Variable<String>(qualityLabel);
    }
    if (!nullToAbsent || videoCodec != null) {
      map['video_codec'] = Variable<String>(videoCodec);
    }
    if (!nullToAbsent || audioCodec != null) {
      map['audio_codec'] = Variable<String>(audioCodec);
    }
    if (!nullToAbsent || audioQualityId != null) {
      map['audio_quality_id'] = Variable<int>(audioQualityId);
    }
    if (!nullToAbsent || estimatedVideoSizeBytes != null) {
      map['estimated_video_size_bytes'] = Variable<int>(
        estimatedVideoSizeBytes,
      );
    }
    if (!nullToAbsent || estimatedAudioSizeBytes != null) {
      map['estimated_audio_size_bytes'] = Variable<int>(
        estimatedAudioSizeBytes,
      );
    }
    if (!nullToAbsent || dashOptionsJson != null) {
      map['dash_options_json'] = Variable<String>(dashOptionsJson);
    }
    map['extra_resources_json'] = Variable<String>(extraResourcesJson);
    if (!nullToAbsent || durationMilliseconds != null) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds);
    }
    if (!nullToAbsent || temporaryDirectory != null) {
      map['temporary_directory'] = Variable<String>(temporaryDirectory);
    }
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    if (!nullToAbsent || downloadBackend != null) {
      map['download_backend'] = Variable<String>(
        $DownloadTasksTable.$converterdownloadBackendn.toSql(downloadBackend),
      );
    }
    {
      map['phase'] = Variable<String>(
        $DownloadTasksTable.$converterphase.toSql(phase),
      );
    }
    if (!nullToAbsent || resumePhase != null) {
      map['resume_phase'] = Variable<String>(
        $DownloadTasksTable.$converterresumePhasen.toSql(resumePhase),
      );
    }
    map['progress'] = Variable<double>(progress);
    map['download_speed_bytes_per_second'] = Variable<int>(
      downloadSpeedBytesPerSecond,
    );
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      taskId: Value(taskId),
      sourceInput: Value(sourceInput),
      bvid: bvid == null && nullToAbsent ? const Value.absent() : Value(bvid),
      cid: cid == null && nullToAbsent ? const Value.absent() : Value(cid),
      epid: epid == null && nullToAbsent ? const Value.absent() : Value(epid),
      title: Value(title),
      publisherName: publisherName == null && nullToAbsent
          ? const Value.absent()
          : Value(publisherName),
      publisherId: publisherId == null && nullToAbsent
          ? const Value.absent()
          : Value(publisherId),
      collectionTitle: collectionTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionTitle),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      resolutionLabel: resolutionLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionLabel),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      partIndex: Value(partIndex),
      qualityId: qualityId == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityId),
      qualityLabel: qualityLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityLabel),
      videoCodec: videoCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCodec),
      audioCodec: audioCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(audioCodec),
      audioQualityId: audioQualityId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioQualityId),
      estimatedVideoSizeBytes: estimatedVideoSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedVideoSizeBytes),
      estimatedAudioSizeBytes: estimatedAudioSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedAudioSizeBytes),
      dashOptionsJson: dashOptionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(dashOptionsJson),
      extraResourcesJson: Value(extraResourcesJson),
      durationMilliseconds: durationMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMilliseconds),
      temporaryDirectory: temporaryDirectory == null && nullToAbsent
          ? const Value.absent()
          : Value(temporaryDirectory),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      downloadBackend: downloadBackend == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadBackend),
      phase: Value(phase),
      resumePhase: resumePhase == null && nullToAbsent
          ? const Value.absent()
          : Value(resumePhase),
      progress: Value(progress),
      downloadSpeedBytesPerSecond: Value(downloadSpeedBytesPerSecond),
      retryCount: Value(retryCount),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadTaskRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskRecord(
      taskId: serializer.fromJson<String>(json['taskId']),
      sourceInput: serializer.fromJson<String>(json['sourceInput']),
      bvid: serializer.fromJson<String?>(json['bvid']),
      cid: serializer.fromJson<int?>(json['cid']),
      epid: serializer.fromJson<int?>(json['epid']),
      title: serializer.fromJson<String>(json['title']),
      publisherName: serializer.fromJson<String?>(json['publisherName']),
      publisherId: serializer.fromJson<int?>(json['publisherId']),
      collectionTitle: serializer.fromJson<String?>(json['collectionTitle']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      description: serializer.fromJson<String?>(json['description']),
      resolutionLabel: serializer.fromJson<String?>(json['resolutionLabel']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      partIndex: serializer.fromJson<int>(json['partIndex']),
      qualityId: serializer.fromJson<int?>(json['qualityId']),
      qualityLabel: serializer.fromJson<String?>(json['qualityLabel']),
      videoCodec: serializer.fromJson<String?>(json['videoCodec']),
      audioCodec: serializer.fromJson<String?>(json['audioCodec']),
      audioQualityId: serializer.fromJson<int?>(json['audioQualityId']),
      estimatedVideoSizeBytes: serializer.fromJson<int?>(
        json['estimatedVideoSizeBytes'],
      ),
      estimatedAudioSizeBytes: serializer.fromJson<int?>(
        json['estimatedAudioSizeBytes'],
      ),
      dashOptionsJson: serializer.fromJson<String?>(json['dashOptionsJson']),
      extraResourcesJson: serializer.fromJson<String>(
        json['extraResourcesJson'],
      ),
      durationMilliseconds: serializer.fromJson<int?>(
        json['durationMilliseconds'],
      ),
      temporaryDirectory: serializer.fromJson<String?>(
        json['temporaryDirectory'],
      ),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      downloadBackend: $DownloadTasksTable.$converterdownloadBackendn.fromJson(
        serializer.fromJson<String?>(json['downloadBackend']),
      ),
      phase: $DownloadTasksTable.$converterphase.fromJson(
        serializer.fromJson<String>(json['phase']),
      ),
      resumePhase: $DownloadTasksTable.$converterresumePhasen.fromJson(
        serializer.fromJson<String?>(json['resumePhase']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      downloadSpeedBytesPerSecond: serializer.fromJson<int>(
        json['downloadSpeedBytesPerSecond'],
      ),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'sourceInput': serializer.toJson<String>(sourceInput),
      'bvid': serializer.toJson<String?>(bvid),
      'cid': serializer.toJson<int?>(cid),
      'epid': serializer.toJson<int?>(epid),
      'title': serializer.toJson<String>(title),
      'publisherName': serializer.toJson<String?>(publisherName),
      'publisherId': serializer.toJson<int?>(publisherId),
      'collectionTitle': serializer.toJson<String?>(collectionTitle),
      'contentType': serializer.toJson<String?>(contentType),
      'description': serializer.toJson<String?>(description),
      'resolutionLabel': serializer.toJson<String?>(resolutionLabel),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'partIndex': serializer.toJson<int>(partIndex),
      'qualityId': serializer.toJson<int?>(qualityId),
      'qualityLabel': serializer.toJson<String?>(qualityLabel),
      'videoCodec': serializer.toJson<String?>(videoCodec),
      'audioCodec': serializer.toJson<String?>(audioCodec),
      'audioQualityId': serializer.toJson<int?>(audioQualityId),
      'estimatedVideoSizeBytes': serializer.toJson<int?>(
        estimatedVideoSizeBytes,
      ),
      'estimatedAudioSizeBytes': serializer.toJson<int?>(
        estimatedAudioSizeBytes,
      ),
      'dashOptionsJson': serializer.toJson<String?>(dashOptionsJson),
      'extraResourcesJson': serializer.toJson<String>(extraResourcesJson),
      'durationMilliseconds': serializer.toJson<int?>(durationMilliseconds),
      'temporaryDirectory': serializer.toJson<String?>(temporaryDirectory),
      'outputPath': serializer.toJson<String?>(outputPath),
      'downloadBackend': serializer.toJson<String?>(
        $DownloadTasksTable.$converterdownloadBackendn.toJson(downloadBackend),
      ),
      'phase': serializer.toJson<String>(
        $DownloadTasksTable.$converterphase.toJson(phase),
      ),
      'resumePhase': serializer.toJson<String?>(
        $DownloadTasksTable.$converterresumePhasen.toJson(resumePhase),
      ),
      'progress': serializer.toJson<double>(progress),
      'downloadSpeedBytesPerSecond': serializer.toJson<int>(
        downloadSpeedBytesPerSecond,
      ),
      'retryCount': serializer.toJson<int>(retryCount),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadTaskRecord copyWith({
    String? taskId,
    String? sourceInput,
    Value<String?> bvid = const Value.absent(),
    Value<int?> cid = const Value.absent(),
    Value<int?> epid = const Value.absent(),
    String? title,
    Value<String?> publisherName = const Value.absent(),
    Value<int?> publisherId = const Value.absent(),
    Value<String?> collectionTitle = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> resolutionLabel = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    int? partIndex,
    Value<int?> qualityId = const Value.absent(),
    Value<String?> qualityLabel = const Value.absent(),
    Value<String?> videoCodec = const Value.absent(),
    Value<String?> audioCodec = const Value.absent(),
    Value<int?> audioQualityId = const Value.absent(),
    Value<int?> estimatedVideoSizeBytes = const Value.absent(),
    Value<int?> estimatedAudioSizeBytes = const Value.absent(),
    Value<String?> dashOptionsJson = const Value.absent(),
    String? extraResourcesJson,
    Value<int?> durationMilliseconds = const Value.absent(),
    Value<String?> temporaryDirectory = const Value.absent(),
    Value<String?> outputPath = const Value.absent(),
    Value<PersistedDownloadBackend?> downloadBackend = const Value.absent(),
    DownloadTaskPhase? phase,
    Value<DownloadTaskPhase?> resumePhase = const Value.absent(),
    double? progress,
    int? downloadSpeedBytesPerSecond,
    int? retryCount,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadTaskRecord(
    taskId: taskId ?? this.taskId,
    sourceInput: sourceInput ?? this.sourceInput,
    bvid: bvid.present ? bvid.value : this.bvid,
    cid: cid.present ? cid.value : this.cid,
    epid: epid.present ? epid.value : this.epid,
    title: title ?? this.title,
    publisherName: publisherName.present
        ? publisherName.value
        : this.publisherName,
    publisherId: publisherId.present ? publisherId.value : this.publisherId,
    collectionTitle: collectionTitle.present
        ? collectionTitle.value
        : this.collectionTitle,
    contentType: contentType.present ? contentType.value : this.contentType,
    description: description.present ? description.value : this.description,
    resolutionLabel: resolutionLabel.present
        ? resolutionLabel.value
        : this.resolutionLabel,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    partIndex: partIndex ?? this.partIndex,
    qualityId: qualityId.present ? qualityId.value : this.qualityId,
    qualityLabel: qualityLabel.present ? qualityLabel.value : this.qualityLabel,
    videoCodec: videoCodec.present ? videoCodec.value : this.videoCodec,
    audioCodec: audioCodec.present ? audioCodec.value : this.audioCodec,
    audioQualityId: audioQualityId.present
        ? audioQualityId.value
        : this.audioQualityId,
    estimatedVideoSizeBytes: estimatedVideoSizeBytes.present
        ? estimatedVideoSizeBytes.value
        : this.estimatedVideoSizeBytes,
    estimatedAudioSizeBytes: estimatedAudioSizeBytes.present
        ? estimatedAudioSizeBytes.value
        : this.estimatedAudioSizeBytes,
    dashOptionsJson: dashOptionsJson.present
        ? dashOptionsJson.value
        : this.dashOptionsJson,
    extraResourcesJson: extraResourcesJson ?? this.extraResourcesJson,
    durationMilliseconds: durationMilliseconds.present
        ? durationMilliseconds.value
        : this.durationMilliseconds,
    temporaryDirectory: temporaryDirectory.present
        ? temporaryDirectory.value
        : this.temporaryDirectory,
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    downloadBackend: downloadBackend.present
        ? downloadBackend.value
        : this.downloadBackend,
    phase: phase ?? this.phase,
    resumePhase: resumePhase.present ? resumePhase.value : this.resumePhase,
    progress: progress ?? this.progress,
    downloadSpeedBytesPerSecond:
        downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
    retryCount: retryCount ?? this.retryCount,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadTaskRecord copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTaskRecord(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      sourceInput: data.sourceInput.present
          ? data.sourceInput.value
          : this.sourceInput,
      bvid: data.bvid.present ? data.bvid.value : this.bvid,
      cid: data.cid.present ? data.cid.value : this.cid,
      epid: data.epid.present ? data.epid.value : this.epid,
      title: data.title.present ? data.title.value : this.title,
      publisherName: data.publisherName.present
          ? data.publisherName.value
          : this.publisherName,
      publisherId: data.publisherId.present
          ? data.publisherId.value
          : this.publisherId,
      collectionTitle: data.collectionTitle.present
          ? data.collectionTitle.value
          : this.collectionTitle,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      description: data.description.present
          ? data.description.value
          : this.description,
      resolutionLabel: data.resolutionLabel.present
          ? data.resolutionLabel.value
          : this.resolutionLabel,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      partIndex: data.partIndex.present ? data.partIndex.value : this.partIndex,
      qualityId: data.qualityId.present ? data.qualityId.value : this.qualityId,
      qualityLabel: data.qualityLabel.present
          ? data.qualityLabel.value
          : this.qualityLabel,
      videoCodec: data.videoCodec.present
          ? data.videoCodec.value
          : this.videoCodec,
      audioCodec: data.audioCodec.present
          ? data.audioCodec.value
          : this.audioCodec,
      audioQualityId: data.audioQualityId.present
          ? data.audioQualityId.value
          : this.audioQualityId,
      estimatedVideoSizeBytes: data.estimatedVideoSizeBytes.present
          ? data.estimatedVideoSizeBytes.value
          : this.estimatedVideoSizeBytes,
      estimatedAudioSizeBytes: data.estimatedAudioSizeBytes.present
          ? data.estimatedAudioSizeBytes.value
          : this.estimatedAudioSizeBytes,
      dashOptionsJson: data.dashOptionsJson.present
          ? data.dashOptionsJson.value
          : this.dashOptionsJson,
      extraResourcesJson: data.extraResourcesJson.present
          ? data.extraResourcesJson.value
          : this.extraResourcesJson,
      durationMilliseconds: data.durationMilliseconds.present
          ? data.durationMilliseconds.value
          : this.durationMilliseconds,
      temporaryDirectory: data.temporaryDirectory.present
          ? data.temporaryDirectory.value
          : this.temporaryDirectory,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      downloadBackend: data.downloadBackend.present
          ? data.downloadBackend.value
          : this.downloadBackend,
      phase: data.phase.present ? data.phase.value : this.phase,
      resumePhase: data.resumePhase.present
          ? data.resumePhase.value
          : this.resumePhase,
      progress: data.progress.present ? data.progress.value : this.progress,
      downloadSpeedBytesPerSecond: data.downloadSpeedBytesPerSecond.present
          ? data.downloadSpeedBytesPerSecond.value
          : this.downloadSpeedBytesPerSecond,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskRecord(')
          ..write('taskId: $taskId, ')
          ..write('sourceInput: $sourceInput, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('epid: $epid, ')
          ..write('title: $title, ')
          ..write('publisherName: $publisherName, ')
          ..write('publisherId: $publisherId, ')
          ..write('collectionTitle: $collectionTitle, ')
          ..write('contentType: $contentType, ')
          ..write('description: $description, ')
          ..write('resolutionLabel: $resolutionLabel, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('partIndex: $partIndex, ')
          ..write('qualityId: $qualityId, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('audioQualityId: $audioQualityId, ')
          ..write('estimatedVideoSizeBytes: $estimatedVideoSizeBytes, ')
          ..write('estimatedAudioSizeBytes: $estimatedAudioSizeBytes, ')
          ..write('dashOptionsJson: $dashOptionsJson, ')
          ..write('extraResourcesJson: $extraResourcesJson, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('temporaryDirectory: $temporaryDirectory, ')
          ..write('outputPath: $outputPath, ')
          ..write('downloadBackend: $downloadBackend, ')
          ..write('phase: $phase, ')
          ..write('resumePhase: $resumePhase, ')
          ..write('progress: $progress, ')
          ..write('downloadSpeedBytesPerSecond: $downloadSpeedBytesPerSecond, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    taskId,
    sourceInput,
    bvid,
    cid,
    epid,
    title,
    publisherName,
    publisherId,
    collectionTitle,
    contentType,
    description,
    resolutionLabel,
    publishedAt,
    coverUrl,
    partIndex,
    qualityId,
    qualityLabel,
    videoCodec,
    audioCodec,
    audioQualityId,
    estimatedVideoSizeBytes,
    estimatedAudioSizeBytes,
    dashOptionsJson,
    extraResourcesJson,
    durationMilliseconds,
    temporaryDirectory,
    outputPath,
    downloadBackend,
    phase,
    resumePhase,
    progress,
    downloadSpeedBytesPerSecond,
    retryCount,
    errorCode,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskRecord &&
          other.taskId == this.taskId &&
          other.sourceInput == this.sourceInput &&
          other.bvid == this.bvid &&
          other.cid == this.cid &&
          other.epid == this.epid &&
          other.title == this.title &&
          other.publisherName == this.publisherName &&
          other.publisherId == this.publisherId &&
          other.collectionTitle == this.collectionTitle &&
          other.contentType == this.contentType &&
          other.description == this.description &&
          other.resolutionLabel == this.resolutionLabel &&
          other.publishedAt == this.publishedAt &&
          other.coverUrl == this.coverUrl &&
          other.partIndex == this.partIndex &&
          other.qualityId == this.qualityId &&
          other.qualityLabel == this.qualityLabel &&
          other.videoCodec == this.videoCodec &&
          other.audioCodec == this.audioCodec &&
          other.audioQualityId == this.audioQualityId &&
          other.estimatedVideoSizeBytes == this.estimatedVideoSizeBytes &&
          other.estimatedAudioSizeBytes == this.estimatedAudioSizeBytes &&
          other.dashOptionsJson == this.dashOptionsJson &&
          other.extraResourcesJson == this.extraResourcesJson &&
          other.durationMilliseconds == this.durationMilliseconds &&
          other.temporaryDirectory == this.temporaryDirectory &&
          other.outputPath == this.outputPath &&
          other.downloadBackend == this.downloadBackend &&
          other.phase == this.phase &&
          other.resumePhase == this.resumePhase &&
          other.progress == this.progress &&
          other.downloadSpeedBytesPerSecond ==
              this.downloadSpeedBytesPerSecond &&
          other.retryCount == this.retryCount &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTaskRecord> {
  final Value<String> taskId;
  final Value<String> sourceInput;
  final Value<String?> bvid;
  final Value<int?> cid;
  final Value<int?> epid;
  final Value<String> title;
  final Value<String?> publisherName;
  final Value<int?> publisherId;
  final Value<String?> collectionTitle;
  final Value<String?> contentType;
  final Value<String?> description;
  final Value<String?> resolutionLabel;
  final Value<DateTime?> publishedAt;
  final Value<String?> coverUrl;
  final Value<int> partIndex;
  final Value<int?> qualityId;
  final Value<String?> qualityLabel;
  final Value<String?> videoCodec;
  final Value<String?> audioCodec;
  final Value<int?> audioQualityId;
  final Value<int?> estimatedVideoSizeBytes;
  final Value<int?> estimatedAudioSizeBytes;
  final Value<String?> dashOptionsJson;
  final Value<String> extraResourcesJson;
  final Value<int?> durationMilliseconds;
  final Value<String?> temporaryDirectory;
  final Value<String?> outputPath;
  final Value<PersistedDownloadBackend?> downloadBackend;
  final Value<DownloadTaskPhase> phase;
  final Value<DownloadTaskPhase?> resumePhase;
  final Value<double> progress;
  final Value<int> downloadSpeedBytesPerSecond;
  final Value<int> retryCount;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.taskId = const Value.absent(),
    this.sourceInput = const Value.absent(),
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.epid = const Value.absent(),
    this.title = const Value.absent(),
    this.publisherName = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.collectionTitle = const Value.absent(),
    this.contentType = const Value.absent(),
    this.description = const Value.absent(),
    this.resolutionLabel = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.partIndex = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.audioQualityId = const Value.absent(),
    this.estimatedVideoSizeBytes = const Value.absent(),
    this.estimatedAudioSizeBytes = const Value.absent(),
    this.dashOptionsJson = const Value.absent(),
    this.extraResourcesJson = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.temporaryDirectory = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.downloadBackend = const Value.absent(),
    this.phase = const Value.absent(),
    this.resumePhase = const Value.absent(),
    this.progress = const Value.absent(),
    this.downloadSpeedBytesPerSecond = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String taskId,
    required String sourceInput,
    this.bvid = const Value.absent(),
    this.cid = const Value.absent(),
    this.epid = const Value.absent(),
    required String title,
    this.publisherName = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.collectionTitle = const Value.absent(),
    this.contentType = const Value.absent(),
    this.description = const Value.absent(),
    this.resolutionLabel = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.partIndex = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.audioQualityId = const Value.absent(),
    this.estimatedVideoSizeBytes = const Value.absent(),
    this.estimatedAudioSizeBytes = const Value.absent(),
    this.dashOptionsJson = const Value.absent(),
    this.extraResourcesJson = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.temporaryDirectory = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.downloadBackend = const Value.absent(),
    this.phase = const Value.absent(),
    this.resumePhase = const Value.absent(),
    this.progress = const Value.absent(),
    this.downloadSpeedBytesPerSecond = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       sourceInput = Value(sourceInput),
       title = Value(title);
  static Insertable<DownloadTaskRecord> custom({
    Expression<String>? taskId,
    Expression<String>? sourceInput,
    Expression<String>? bvid,
    Expression<int>? cid,
    Expression<int>? epid,
    Expression<String>? title,
    Expression<String>? publisherName,
    Expression<int>? publisherId,
    Expression<String>? collectionTitle,
    Expression<String>? contentType,
    Expression<String>? description,
    Expression<String>? resolutionLabel,
    Expression<DateTime>? publishedAt,
    Expression<String>? coverUrl,
    Expression<int>? partIndex,
    Expression<int>? qualityId,
    Expression<String>? qualityLabel,
    Expression<String>? videoCodec,
    Expression<String>? audioCodec,
    Expression<int>? audioQualityId,
    Expression<int>? estimatedVideoSizeBytes,
    Expression<int>? estimatedAudioSizeBytes,
    Expression<String>? dashOptionsJson,
    Expression<String>? extraResourcesJson,
    Expression<int>? durationMilliseconds,
    Expression<String>? temporaryDirectory,
    Expression<String>? outputPath,
    Expression<String>? downloadBackend,
    Expression<String>? phase,
    Expression<String>? resumePhase,
    Expression<double>? progress,
    Expression<int>? downloadSpeedBytesPerSecond,
    Expression<int>? retryCount,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (sourceInput != null) 'source_input': sourceInput,
      if (bvid != null) 'bvid': bvid,
      if (cid != null) 'cid': cid,
      if (epid != null) 'epid': epid,
      if (title != null) 'title': title,
      if (publisherName != null) 'publisher_name': publisherName,
      if (publisherId != null) 'publisher_id': publisherId,
      if (collectionTitle != null) 'collection_title': collectionTitle,
      if (contentType != null) 'content_type': contentType,
      if (description != null) 'description': description,
      if (resolutionLabel != null) 'resolution_label': resolutionLabel,
      if (publishedAt != null) 'published_at': publishedAt,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (partIndex != null) 'part_index': partIndex,
      if (qualityId != null) 'quality_id': qualityId,
      if (qualityLabel != null) 'quality_label': qualityLabel,
      if (videoCodec != null) 'video_codec': videoCodec,
      if (audioCodec != null) 'audio_codec': audioCodec,
      if (audioQualityId != null) 'audio_quality_id': audioQualityId,
      if (estimatedVideoSizeBytes != null)
        'estimated_video_size_bytes': estimatedVideoSizeBytes,
      if (estimatedAudioSizeBytes != null)
        'estimated_audio_size_bytes': estimatedAudioSizeBytes,
      if (dashOptionsJson != null) 'dash_options_json': dashOptionsJson,
      if (extraResourcesJson != null)
        'extra_resources_json': extraResourcesJson,
      if (durationMilliseconds != null)
        'duration_milliseconds': durationMilliseconds,
      if (temporaryDirectory != null) 'temporary_directory': temporaryDirectory,
      if (outputPath != null) 'output_path': outputPath,
      if (downloadBackend != null) 'download_backend': downloadBackend,
      if (phase != null) 'phase': phase,
      if (resumePhase != null) 'resume_phase': resumePhase,
      if (progress != null) 'progress': progress,
      if (downloadSpeedBytesPerSecond != null)
        'download_speed_bytes_per_second': downloadSpeedBytesPerSecond,
      if (retryCount != null) 'retry_count': retryCount,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? taskId,
    Value<String>? sourceInput,
    Value<String?>? bvid,
    Value<int?>? cid,
    Value<int?>? epid,
    Value<String>? title,
    Value<String?>? publisherName,
    Value<int?>? publisherId,
    Value<String?>? collectionTitle,
    Value<String?>? contentType,
    Value<String?>? description,
    Value<String?>? resolutionLabel,
    Value<DateTime?>? publishedAt,
    Value<String?>? coverUrl,
    Value<int>? partIndex,
    Value<int?>? qualityId,
    Value<String?>? qualityLabel,
    Value<String?>? videoCodec,
    Value<String?>? audioCodec,
    Value<int?>? audioQualityId,
    Value<int?>? estimatedVideoSizeBytes,
    Value<int?>? estimatedAudioSizeBytes,
    Value<String?>? dashOptionsJson,
    Value<String>? extraResourcesJson,
    Value<int?>? durationMilliseconds,
    Value<String?>? temporaryDirectory,
    Value<String?>? outputPath,
    Value<PersistedDownloadBackend?>? downloadBackend,
    Value<DownloadTaskPhase>? phase,
    Value<DownloadTaskPhase?>? resumePhase,
    Value<double>? progress,
    Value<int>? downloadSpeedBytesPerSecond,
    Value<int>? retryCount,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      taskId: taskId ?? this.taskId,
      sourceInput: sourceInput ?? this.sourceInput,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      epid: epid ?? this.epid,
      title: title ?? this.title,
      publisherName: publisherName ?? this.publisherName,
      publisherId: publisherId ?? this.publisherId,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      contentType: contentType ?? this.contentType,
      description: description ?? this.description,
      resolutionLabel: resolutionLabel ?? this.resolutionLabel,
      publishedAt: publishedAt ?? this.publishedAt,
      coverUrl: coverUrl ?? this.coverUrl,
      partIndex: partIndex ?? this.partIndex,
      qualityId: qualityId ?? this.qualityId,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      audioQualityId: audioQualityId ?? this.audioQualityId,
      estimatedVideoSizeBytes:
          estimatedVideoSizeBytes ?? this.estimatedVideoSizeBytes,
      estimatedAudioSizeBytes:
          estimatedAudioSizeBytes ?? this.estimatedAudioSizeBytes,
      dashOptionsJson: dashOptionsJson ?? this.dashOptionsJson,
      extraResourcesJson: extraResourcesJson ?? this.extraResourcesJson,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      temporaryDirectory: temporaryDirectory ?? this.temporaryDirectory,
      outputPath: outputPath ?? this.outputPath,
      downloadBackend: downloadBackend ?? this.downloadBackend,
      phase: phase ?? this.phase,
      resumePhase: resumePhase ?? this.resumePhase,
      progress: progress ?? this.progress,
      downloadSpeedBytesPerSecond:
          downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
      retryCount: retryCount ?? this.retryCount,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (sourceInput.present) {
      map['source_input'] = Variable<String>(sourceInput.value);
    }
    if (bvid.present) {
      map['bvid'] = Variable<String>(bvid.value);
    }
    if (cid.present) {
      map['cid'] = Variable<int>(cid.value);
    }
    if (epid.present) {
      map['epid'] = Variable<int>(epid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (publisherName.present) {
      map['publisher_name'] = Variable<String>(publisherName.value);
    }
    if (publisherId.present) {
      map['publisher_id'] = Variable<int>(publisherId.value);
    }
    if (collectionTitle.present) {
      map['collection_title'] = Variable<String>(collectionTitle.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (resolutionLabel.present) {
      map['resolution_label'] = Variable<String>(resolutionLabel.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (partIndex.present) {
      map['part_index'] = Variable<int>(partIndex.value);
    }
    if (qualityId.present) {
      map['quality_id'] = Variable<int>(qualityId.value);
    }
    if (qualityLabel.present) {
      map['quality_label'] = Variable<String>(qualityLabel.value);
    }
    if (videoCodec.present) {
      map['video_codec'] = Variable<String>(videoCodec.value);
    }
    if (audioCodec.present) {
      map['audio_codec'] = Variable<String>(audioCodec.value);
    }
    if (audioQualityId.present) {
      map['audio_quality_id'] = Variable<int>(audioQualityId.value);
    }
    if (estimatedVideoSizeBytes.present) {
      map['estimated_video_size_bytes'] = Variable<int>(
        estimatedVideoSizeBytes.value,
      );
    }
    if (estimatedAudioSizeBytes.present) {
      map['estimated_audio_size_bytes'] = Variable<int>(
        estimatedAudioSizeBytes.value,
      );
    }
    if (dashOptionsJson.present) {
      map['dash_options_json'] = Variable<String>(dashOptionsJson.value);
    }
    if (extraResourcesJson.present) {
      map['extra_resources_json'] = Variable<String>(extraResourcesJson.value);
    }
    if (durationMilliseconds.present) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds.value);
    }
    if (temporaryDirectory.present) {
      map['temporary_directory'] = Variable<String>(temporaryDirectory.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (downloadBackend.present) {
      map['download_backend'] = Variable<String>(
        $DownloadTasksTable.$converterdownloadBackendn.toSql(
          downloadBackend.value,
        ),
      );
    }
    if (phase.present) {
      map['phase'] = Variable<String>(
        $DownloadTasksTable.$converterphase.toSql(phase.value),
      );
    }
    if (resumePhase.present) {
      map['resume_phase'] = Variable<String>(
        $DownloadTasksTable.$converterresumePhasen.toSql(resumePhase.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (downloadSpeedBytesPerSecond.present) {
      map['download_speed_bytes_per_second'] = Variable<int>(
        downloadSpeedBytesPerSecond.value,
      );
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('taskId: $taskId, ')
          ..write('sourceInput: $sourceInput, ')
          ..write('bvid: $bvid, ')
          ..write('cid: $cid, ')
          ..write('epid: $epid, ')
          ..write('title: $title, ')
          ..write('publisherName: $publisherName, ')
          ..write('publisherId: $publisherId, ')
          ..write('collectionTitle: $collectionTitle, ')
          ..write('contentType: $contentType, ')
          ..write('description: $description, ')
          ..write('resolutionLabel: $resolutionLabel, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('partIndex: $partIndex, ')
          ..write('qualityId: $qualityId, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('audioQualityId: $audioQualityId, ')
          ..write('estimatedVideoSizeBytes: $estimatedVideoSizeBytes, ')
          ..write('estimatedAudioSizeBytes: $estimatedAudioSizeBytes, ')
          ..write('dashOptionsJson: $dashOptionsJson, ')
          ..write('extraResourcesJson: $extraResourcesJson, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('temporaryDirectory: $temporaryDirectory, ')
          ..write('outputPath: $outputPath, ')
          ..write('downloadBackend: $downloadBackend, ')
          ..write('phase: $phase, ')
          ..write('resumePhase: $resumePhase, ')
          ..write('progress: $progress, ')
          ..write('downloadSpeedBytesPerSecond: $downloadSpeedBytesPerSecond, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadStreamsTable extends DownloadStreams
    with TableInfo<$DownloadStreamsTable, DownloadStreamRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadStreamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _streamIdMeta = const VerificationMeta(
    'streamId',
  );
  @override
  late final GeneratedColumn<String> streamId = GeneratedColumn<String>(
    'stream_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download_tasks (task_id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStreamKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadStreamKind>($DownloadStreamsTable.$converterkind);
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
    'codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temporaryPathMeta = const VerificationMeta(
    'temporaryPath',
  );
  @override
  late final GeneratedColumn<String> temporaryPath = GeneratedColumn<String>(
    'temporary_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineTaskIdMeta = const VerificationMeta(
    'engineTaskId',
  );
  @override
  late final GeneratedColumn<String> engineTaskId = GeneratedColumn<String>(
    'engine_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStreamPhase, String>
  phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(DownloadStreamPhase.pending.name),
  ).withConverter<DownloadStreamPhase>($DownloadStreamsTable.$converterphase);
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadSpeedBytesPerSecondMeta =
      const VerificationMeta('downloadSpeedBytesPerSecond');
  @override
  late final GeneratedColumn<int> downloadSpeedBytesPerSecond =
      GeneratedColumn<int>(
        'download_speed_bytes_per_second',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlRefreshedAtMeta = const VerificationMeta(
    'urlRefreshedAt',
  );
  @override
  late final GeneratedColumn<DateTime> urlRefreshedAt =
      GeneratedColumn<DateTime>(
        'url_refreshed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    streamId,
    taskId,
    kind,
    remoteUrl,
    codec,
    temporaryPath,
    engineTaskId,
    phase,
    downloadedBytes,
    totalBytes,
    downloadSpeedBytesPerSecond,
    errorCode,
    errorMessage,
    urlRefreshedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_streams';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadStreamRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('stream_id')) {
      context.handle(
        _streamIdMeta,
        streamId.isAcceptableOrUnknown(data['stream_id']!, _streamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_streamIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteUrlMeta);
    }
    if (data.containsKey('codec')) {
      context.handle(
        _codecMeta,
        codec.isAcceptableOrUnknown(data['codec']!, _codecMeta),
      );
    }
    if (data.containsKey('temporary_path')) {
      context.handle(
        _temporaryPathMeta,
        temporaryPath.isAcceptableOrUnknown(
          data['temporary_path']!,
          _temporaryPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temporaryPathMeta);
    }
    if (data.containsKey('engine_task_id')) {
      context.handle(
        _engineTaskIdMeta,
        engineTaskId.isAcceptableOrUnknown(
          data['engine_task_id']!,
          _engineTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('download_speed_bytes_per_second')) {
      context.handle(
        _downloadSpeedBytesPerSecondMeta,
        downloadSpeedBytesPerSecond.isAcceptableOrUnknown(
          data['download_speed_bytes_per_second']!,
          _downloadSpeedBytesPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('url_refreshed_at')) {
      context.handle(
        _urlRefreshedAtMeta,
        urlRefreshedAt.isAcceptableOrUnknown(
          data['url_refreshed_at']!,
          _urlRefreshedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {streamId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, kind},
  ];
  @override
  DownloadStreamRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadStreamRecord(
      streamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      kind: $DownloadStreamsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      )!,
      codec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec'],
      ),
      temporaryPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporary_path'],
      )!,
      engineTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_task_id'],
      ),
      phase: $DownloadStreamsTable.$converterphase.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}phase'],
        )!,
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadSpeedBytesPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_speed_bytes_per_second'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      urlRefreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}url_refreshed_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadStreamsTable createAlias(String alias) {
    return $DownloadStreamsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStreamKind, String, String> $converterkind =
      const EnumNameConverter<DownloadStreamKind>(DownloadStreamKind.values);
  static JsonTypeConverter2<DownloadStreamPhase, String, String>
  $converterphase = const EnumNameConverter<DownloadStreamPhase>(
    DownloadStreamPhase.values,
  );
}

class DownloadStreamRecord extends DataClass
    implements Insertable<DownloadStreamRecord> {
  /// 内部稳定分流 ID，建议使用“任务 ID + video/audio”。
  final String streamId;

  /// 所属业务任务 ID，删除主任务时级联清理。
  final String taskId;

  /// 当前记录是视频流还是音频流。
  final DownloadStreamKind kind;

  /// B 站返回的临时媒体地址，过期后由解析服务刷新。
  final String remoteUrl;

  /// 媒体编码或音质标识。
  final String? codec;

  /// 分流文件下载完成后的本地临时路径。
  final String temporaryPath;

  /// aria2 GID 或系统后台下载任务 ID。
  final String? engineTaskId;

  /// 分流在下载引擎中的当前状态。
  final DownloadStreamPhase phase;

  /// 已经写入临时文件的字节数。
  final int downloadedBytes;

  /// 服务端声明的总字节数，未知时为空。
  final int? totalBytes;

  /// 当前分流网络下载速度，单位为字节每秒，非下载阶段为零。
  final int downloadSpeedBytesPerSecond;

  /// 分流下载失败时用于程序判断的稳定错误码。
  final String? errorCode;

  /// 分流下载失败时的原始错误说明。
  final String? errorMessage;

  /// 媒体地址最近一次解析或刷新时间。
  final DateTime urlRefreshedAt;

  /// 分流状态或进度最近更新时间。
  final DateTime updatedAt;
  const DownloadStreamRecord({
    required this.streamId,
    required this.taskId,
    required this.kind,
    required this.remoteUrl,
    this.codec,
    required this.temporaryPath,
    this.engineTaskId,
    required this.phase,
    required this.downloadedBytes,
    this.totalBytes,
    required this.downloadSpeedBytesPerSecond,
    this.errorCode,
    this.errorMessage,
    required this.urlRefreshedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['stream_id'] = Variable<String>(streamId);
    map['task_id'] = Variable<String>(taskId);
    {
      map['kind'] = Variable<String>(
        $DownloadStreamsTable.$converterkind.toSql(kind),
      );
    }
    map['remote_url'] = Variable<String>(remoteUrl);
    if (!nullToAbsent || codec != null) {
      map['codec'] = Variable<String>(codec);
    }
    map['temporary_path'] = Variable<String>(temporaryPath);
    if (!nullToAbsent || engineTaskId != null) {
      map['engine_task_id'] = Variable<String>(engineTaskId);
    }
    {
      map['phase'] = Variable<String>(
        $DownloadStreamsTable.$converterphase.toSql(phase),
      );
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['download_speed_bytes_per_second'] = Variable<int>(
      downloadSpeedBytesPerSecond,
    );
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['url_refreshed_at'] = Variable<DateTime>(urlRefreshedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadStreamsCompanion toCompanion(bool nullToAbsent) {
    return DownloadStreamsCompanion(
      streamId: Value(streamId),
      taskId: Value(taskId),
      kind: Value(kind),
      remoteUrl: Value(remoteUrl),
      codec: codec == null && nullToAbsent
          ? const Value.absent()
          : Value(codec),
      temporaryPath: Value(temporaryPath),
      engineTaskId: engineTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(engineTaskId),
      phase: Value(phase),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadSpeedBytesPerSecond: Value(downloadSpeedBytesPerSecond),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      urlRefreshedAt: Value(urlRefreshedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadStreamRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadStreamRecord(
      streamId: serializer.fromJson<String>(json['streamId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      kind: $DownloadStreamsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      remoteUrl: serializer.fromJson<String>(json['remoteUrl']),
      codec: serializer.fromJson<String?>(json['codec']),
      temporaryPath: serializer.fromJson<String>(json['temporaryPath']),
      engineTaskId: serializer.fromJson<String?>(json['engineTaskId']),
      phase: $DownloadStreamsTable.$converterphase.fromJson(
        serializer.fromJson<String>(json['phase']),
      ),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadSpeedBytesPerSecond: serializer.fromJson<int>(
        json['downloadSpeedBytesPerSecond'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      urlRefreshedAt: serializer.fromJson<DateTime>(json['urlRefreshedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'streamId': serializer.toJson<String>(streamId),
      'taskId': serializer.toJson<String>(taskId),
      'kind': serializer.toJson<String>(
        $DownloadStreamsTable.$converterkind.toJson(kind),
      ),
      'remoteUrl': serializer.toJson<String>(remoteUrl),
      'codec': serializer.toJson<String?>(codec),
      'temporaryPath': serializer.toJson<String>(temporaryPath),
      'engineTaskId': serializer.toJson<String?>(engineTaskId),
      'phase': serializer.toJson<String>(
        $DownloadStreamsTable.$converterphase.toJson(phase),
      ),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadSpeedBytesPerSecond': serializer.toJson<int>(
        downloadSpeedBytesPerSecond,
      ),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'urlRefreshedAt': serializer.toJson<DateTime>(urlRefreshedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadStreamRecord copyWith({
    String? streamId,
    String? taskId,
    DownloadStreamKind? kind,
    String? remoteUrl,
    Value<String?> codec = const Value.absent(),
    String? temporaryPath,
    Value<String?> engineTaskId = const Value.absent(),
    DownloadStreamPhase? phase,
    int? downloadedBytes,
    Value<int?> totalBytes = const Value.absent(),
    int? downloadSpeedBytesPerSecond,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? urlRefreshedAt,
    DateTime? updatedAt,
  }) => DownloadStreamRecord(
    streamId: streamId ?? this.streamId,
    taskId: taskId ?? this.taskId,
    kind: kind ?? this.kind,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    codec: codec.present ? codec.value : this.codec,
    temporaryPath: temporaryPath ?? this.temporaryPath,
    engineTaskId: engineTaskId.present ? engineTaskId.value : this.engineTaskId,
    phase: phase ?? this.phase,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadSpeedBytesPerSecond:
        downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    urlRefreshedAt: urlRefreshedAt ?? this.urlRefreshedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadStreamRecord copyWithCompanion(DownloadStreamsCompanion data) {
    return DownloadStreamRecord(
      streamId: data.streamId.present ? data.streamId.value : this.streamId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      kind: data.kind.present ? data.kind.value : this.kind,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      codec: data.codec.present ? data.codec.value : this.codec,
      temporaryPath: data.temporaryPath.present
          ? data.temporaryPath.value
          : this.temporaryPath,
      engineTaskId: data.engineTaskId.present
          ? data.engineTaskId.value
          : this.engineTaskId,
      phase: data.phase.present ? data.phase.value : this.phase,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadSpeedBytesPerSecond: data.downloadSpeedBytesPerSecond.present
          ? data.downloadSpeedBytesPerSecond.value
          : this.downloadSpeedBytesPerSecond,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      urlRefreshedAt: data.urlRefreshedAt.present
          ? data.urlRefreshedAt.value
          : this.urlRefreshedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadStreamRecord(')
          ..write('streamId: $streamId, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('codec: $codec, ')
          ..write('temporaryPath: $temporaryPath, ')
          ..write('engineTaskId: $engineTaskId, ')
          ..write('phase: $phase, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadSpeedBytesPerSecond: $downloadSpeedBytesPerSecond, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('urlRefreshedAt: $urlRefreshedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    streamId,
    taskId,
    kind,
    remoteUrl,
    codec,
    temporaryPath,
    engineTaskId,
    phase,
    downloadedBytes,
    totalBytes,
    downloadSpeedBytesPerSecond,
    errorCode,
    errorMessage,
    urlRefreshedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadStreamRecord &&
          other.streamId == this.streamId &&
          other.taskId == this.taskId &&
          other.kind == this.kind &&
          other.remoteUrl == this.remoteUrl &&
          other.codec == this.codec &&
          other.temporaryPath == this.temporaryPath &&
          other.engineTaskId == this.engineTaskId &&
          other.phase == this.phase &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.downloadSpeedBytesPerSecond ==
              this.downloadSpeedBytesPerSecond &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.urlRefreshedAt == this.urlRefreshedAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadStreamsCompanion extends UpdateCompanion<DownloadStreamRecord> {
  final Value<String> streamId;
  final Value<String> taskId;
  final Value<DownloadStreamKind> kind;
  final Value<String> remoteUrl;
  final Value<String?> codec;
  final Value<String> temporaryPath;
  final Value<String?> engineTaskId;
  final Value<DownloadStreamPhase> phase;
  final Value<int> downloadedBytes;
  final Value<int?> totalBytes;
  final Value<int> downloadSpeedBytesPerSecond;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime> urlRefreshedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadStreamsCompanion({
    this.streamId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.kind = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.codec = const Value.absent(),
    this.temporaryPath = const Value.absent(),
    this.engineTaskId = const Value.absent(),
    this.phase = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadSpeedBytesPerSecond = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.urlRefreshedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadStreamsCompanion.insert({
    required String streamId,
    required String taskId,
    required DownloadStreamKind kind,
    required String remoteUrl,
    this.codec = const Value.absent(),
    required String temporaryPath,
    this.engineTaskId = const Value.absent(),
    this.phase = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadSpeedBytesPerSecond = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.urlRefreshedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : streamId = Value(streamId),
       taskId = Value(taskId),
       kind = Value(kind),
       remoteUrl = Value(remoteUrl),
       temporaryPath = Value(temporaryPath);
  static Insertable<DownloadStreamRecord> custom({
    Expression<String>? streamId,
    Expression<String>? taskId,
    Expression<String>? kind,
    Expression<String>? remoteUrl,
    Expression<String>? codec,
    Expression<String>? temporaryPath,
    Expression<String>? engineTaskId,
    Expression<String>? phase,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<int>? downloadSpeedBytesPerSecond,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? urlRefreshedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (streamId != null) 'stream_id': streamId,
      if (taskId != null) 'task_id': taskId,
      if (kind != null) 'kind': kind,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (codec != null) 'codec': codec,
      if (temporaryPath != null) 'temporary_path': temporaryPath,
      if (engineTaskId != null) 'engine_task_id': engineTaskId,
      if (phase != null) 'phase': phase,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadSpeedBytesPerSecond != null)
        'download_speed_bytes_per_second': downloadSpeedBytesPerSecond,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (urlRefreshedAt != null) 'url_refreshed_at': urlRefreshedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadStreamsCompanion copyWith({
    Value<String>? streamId,
    Value<String>? taskId,
    Value<DownloadStreamKind>? kind,
    Value<String>? remoteUrl,
    Value<String?>? codec,
    Value<String>? temporaryPath,
    Value<String?>? engineTaskId,
    Value<DownloadStreamPhase>? phase,
    Value<int>? downloadedBytes,
    Value<int?>? totalBytes,
    Value<int>? downloadSpeedBytesPerSecond,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime>? urlRefreshedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadStreamsCompanion(
      streamId: streamId ?? this.streamId,
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      codec: codec ?? this.codec,
      temporaryPath: temporaryPath ?? this.temporaryPath,
      engineTaskId: engineTaskId ?? this.engineTaskId,
      phase: phase ?? this.phase,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadSpeedBytesPerSecond:
          downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      urlRefreshedAt: urlRefreshedAt ?? this.urlRefreshedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (streamId.present) {
      map['stream_id'] = Variable<String>(streamId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DownloadStreamsTable.$converterkind.toSql(kind.value),
      );
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (temporaryPath.present) {
      map['temporary_path'] = Variable<String>(temporaryPath.value);
    }
    if (engineTaskId.present) {
      map['engine_task_id'] = Variable<String>(engineTaskId.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(
        $DownloadStreamsTable.$converterphase.toSql(phase.value),
      );
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadSpeedBytesPerSecond.present) {
      map['download_speed_bytes_per_second'] = Variable<int>(
        downloadSpeedBytesPerSecond.value,
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (urlRefreshedAt.present) {
      map['url_refreshed_at'] = Variable<DateTime>(urlRefreshedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadStreamsCompanion(')
          ..write('streamId: $streamId, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('codec: $codec, ')
          ..write('temporaryPath: $temporaryPath, ')
          ..write('engineTaskId: $engineTaskId, ')
          ..write('phase: $phase, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadSpeedBytesPerSecond: $downloadSpeedBytesPerSecond, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('urlRefreshedAt: $urlRefreshedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadArtifactsTable extends DownloadArtifacts
    with TableInfo<$DownloadArtifactsTable, DownloadArtifactRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download_tasks (task_id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadArtifactKind, String>
  kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DownloadArtifactKind>($DownloadArtifactsTable.$converterkind);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retainedMeta = const VerificationMeta(
    'retained',
  );
  @override
  late final GeneratedColumn<bool> retained = GeneratedColumn<bool>(
    'retained',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retained" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    kind,
    path,
    sizeBytes,
    checksum,
    retained,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_artifacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadArtifactRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('retained')) {
      context.handle(
        _retainedMeta,
        retained.isAcceptableOrUnknown(data['retained']!, _retainedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, kind, path},
  ];
  @override
  DownloadArtifactRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadArtifactRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      kind: $DownloadArtifactsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      retained: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retained'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadArtifactsTable createAlias(String alias) {
    return $DownloadArtifactsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadArtifactKind, String, String>
  $converterkind = const EnumNameConverter<DownloadArtifactKind>(
    DownloadArtifactKind.values,
  );
}

class DownloadArtifactRecord extends DataClass
    implements Insertable<DownloadArtifactRecord> {
  /// 数据库自增产物 ID。
  final int id;

  /// 所属业务任务 ID，删除主任务时级联清理记录。
  final String taskId;

  /// 文件属于最终视频、临时流、封面、字幕或弹幕。
  final DownloadArtifactKind kind;

  /// 文件绝对路径。
  final String path;

  /// 文件大小，尚未生成或无法读取时为空。
  final int? sizeBytes;

  /// 可选文件摘要，用于完整性校验和重复文件判断。
  final String? checksum;

  /// 任务完成后是否仍应保留该文件。
  final bool retained;

  /// 产物记录创建时间。
  final DateTime createdAt;
  const DownloadArtifactRecord({
    required this.id,
    required this.taskId,
    required this.kind,
    required this.path,
    this.sizeBytes,
    this.checksum,
    required this.retained,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<String>(taskId);
    {
      map['kind'] = Variable<String>(
        $DownloadArtifactsTable.$converterkind.toSql(kind),
      );
    }
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    map['retained'] = Variable<bool>(retained);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadArtifactsCompanion toCompanion(bool nullToAbsent) {
    return DownloadArtifactsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      kind: Value(kind),
      path: Value(path),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      retained: Value(retained),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadArtifactRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadArtifactRecord(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      kind: $DownloadArtifactsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      path: serializer.fromJson<String>(json['path']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      retained: serializer.fromJson<bool>(json['retained']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<String>(taskId),
      'kind': serializer.toJson<String>(
        $DownloadArtifactsTable.$converterkind.toJson(kind),
      ),
      'path': serializer.toJson<String>(path),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'checksum': serializer.toJson<String?>(checksum),
      'retained': serializer.toJson<bool>(retained),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DownloadArtifactRecord copyWith({
    int? id,
    String? taskId,
    DownloadArtifactKind? kind,
    String? path,
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> checksum = const Value.absent(),
    bool? retained,
    DateTime? createdAt,
  }) => DownloadArtifactRecord(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    checksum: checksum.present ? checksum.value : this.checksum,
    retained: retained ?? this.retained,
    createdAt: createdAt ?? this.createdAt,
  );
  DownloadArtifactRecord copyWithCompanion(DownloadArtifactsCompanion data) {
    return DownloadArtifactRecord(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      retained: data.retained.present ? data.retained.value : this.retained,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadArtifactRecord(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('checksum: $checksum, ')
          ..write('retained: $retained, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    kind,
    path,
    sizeBytes,
    checksum,
    retained,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadArtifactRecord &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.sizeBytes == this.sizeBytes &&
          other.checksum == this.checksum &&
          other.retained == this.retained &&
          other.createdAt == this.createdAt);
}

class DownloadArtifactsCompanion
    extends UpdateCompanion<DownloadArtifactRecord> {
  final Value<int> id;
  final Value<String> taskId;
  final Value<DownloadArtifactKind> kind;
  final Value<String> path;
  final Value<int?> sizeBytes;
  final Value<String?> checksum;
  final Value<bool> retained;
  final Value<DateTime> createdAt;
  const DownloadArtifactsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.retained = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DownloadArtifactsCompanion.insert({
    this.id = const Value.absent(),
    required String taskId,
    required DownloadArtifactKind kind,
    required String path,
    this.sizeBytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.retained = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : taskId = Value(taskId),
       kind = Value(kind),
       path = Value(path);
  static Insertable<DownloadArtifactRecord> custom({
    Expression<int>? id,
    Expression<String>? taskId,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<int>? sizeBytes,
    Expression<String>? checksum,
    Expression<bool>? retained,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (checksum != null) 'checksum': checksum,
      if (retained != null) 'retained': retained,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DownloadArtifactsCompanion copyWith({
    Value<int>? id,
    Value<String>? taskId,
    Value<DownloadArtifactKind>? kind,
    Value<String>? path,
    Value<int?>? sizeBytes,
    Value<String?>? checksum,
    Value<bool>? retained,
    Value<DateTime>? createdAt,
  }) {
    return DownloadArtifactsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      checksum: checksum ?? this.checksum,
      retained: retained ?? this.retained,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DownloadArtifactsTable.$converterkind.toSql(kind.value),
      );
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (retained.present) {
      map['retained'] = Variable<bool>(retained.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadArtifactsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('checksum: $checksum, ')
          ..write('retained: $retained, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ParseHistoriesTable extends ParseHistories
    with TableInfo<$ParseHistoriesTable, ParseHistoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParseHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _historyKeyMeta = const VerificationMeta(
    'historyKey',
  );
  @override
  late final GeneratedColumn<String> historyKey = GeneratedColumn<String>(
    'history_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceInputMeta = const VerificationMeta(
    'sourceInput',
  );
  @override
  late final GeneratedColumn<String> sourceInput = GeneratedColumn<String>(
    'source_input',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  @override
  late final GeneratedColumn<String> targetKind = GeneratedColumn<String>(
    'target_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalIdMeta = const VerificationMeta(
    'canonicalId',
  );
  @override
  late final GeneratedColumn<String> canonicalId = GeneratedColumn<String>(
    'canonical_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTitleMeta = const VerificationMeta(
    'mediaTitle',
  );
  @override
  late final GeneratedColumn<String> mediaTitle = GeneratedColumn<String>(
    'media_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherNameMeta = const VerificationMeta(
    'publisherName',
  );
  @override
  late final GeneratedColumn<String> publisherName = GeneratedColumn<String>(
    'publisher_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeCountMeta = const VerificationMeta(
    'episodeCount',
  );
  @override
  late final GeneratedColumn<int> episodeCount = GeneratedColumn<int>(
    'episode_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mediaJsonMeta = const VerificationMeta(
    'mediaJson',
  );
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
    'media_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedIndexesJsonMeta =
      const VerificationMeta('selectedIndexesJson');
  @override
  late final GeneratedColumn<String> selectedIndexesJson =
      GeneratedColumn<String>(
        'selected_indexes_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    historyKey,
    sourceInput,
    targetKind,
    canonicalId,
    mediaTitle,
    coverUrl,
    publisherName,
    episodeCount,
    mediaJson,
    selectedIndexesJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parse_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParseHistoryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('history_key')) {
      context.handle(
        _historyKeyMeta,
        historyKey.isAcceptableOrUnknown(data['history_key']!, _historyKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_historyKeyMeta);
    }
    if (data.containsKey('source_input')) {
      context.handle(
        _sourceInputMeta,
        sourceInput.isAcceptableOrUnknown(
          data['source_input']!,
          _sourceInputMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceInputMeta);
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKindMeta);
    }
    if (data.containsKey('canonical_id')) {
      context.handle(
        _canonicalIdMeta,
        canonicalId.isAcceptableOrUnknown(
          data['canonical_id']!,
          _canonicalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalIdMeta);
    }
    if (data.containsKey('media_title')) {
      context.handle(
        _mediaTitleMeta,
        mediaTitle.isAcceptableOrUnknown(data['media_title']!, _mediaTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTitleMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('publisher_name')) {
      context.handle(
        _publisherNameMeta,
        publisherName.isAcceptableOrUnknown(
          data['publisher_name']!,
          _publisherNameMeta,
        ),
      );
    }
    if (data.containsKey('episode_count')) {
      context.handle(
        _episodeCountMeta,
        episodeCount.isAcceptableOrUnknown(
          data['episode_count']!,
          _episodeCountMeta,
        ),
      );
    }
    if (data.containsKey('media_json')) {
      context.handle(
        _mediaJsonMeta,
        mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaJsonMeta);
    }
    if (data.containsKey('selected_indexes_json')) {
      context.handle(
        _selectedIndexesJsonMeta,
        selectedIndexesJson.isAcceptableOrUnknown(
          data['selected_indexes_json']!,
          _selectedIndexesJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {historyKey};
  @override
  ParseHistoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParseHistoryRecord(
      historyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history_key'],
      )!,
      sourceInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_input'],
      )!,
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_kind'],
      )!,
      canonicalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_id'],
      )!,
      mediaTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_title'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      publisherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher_name'],
      ),
      episodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_count'],
      )!,
      mediaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_json'],
      )!,
      selectedIndexesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_indexes_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ParseHistoriesTable createAlias(String alias) {
    return $ParseHistoriesTable(attachedDatabase, alias);
  }
}

class ParseHistoryRecord extends DataClass
    implements Insertable<ParseHistoryRecord> {
  /// 目标类型和标准 ID 组成的稳定键，同一个视频或季度重复解析时覆盖旧快照。
  final String historyKey;

  /// 用户最近一次提交的原始输入，回填解析页输入框时使用。
  final String sourceInput;

  /// 标准化后的目标类型，例如 bvid、episode 或 season。
  final String targetKind;

  /// 标准化后的目标 ID，例如 BV 号、ep123 或 ss123。
  final String canonicalId;

  /// 媒体主标题，列表展示和搜索摘要使用。
  final String mediaTitle;

  /// 媒体封面远程地址，接口未返回时为空。
  final String? coverUrl;

  /// UP 主或内容发布者名称，接口未返回时为空。
  final String? publisherName;

  /// 当前解析结果包含的分集数量，列表无需解码 JSON 也能展示。
  final int episodeCount;

  /// 完整媒体和分集快照 JSON，用于点击历史后直接恢复解析页。
  final String mediaJson;

  /// 解析完成时的选中分集 index JSON 数组，用于恢复默认勾选状态。
  final String selectedIndexesJson;

  /// 首次写入该历史目标的时间。
  final DateTime createdAt;

  /// 最近一次解析并刷新快照的时间。
  final DateTime updatedAt;
  const ParseHistoryRecord({
    required this.historyKey,
    required this.sourceInput,
    required this.targetKind,
    required this.canonicalId,
    required this.mediaTitle,
    this.coverUrl,
    this.publisherName,
    required this.episodeCount,
    required this.mediaJson,
    required this.selectedIndexesJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['history_key'] = Variable<String>(historyKey);
    map['source_input'] = Variable<String>(sourceInput);
    map['target_kind'] = Variable<String>(targetKind);
    map['canonical_id'] = Variable<String>(canonicalId);
    map['media_title'] = Variable<String>(mediaTitle);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || publisherName != null) {
      map['publisher_name'] = Variable<String>(publisherName);
    }
    map['episode_count'] = Variable<int>(episodeCount);
    map['media_json'] = Variable<String>(mediaJson);
    map['selected_indexes_json'] = Variable<String>(selectedIndexesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ParseHistoriesCompanion toCompanion(bool nullToAbsent) {
    return ParseHistoriesCompanion(
      historyKey: Value(historyKey),
      sourceInput: Value(sourceInput),
      targetKind: Value(targetKind),
      canonicalId: Value(canonicalId),
      mediaTitle: Value(mediaTitle),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      publisherName: publisherName == null && nullToAbsent
          ? const Value.absent()
          : Value(publisherName),
      episodeCount: Value(episodeCount),
      mediaJson: Value(mediaJson),
      selectedIndexesJson: Value(selectedIndexesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ParseHistoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParseHistoryRecord(
      historyKey: serializer.fromJson<String>(json['historyKey']),
      sourceInput: serializer.fromJson<String>(json['sourceInput']),
      targetKind: serializer.fromJson<String>(json['targetKind']),
      canonicalId: serializer.fromJson<String>(json['canonicalId']),
      mediaTitle: serializer.fromJson<String>(json['mediaTitle']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      publisherName: serializer.fromJson<String?>(json['publisherName']),
      episodeCount: serializer.fromJson<int>(json['episodeCount']),
      mediaJson: serializer.fromJson<String>(json['mediaJson']),
      selectedIndexesJson: serializer.fromJson<String>(
        json['selectedIndexesJson'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'historyKey': serializer.toJson<String>(historyKey),
      'sourceInput': serializer.toJson<String>(sourceInput),
      'targetKind': serializer.toJson<String>(targetKind),
      'canonicalId': serializer.toJson<String>(canonicalId),
      'mediaTitle': serializer.toJson<String>(mediaTitle),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'publisherName': serializer.toJson<String?>(publisherName),
      'episodeCount': serializer.toJson<int>(episodeCount),
      'mediaJson': serializer.toJson<String>(mediaJson),
      'selectedIndexesJson': serializer.toJson<String>(selectedIndexesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ParseHistoryRecord copyWith({
    String? historyKey,
    String? sourceInput,
    String? targetKind,
    String? canonicalId,
    String? mediaTitle,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> publisherName = const Value.absent(),
    int? episodeCount,
    String? mediaJson,
    String? selectedIndexesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ParseHistoryRecord(
    historyKey: historyKey ?? this.historyKey,
    sourceInput: sourceInput ?? this.sourceInput,
    targetKind: targetKind ?? this.targetKind,
    canonicalId: canonicalId ?? this.canonicalId,
    mediaTitle: mediaTitle ?? this.mediaTitle,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    publisherName: publisherName.present
        ? publisherName.value
        : this.publisherName,
    episodeCount: episodeCount ?? this.episodeCount,
    mediaJson: mediaJson ?? this.mediaJson,
    selectedIndexesJson: selectedIndexesJson ?? this.selectedIndexesJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ParseHistoryRecord copyWithCompanion(ParseHistoriesCompanion data) {
    return ParseHistoryRecord(
      historyKey: data.historyKey.present
          ? data.historyKey.value
          : this.historyKey,
      sourceInput: data.sourceInput.present
          ? data.sourceInput.value
          : this.sourceInput,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      canonicalId: data.canonicalId.present
          ? data.canonicalId.value
          : this.canonicalId,
      mediaTitle: data.mediaTitle.present
          ? data.mediaTitle.value
          : this.mediaTitle,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      publisherName: data.publisherName.present
          ? data.publisherName.value
          : this.publisherName,
      episodeCount: data.episodeCount.present
          ? data.episodeCount.value
          : this.episodeCount,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      selectedIndexesJson: data.selectedIndexesJson.present
          ? data.selectedIndexesJson.value
          : this.selectedIndexesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParseHistoryRecord(')
          ..write('historyKey: $historyKey, ')
          ..write('sourceInput: $sourceInput, ')
          ..write('targetKind: $targetKind, ')
          ..write('canonicalId: $canonicalId, ')
          ..write('mediaTitle: $mediaTitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('publisherName: $publisherName, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('selectedIndexesJson: $selectedIndexesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    historyKey,
    sourceInput,
    targetKind,
    canonicalId,
    mediaTitle,
    coverUrl,
    publisherName,
    episodeCount,
    mediaJson,
    selectedIndexesJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParseHistoryRecord &&
          other.historyKey == this.historyKey &&
          other.sourceInput == this.sourceInput &&
          other.targetKind == this.targetKind &&
          other.canonicalId == this.canonicalId &&
          other.mediaTitle == this.mediaTitle &&
          other.coverUrl == this.coverUrl &&
          other.publisherName == this.publisherName &&
          other.episodeCount == this.episodeCount &&
          other.mediaJson == this.mediaJson &&
          other.selectedIndexesJson == this.selectedIndexesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ParseHistoriesCompanion extends UpdateCompanion<ParseHistoryRecord> {
  final Value<String> historyKey;
  final Value<String> sourceInput;
  final Value<String> targetKind;
  final Value<String> canonicalId;
  final Value<String> mediaTitle;
  final Value<String?> coverUrl;
  final Value<String?> publisherName;
  final Value<int> episodeCount;
  final Value<String> mediaJson;
  final Value<String> selectedIndexesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ParseHistoriesCompanion({
    this.historyKey = const Value.absent(),
    this.sourceInput = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.canonicalId = const Value.absent(),
    this.mediaTitle = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.publisherName = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.selectedIndexesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParseHistoriesCompanion.insert({
    required String historyKey,
    required String sourceInput,
    required String targetKind,
    required String canonicalId,
    required String mediaTitle,
    this.coverUrl = const Value.absent(),
    this.publisherName = const Value.absent(),
    this.episodeCount = const Value.absent(),
    required String mediaJson,
    this.selectedIndexesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : historyKey = Value(historyKey),
       sourceInput = Value(sourceInput),
       targetKind = Value(targetKind),
       canonicalId = Value(canonicalId),
       mediaTitle = Value(mediaTitle),
       mediaJson = Value(mediaJson);
  static Insertable<ParseHistoryRecord> custom({
    Expression<String>? historyKey,
    Expression<String>? sourceInput,
    Expression<String>? targetKind,
    Expression<String>? canonicalId,
    Expression<String>? mediaTitle,
    Expression<String>? coverUrl,
    Expression<String>? publisherName,
    Expression<int>? episodeCount,
    Expression<String>? mediaJson,
    Expression<String>? selectedIndexesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (historyKey != null) 'history_key': historyKey,
      if (sourceInput != null) 'source_input': sourceInput,
      if (targetKind != null) 'target_kind': targetKind,
      if (canonicalId != null) 'canonical_id': canonicalId,
      if (mediaTitle != null) 'media_title': mediaTitle,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (publisherName != null) 'publisher_name': publisherName,
      if (episodeCount != null) 'episode_count': episodeCount,
      if (mediaJson != null) 'media_json': mediaJson,
      if (selectedIndexesJson != null)
        'selected_indexes_json': selectedIndexesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParseHistoriesCompanion copyWith({
    Value<String>? historyKey,
    Value<String>? sourceInput,
    Value<String>? targetKind,
    Value<String>? canonicalId,
    Value<String>? mediaTitle,
    Value<String?>? coverUrl,
    Value<String?>? publisherName,
    Value<int>? episodeCount,
    Value<String>? mediaJson,
    Value<String>? selectedIndexesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ParseHistoriesCompanion(
      historyKey: historyKey ?? this.historyKey,
      sourceInput: sourceInput ?? this.sourceInput,
      targetKind: targetKind ?? this.targetKind,
      canonicalId: canonicalId ?? this.canonicalId,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      publisherName: publisherName ?? this.publisherName,
      episodeCount: episodeCount ?? this.episodeCount,
      mediaJson: mediaJson ?? this.mediaJson,
      selectedIndexesJson: selectedIndexesJson ?? this.selectedIndexesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (historyKey.present) {
      map['history_key'] = Variable<String>(historyKey.value);
    }
    if (sourceInput.present) {
      map['source_input'] = Variable<String>(sourceInput.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<String>(targetKind.value);
    }
    if (canonicalId.present) {
      map['canonical_id'] = Variable<String>(canonicalId.value);
    }
    if (mediaTitle.present) {
      map['media_title'] = Variable<String>(mediaTitle.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (publisherName.present) {
      map['publisher_name'] = Variable<String>(publisherName.value);
    }
    if (episodeCount.present) {
      map['episode_count'] = Variable<int>(episodeCount.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (selectedIndexesJson.present) {
      map['selected_indexes_json'] = Variable<String>(
        selectedIndexesJson.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParseHistoriesCompanion(')
          ..write('historyKey: $historyKey, ')
          ..write('sourceInput: $sourceInput, ')
          ..write('targetKind: $targetKind, ')
          ..write('canonicalId: $canonicalId, ')
          ..write('mediaTitle: $mediaTitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('publisherName: $publisherName, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('selectedIndexesJson: $selectedIndexesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $DownloadStreamsTable downloadStreams = $DownloadStreamsTable(
    this,
  );
  late final $DownloadArtifactsTable downloadArtifacts =
      $DownloadArtifactsTable(this);
  late final $ParseHistoriesTable parseHistories = $ParseHistoriesTable(this);
  late final Index downloadTasksPhaseUpdated = Index(
    'download_tasks_phase_updated',
    'CREATE INDEX download_tasks_phase_updated ON download_tasks (phase, updated_at)',
  );
  late final Index downloadStreamsEngineTask = Index(
    'download_streams_engine_task',
    'CREATE UNIQUE INDEX download_streams_engine_task ON download_streams (engine_task_id)',
  );
  late final Index downloadArtifactsTaskKind = Index(
    'download_artifacts_task_kind',
    'CREATE INDEX download_artifacts_task_kind ON download_artifacts (task_id, kind)',
  );
  late final Index parseHistoriesUpdated = Index(
    'parse_histories_updated',
    'CREATE INDEX parse_histories_updated ON parse_histories (updated_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadTasks,
    downloadStreams,
    downloadArtifacts,
    parseHistories,
    downloadTasksPhaseUpdated,
    downloadStreamsEngineTask,
    downloadArtifactsTaskKind,
    parseHistoriesUpdated,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'download_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_streams', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'download_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_artifacts', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String taskId,
      required String sourceInput,
      Value<String?> bvid,
      Value<int?> cid,
      Value<int?> epid,
      required String title,
      Value<String?> publisherName,
      Value<int?> publisherId,
      Value<String?> collectionTitle,
      Value<String?> contentType,
      Value<String?> description,
      Value<String?> resolutionLabel,
      Value<DateTime?> publishedAt,
      Value<String?> coverUrl,
      Value<int> partIndex,
      Value<int?> qualityId,
      Value<String?> qualityLabel,
      Value<String?> videoCodec,
      Value<String?> audioCodec,
      Value<int?> audioQualityId,
      Value<int?> estimatedVideoSizeBytes,
      Value<int?> estimatedAudioSizeBytes,
      Value<String?> dashOptionsJson,
      Value<String> extraResourcesJson,
      Value<int?> durationMilliseconds,
      Value<String?> temporaryDirectory,
      Value<String?> outputPath,
      Value<PersistedDownloadBackend?> downloadBackend,
      Value<DownloadTaskPhase> phase,
      Value<DownloadTaskPhase?> resumePhase,
      Value<double> progress,
      Value<int> downloadSpeedBytesPerSecond,
      Value<int> retryCount,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> taskId,
      Value<String> sourceInput,
      Value<String?> bvid,
      Value<int?> cid,
      Value<int?> epid,
      Value<String> title,
      Value<String?> publisherName,
      Value<int?> publisherId,
      Value<String?> collectionTitle,
      Value<String?> contentType,
      Value<String?> description,
      Value<String?> resolutionLabel,
      Value<DateTime?> publishedAt,
      Value<String?> coverUrl,
      Value<int> partIndex,
      Value<int?> qualityId,
      Value<String?> qualityLabel,
      Value<String?> videoCodec,
      Value<String?> audioCodec,
      Value<int?> audioQualityId,
      Value<int?> estimatedVideoSizeBytes,
      Value<int?> estimatedAudioSizeBytes,
      Value<String?> dashOptionsJson,
      Value<String> extraResourcesJson,
      Value<int?> durationMilliseconds,
      Value<String?> temporaryDirectory,
      Value<String?> outputPath,
      Value<PersistedDownloadBackend?> downloadBackend,
      Value<DownloadTaskPhase> phase,
      Value<DownloadTaskPhase?> resumePhase,
      Value<double> progress,
      Value<int> downloadSpeedBytesPerSecond,
      Value<int> retryCount,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$DownloadTasksTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTaskRecord> {
  $$DownloadTasksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DownloadStreamsTable, List<DownloadStreamRecord>>
  _downloadStreamsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadStreams,
    aliasName: 'download_tasks__task_id__download_streams__task_id',
  );

  $$DownloadStreamsTableProcessedTableManager get downloadStreamsRefs {
    final manager =
        $$DownloadStreamsTableTableManager($_db, $_db.downloadStreams).filter(
          (f) => f.taskId.taskId.sqlEquals($_itemColumn<String>('task_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _downloadStreamsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DownloadArtifactsTable,
    List<DownloadArtifactRecord>
  >
  _downloadArtifactsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.downloadArtifacts,
        aliasName: 'download_tasks__task_id__download_artifacts__task_id',
      );

  $$DownloadArtifactsTableProcessedTableManager get downloadArtifactsRefs {
    final manager =
        $$DownloadArtifactsTableTableManager(
          $_db,
          $_db.downloadArtifacts,
        ).filter(
          (f) => f.taskId.taskId.sqlEquals($_itemColumn<String>('task_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _downloadArtifactsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bvid => $composableBuilder(
    column: $table.bvid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cid => $composableBuilder(
    column: $table.cid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epid => $composableBuilder(
    column: $table.epid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionTitle => $composableBuilder(
    column: $table.collectionTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionLabel => $composableBuilder(
    column: $table.resolutionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partIndex => $composableBuilder(
    column: $table.partIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioQualityId => $composableBuilder(
    column: $table.audioQualityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedVideoSizeBytes => $composableBuilder(
    column: $table.estimatedVideoSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedAudioSizeBytes => $composableBuilder(
    column: $table.estimatedAudioSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dashOptionsJson => $composableBuilder(
    column: $table.dashOptionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraResourcesJson => $composableBuilder(
    column: $table.extraResourcesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporaryDirectory => $composableBuilder(
    column: $table.temporaryDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    PersistedDownloadBackend?,
    PersistedDownloadBackend,
    String
  >
  get downloadBackend => $composableBuilder(
    column: $table.downloadBackend,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadTaskPhase, DownloadTaskPhase, String>
  get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadTaskPhase?, DownloadTaskPhase, String>
  get resumePhase => $composableBuilder(
    column: $table.resumePhase,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadStreamsRefs(
    Expression<bool> Function($$DownloadStreamsTableFilterComposer f) f,
  ) {
    final $$DownloadStreamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadStreams,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadStreamsTableFilterComposer(
            $db: $db,
            $table: $db.downloadStreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadArtifactsRefs(
    Expression<bool> Function($$DownloadArtifactsTableFilterComposer f) f,
  ) {
    final $$DownloadArtifactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadArtifacts,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadArtifactsTableFilterComposer(
            $db: $db,
            $table: $db.downloadArtifacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bvid => $composableBuilder(
    column: $table.bvid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cid => $composableBuilder(
    column: $table.cid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epid => $composableBuilder(
    column: $table.epid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionTitle => $composableBuilder(
    column: $table.collectionTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionLabel => $composableBuilder(
    column: $table.resolutionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partIndex => $composableBuilder(
    column: $table.partIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioQualityId => $composableBuilder(
    column: $table.audioQualityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedVideoSizeBytes => $composableBuilder(
    column: $table.estimatedVideoSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedAudioSizeBytes => $composableBuilder(
    column: $table.estimatedAudioSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dashOptionsJson => $composableBuilder(
    column: $table.dashOptionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraResourcesJson => $composableBuilder(
    column: $table.extraResourcesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporaryDirectory => $composableBuilder(
    column: $table.temporaryDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadBackend => $composableBuilder(
    column: $table.downloadBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resumePhase => $composableBuilder(
    column: $table.resumePhase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bvid =>
      $composableBuilder(column: $table.bvid, builder: (column) => column);

  GeneratedColumn<int> get cid =>
      $composableBuilder(column: $table.cid, builder: (column) => column);

  GeneratedColumn<int> get epid =>
      $composableBuilder(column: $table.epid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectionTitle => $composableBuilder(
    column: $table.collectionTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionLabel => $composableBuilder(
    column: $table.resolutionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get partIndex =>
      $composableBuilder(column: $table.partIndex, builder: (column) => column);

  GeneratedColumn<int> get qualityId =>
      $composableBuilder(column: $table.qualityId, builder: (column) => column);

  GeneratedColumn<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioCodec => $composableBuilder(
    column: $table.audioCodec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioQualityId => $composableBuilder(
    column: $table.audioQualityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedVideoSizeBytes => $composableBuilder(
    column: $table.estimatedVideoSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedAudioSizeBytes => $composableBuilder(
    column: $table.estimatedAudioSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dashOptionsJson => $composableBuilder(
    column: $table.dashOptionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extraResourcesJson => $composableBuilder(
    column: $table.extraResourcesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporaryDirectory => $composableBuilder(
    column: $table.temporaryDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PersistedDownloadBackend?, String>
  get downloadBackend => $composableBuilder(
    column: $table.downloadBackend,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadTaskPhase, String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadTaskPhase?, String>
  get resumePhase => $composableBuilder(
    column: $table.resumePhase,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  Expression<T> downloadStreamsRefs<T extends Object>(
    Expression<T> Function($$DownloadStreamsTableAnnotationComposer a) f,
  ) {
    final $$DownloadStreamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadStreams,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadStreamsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadStreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> downloadArtifactsRefs<T extends Object>(
    Expression<T> Function($$DownloadArtifactsTableAnnotationComposer a) f,
  ) {
    final $$DownloadArtifactsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadArtifacts,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadArtifactsTableAnnotationComposer(
                $db: $db,
                $table: $db.downloadArtifacts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTaskRecord,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (DownloadTaskRecord, $$DownloadTasksTableReferences),
          DownloadTaskRecord,
          PrefetchHooks Function({
            bool downloadStreamsRefs,
            bool downloadArtifactsRefs,
          })
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> sourceInput = const Value.absent(),
                Value<String?> bvid = const Value.absent(),
                Value<int?> cid = const Value.absent(),
                Value<int?> epid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> publisherName = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                Value<String?> collectionTitle = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> resolutionLabel = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int> partIndex = const Value.absent(),
                Value<int?> qualityId = const Value.absent(),
                Value<String?> qualityLabel = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<int?> audioQualityId = const Value.absent(),
                Value<int?> estimatedVideoSizeBytes = const Value.absent(),
                Value<int?> estimatedAudioSizeBytes = const Value.absent(),
                Value<String?> dashOptionsJson = const Value.absent(),
                Value<String> extraResourcesJson = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<String?> temporaryDirectory = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<PersistedDownloadBackend?> downloadBackend =
                    const Value.absent(),
                Value<DownloadTaskPhase> phase = const Value.absent(),
                Value<DownloadTaskPhase?> resumePhase = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> downloadSpeedBytesPerSecond = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                taskId: taskId,
                sourceInput: sourceInput,
                bvid: bvid,
                cid: cid,
                epid: epid,
                title: title,
                publisherName: publisherName,
                publisherId: publisherId,
                collectionTitle: collectionTitle,
                contentType: contentType,
                description: description,
                resolutionLabel: resolutionLabel,
                publishedAt: publishedAt,
                coverUrl: coverUrl,
                partIndex: partIndex,
                qualityId: qualityId,
                qualityLabel: qualityLabel,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                audioQualityId: audioQualityId,
                estimatedVideoSizeBytes: estimatedVideoSizeBytes,
                estimatedAudioSizeBytes: estimatedAudioSizeBytes,
                dashOptionsJson: dashOptionsJson,
                extraResourcesJson: extraResourcesJson,
                durationMilliseconds: durationMilliseconds,
                temporaryDirectory: temporaryDirectory,
                outputPath: outputPath,
                downloadBackend: downloadBackend,
                phase: phase,
                resumePhase: resumePhase,
                progress: progress,
                downloadSpeedBytesPerSecond: downloadSpeedBytesPerSecond,
                retryCount: retryCount,
                errorCode: errorCode,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String sourceInput,
                Value<String?> bvid = const Value.absent(),
                Value<int?> cid = const Value.absent(),
                Value<int?> epid = const Value.absent(),
                required String title,
                Value<String?> publisherName = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                Value<String?> collectionTitle = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> resolutionLabel = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int> partIndex = const Value.absent(),
                Value<int?> qualityId = const Value.absent(),
                Value<String?> qualityLabel = const Value.absent(),
                Value<String?> videoCodec = const Value.absent(),
                Value<String?> audioCodec = const Value.absent(),
                Value<int?> audioQualityId = const Value.absent(),
                Value<int?> estimatedVideoSizeBytes = const Value.absent(),
                Value<int?> estimatedAudioSizeBytes = const Value.absent(),
                Value<String?> dashOptionsJson = const Value.absent(),
                Value<String> extraResourcesJson = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<String?> temporaryDirectory = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<PersistedDownloadBackend?> downloadBackend =
                    const Value.absent(),
                Value<DownloadTaskPhase> phase = const Value.absent(),
                Value<DownloadTaskPhase?> resumePhase = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> downloadSpeedBytesPerSecond = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                taskId: taskId,
                sourceInput: sourceInput,
                bvid: bvid,
                cid: cid,
                epid: epid,
                title: title,
                publisherName: publisherName,
                publisherId: publisherId,
                collectionTitle: collectionTitle,
                contentType: contentType,
                description: description,
                resolutionLabel: resolutionLabel,
                publishedAt: publishedAt,
                coverUrl: coverUrl,
                partIndex: partIndex,
                qualityId: qualityId,
                qualityLabel: qualityLabel,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                audioQualityId: audioQualityId,
                estimatedVideoSizeBytes: estimatedVideoSizeBytes,
                estimatedAudioSizeBytes: estimatedAudioSizeBytes,
                dashOptionsJson: dashOptionsJson,
                extraResourcesJson: extraResourcesJson,
                durationMilliseconds: durationMilliseconds,
                temporaryDirectory: temporaryDirectory,
                outputPath: outputPath,
                downloadBackend: downloadBackend,
                phase: phase,
                resumePhase: resumePhase,
                progress: progress,
                downloadSpeedBytesPerSecond: downloadSpeedBytesPerSecond,
                retryCount: retryCount,
                errorCode: errorCode,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({downloadStreamsRefs = false, downloadArtifactsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (downloadStreamsRefs) db.downloadStreams,
                    if (downloadArtifactsRefs) db.downloadArtifacts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (downloadStreamsRefs)
                        await $_getPrefetchedData<
                          DownloadTaskRecord,
                          $DownloadTasksTable,
                          DownloadStreamRecord
                        >(
                          currentTable: table,
                          referencedTable: $$DownloadTasksTableReferences
                              ._downloadStreamsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DownloadTasksTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadStreamsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.taskId,
                              ),
                          typedResults: items,
                        ),
                      if (downloadArtifactsRefs)
                        await $_getPrefetchedData<
                          DownloadTaskRecord,
                          $DownloadTasksTable,
                          DownloadArtifactRecord
                        >(
                          currentTable: table,
                          referencedTable: $$DownloadTasksTableReferences
                              ._downloadArtifactsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DownloadTasksTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadArtifactsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.taskId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTaskRecord,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (DownloadTaskRecord, $$DownloadTasksTableReferences),
      DownloadTaskRecord,
      PrefetchHooks Function({
        bool downloadStreamsRefs,
        bool downloadArtifactsRefs,
      })
    >;
typedef $$DownloadStreamsTableCreateCompanionBuilder =
    DownloadStreamsCompanion Function({
      required String streamId,
      required String taskId,
      required DownloadStreamKind kind,
      required String remoteUrl,
      Value<String?> codec,
      required String temporaryPath,
      Value<String?> engineTaskId,
      Value<DownloadStreamPhase> phase,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<int> downloadSpeedBytesPerSecond,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime> urlRefreshedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadStreamsTableUpdateCompanionBuilder =
    DownloadStreamsCompanion Function({
      Value<String> streamId,
      Value<String> taskId,
      Value<DownloadStreamKind> kind,
      Value<String> remoteUrl,
      Value<String?> codec,
      Value<String> temporaryPath,
      Value<String?> engineTaskId,
      Value<DownloadStreamPhase> phase,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<int> downloadSpeedBytesPerSecond,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime> urlRefreshedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DownloadStreamsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadStreamsTable,
          DownloadStreamRecord
        > {
  $$DownloadStreamsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadTasksTable _taskIdTable(_$AppDatabase db) => db.downloadTasks
      .createAlias('download_streams__task_id__download_tasks__task_id');

  $$DownloadTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$DownloadTasksTableTableManager(
      $_db,
      $_db.downloadTasks,
    ).filter((f) => f.taskId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadStreamsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadStreamsTable> {
  $$DownloadStreamsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStreamKind, DownloadStreamKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporaryPath => $composableBuilder(
    column: $table.temporaryPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineTaskId => $composableBuilder(
    column: $table.engineTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DownloadStreamPhase,
    DownloadStreamPhase,
    String
  >
  get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get urlRefreshedAt => $composableBuilder(
    column: $table.urlRefreshedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadTasksTableFilterComposer get taskId {
    final $$DownloadTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableFilterComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadStreamsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadStreamsTable> {
  $$DownloadStreamsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporaryPath => $composableBuilder(
    column: $table.temporaryPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineTaskId => $composableBuilder(
    column: $table.engineTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get urlRefreshedAt => $composableBuilder(
    column: $table.urlRefreshedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadTasksTableOrderingComposer get taskId {
    final $$DownloadTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableOrderingComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadStreamsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadStreamsTable> {
  $$DownloadStreamsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get streamId =>
      $composableBuilder(column: $table.streamId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStreamKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);

  GeneratedColumn<String> get temporaryPath => $composableBuilder(
    column: $table.temporaryPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engineTaskId => $composableBuilder(
    column: $table.engineTaskId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadStreamPhase, String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadSpeedBytesPerSecond => $composableBuilder(
    column: $table.downloadSpeedBytesPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get urlRefreshedAt => $composableBuilder(
    column: $table.urlRefreshedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DownloadTasksTableAnnotationComposer get taskId {
    final $$DownloadTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadStreamsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadStreamsTable,
          DownloadStreamRecord,
          $$DownloadStreamsTableFilterComposer,
          $$DownloadStreamsTableOrderingComposer,
          $$DownloadStreamsTableAnnotationComposer,
          $$DownloadStreamsTableCreateCompanionBuilder,
          $$DownloadStreamsTableUpdateCompanionBuilder,
          (DownloadStreamRecord, $$DownloadStreamsTableReferences),
          DownloadStreamRecord,
          PrefetchHooks Function({bool taskId})
        > {
  $$DownloadStreamsTableTableManager(
    _$AppDatabase db,
    $DownloadStreamsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadStreamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadStreamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadStreamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> streamId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<DownloadStreamKind> kind = const Value.absent(),
                Value<String> remoteUrl = const Value.absent(),
                Value<String?> codec = const Value.absent(),
                Value<String> temporaryPath = const Value.absent(),
                Value<String?> engineTaskId = const Value.absent(),
                Value<DownloadStreamPhase> phase = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadSpeedBytesPerSecond = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> urlRefreshedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadStreamsCompanion(
                streamId: streamId,
                taskId: taskId,
                kind: kind,
                remoteUrl: remoteUrl,
                codec: codec,
                temporaryPath: temporaryPath,
                engineTaskId: engineTaskId,
                phase: phase,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                downloadSpeedBytesPerSecond: downloadSpeedBytesPerSecond,
                errorCode: errorCode,
                errorMessage: errorMessage,
                urlRefreshedAt: urlRefreshedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String streamId,
                required String taskId,
                required DownloadStreamKind kind,
                required String remoteUrl,
                Value<String?> codec = const Value.absent(),
                required String temporaryPath,
                Value<String?> engineTaskId = const Value.absent(),
                Value<DownloadStreamPhase> phase = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadSpeedBytesPerSecond = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> urlRefreshedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadStreamsCompanion.insert(
                streamId: streamId,
                taskId: taskId,
                kind: kind,
                remoteUrl: remoteUrl,
                codec: codec,
                temporaryPath: temporaryPath,
                engineTaskId: engineTaskId,
                phase: phase,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                downloadSpeedBytesPerSecond: downloadSpeedBytesPerSecond,
                errorCode: errorCode,
                errorMessage: errorMessage,
                urlRefreshedAt: urlRefreshedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadStreamsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$DownloadStreamsTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$DownloadStreamsTableReferences
                                        ._taskIdTable(db)
                                        .taskId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadStreamsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadStreamsTable,
      DownloadStreamRecord,
      $$DownloadStreamsTableFilterComposer,
      $$DownloadStreamsTableOrderingComposer,
      $$DownloadStreamsTableAnnotationComposer,
      $$DownloadStreamsTableCreateCompanionBuilder,
      $$DownloadStreamsTableUpdateCompanionBuilder,
      (DownloadStreamRecord, $$DownloadStreamsTableReferences),
      DownloadStreamRecord,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$DownloadArtifactsTableCreateCompanionBuilder =
    DownloadArtifactsCompanion Function({
      Value<int> id,
      required String taskId,
      required DownloadArtifactKind kind,
      required String path,
      Value<int?> sizeBytes,
      Value<String?> checksum,
      Value<bool> retained,
      Value<DateTime> createdAt,
    });
typedef $$DownloadArtifactsTableUpdateCompanionBuilder =
    DownloadArtifactsCompanion Function({
      Value<int> id,
      Value<String> taskId,
      Value<DownloadArtifactKind> kind,
      Value<String> path,
      Value<int?> sizeBytes,
      Value<String?> checksum,
      Value<bool> retained,
      Value<DateTime> createdAt,
    });

final class $$DownloadArtifactsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadArtifactsTable,
          DownloadArtifactRecord
        > {
  $$DownloadArtifactsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadTasksTable _taskIdTable(_$AppDatabase db) => db.downloadTasks
      .createAlias('download_artifacts__task_id__download_tasks__task_id');

  $$DownloadTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$DownloadTasksTableTableManager(
      $_db,
      $_db.downloadTasks,
    ).filter((f) => f.taskId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadArtifactsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadArtifactsTable> {
  $$DownloadArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DownloadArtifactKind,
    DownloadArtifactKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retained => $composableBuilder(
    column: $table.retained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadTasksTableFilterComposer get taskId {
    final $$DownloadTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableFilterComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadArtifactsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadArtifactsTable> {
  $$DownloadArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retained => $composableBuilder(
    column: $table.retained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadTasksTableOrderingComposer get taskId {
    final $$DownloadTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableOrderingComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadArtifactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadArtifactsTable> {
  $$DownloadArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadArtifactKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<bool> get retained =>
      $composableBuilder(column: $table.retained, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DownloadTasksTableAnnotationComposer get taskId {
    final $$DownloadTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadArtifactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadArtifactsTable,
          DownloadArtifactRecord,
          $$DownloadArtifactsTableFilterComposer,
          $$DownloadArtifactsTableOrderingComposer,
          $$DownloadArtifactsTableAnnotationComposer,
          $$DownloadArtifactsTableCreateCompanionBuilder,
          $$DownloadArtifactsTableUpdateCompanionBuilder,
          (DownloadArtifactRecord, $$DownloadArtifactsTableReferences),
          DownloadArtifactRecord,
          PrefetchHooks Function({bool taskId})
        > {
  $$DownloadArtifactsTableTableManager(
    _$AppDatabase db,
    $DownloadArtifactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadArtifactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadArtifactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadArtifactsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<DownloadArtifactKind> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<bool> retained = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DownloadArtifactsCompanion(
                id: id,
                taskId: taskId,
                kind: kind,
                path: path,
                sizeBytes: sizeBytes,
                checksum: checksum,
                retained: retained,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String taskId,
                required DownloadArtifactKind kind,
                required String path,
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<bool> retained = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DownloadArtifactsCompanion.insert(
                id: id,
                taskId: taskId,
                kind: kind,
                path: path,
                sizeBytes: sizeBytes,
                checksum: checksum,
                retained: retained,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadArtifactsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$DownloadArtifactsTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$DownloadArtifactsTableReferences
                                        ._taskIdTable(db)
                                        .taskId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadArtifactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadArtifactsTable,
      DownloadArtifactRecord,
      $$DownloadArtifactsTableFilterComposer,
      $$DownloadArtifactsTableOrderingComposer,
      $$DownloadArtifactsTableAnnotationComposer,
      $$DownloadArtifactsTableCreateCompanionBuilder,
      $$DownloadArtifactsTableUpdateCompanionBuilder,
      (DownloadArtifactRecord, $$DownloadArtifactsTableReferences),
      DownloadArtifactRecord,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$ParseHistoriesTableCreateCompanionBuilder =
    ParseHistoriesCompanion Function({
      required String historyKey,
      required String sourceInput,
      required String targetKind,
      required String canonicalId,
      required String mediaTitle,
      Value<String?> coverUrl,
      Value<String?> publisherName,
      Value<int> episodeCount,
      required String mediaJson,
      Value<String> selectedIndexesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ParseHistoriesTableUpdateCompanionBuilder =
    ParseHistoriesCompanion Function({
      Value<String> historyKey,
      Value<String> sourceInput,
      Value<String> targetKind,
      Value<String> canonicalId,
      Value<String> mediaTitle,
      Value<String?> coverUrl,
      Value<String?> publisherName,
      Value<int> episodeCount,
      Value<String> mediaJson,
      Value<String> selectedIndexesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ParseHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ParseHistoriesTable> {
  $$ParseHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get historyKey => $composableBuilder(
    column: $table.historyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalId => $composableBuilder(
    column: $table.canonicalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedIndexesJson => $composableBuilder(
    column: $table.selectedIndexesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParseHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParseHistoriesTable> {
  $$ParseHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get historyKey => $composableBuilder(
    column: $table.historyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalId => $composableBuilder(
    column: $table.canonicalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedIndexesJson => $composableBuilder(
    column: $table.selectedIndexesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParseHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParseHistoriesTable> {
  $$ParseHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get historyKey => $composableBuilder(
    column: $table.historyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceInput => $composableBuilder(
    column: $table.sourceInput,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalId => $composableBuilder(
    column: $table.canonicalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<String> get selectedIndexesJson => $composableBuilder(
    column: $table.selectedIndexesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ParseHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParseHistoriesTable,
          ParseHistoryRecord,
          $$ParseHistoriesTableFilterComposer,
          $$ParseHistoriesTableOrderingComposer,
          $$ParseHistoriesTableAnnotationComposer,
          $$ParseHistoriesTableCreateCompanionBuilder,
          $$ParseHistoriesTableUpdateCompanionBuilder,
          (
            ParseHistoryRecord,
            BaseReferences<
              _$AppDatabase,
              $ParseHistoriesTable,
              ParseHistoryRecord
            >,
          ),
          ParseHistoryRecord,
          PrefetchHooks Function()
        > {
  $$ParseHistoriesTableTableManager(
    _$AppDatabase db,
    $ParseHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParseHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParseHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParseHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> historyKey = const Value.absent(),
                Value<String> sourceInput = const Value.absent(),
                Value<String> targetKind = const Value.absent(),
                Value<String> canonicalId = const Value.absent(),
                Value<String> mediaTitle = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> publisherName = const Value.absent(),
                Value<int> episodeCount = const Value.absent(),
                Value<String> mediaJson = const Value.absent(),
                Value<String> selectedIndexesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParseHistoriesCompanion(
                historyKey: historyKey,
                sourceInput: sourceInput,
                targetKind: targetKind,
                canonicalId: canonicalId,
                mediaTitle: mediaTitle,
                coverUrl: coverUrl,
                publisherName: publisherName,
                episodeCount: episodeCount,
                mediaJson: mediaJson,
                selectedIndexesJson: selectedIndexesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String historyKey,
                required String sourceInput,
                required String targetKind,
                required String canonicalId,
                required String mediaTitle,
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> publisherName = const Value.absent(),
                Value<int> episodeCount = const Value.absent(),
                required String mediaJson,
                Value<String> selectedIndexesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParseHistoriesCompanion.insert(
                historyKey: historyKey,
                sourceInput: sourceInput,
                targetKind: targetKind,
                canonicalId: canonicalId,
                mediaTitle: mediaTitle,
                coverUrl: coverUrl,
                publisherName: publisherName,
                episodeCount: episodeCount,
                mediaJson: mediaJson,
                selectedIndexesJson: selectedIndexesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParseHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParseHistoriesTable,
      ParseHistoryRecord,
      $$ParseHistoriesTableFilterComposer,
      $$ParseHistoriesTableOrderingComposer,
      $$ParseHistoriesTableAnnotationComposer,
      $$ParseHistoriesTableCreateCompanionBuilder,
      $$ParseHistoriesTableUpdateCompanionBuilder,
      (
        ParseHistoryRecord,
        BaseReferences<_$AppDatabase, $ParseHistoriesTable, ParseHistoryRecord>,
      ),
      ParseHistoryRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$DownloadStreamsTableTableManager get downloadStreams =>
      $$DownloadStreamsTableTableManager(_db, _db.downloadStreams);
  $$DownloadArtifactsTableTableManager get downloadArtifacts =>
      $$DownloadArtifactsTableTableManager(_db, _db.downloadArtifacts);
  $$ParseHistoriesTableTableManager get parseHistories =>
      $$ParseHistoriesTableTableManager(_db, _db.parseHistories);
}
