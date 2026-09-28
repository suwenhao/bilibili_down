import 'package:dio/dio.dart';

import '../../core/network/bili_network_client.dart';
import 'bili_api_exception.dart';

/// 首期支持的 B 站输入类型。
enum BiliInputKind {
  /// BV 普通视频或 UGC 合集。
  bvid,

  /// av 旧普通视频稿件号。
  avid,

  /// ep 番剧分集。
  episode,

  /// ss 番剧季度。
  season,
}

/// 已完成格式校验和短链接展开的标准输入。
final class BiliInputTarget {
  /// 创建一个标准化 BVID 目标。
  const BiliInputTarget.bvid(String this.bvid, {this.pageNumber})
    : kind = BiliInputKind.bvid,
      numericId = null;

  /// 创建一个标准化 AV、EP 或 SS 数字目标。
  const BiliInputTarget.numeric(this.kind, int this.numericId)
    : bvid = null,
      pageNumber = null;

  /// 输入类型。
  final BiliInputKind kind;

  /// BV 目标的完整 BVID。
  final String? bvid;

  /// AV、EP 或 SS 目标的数字 ID。
  final int? numericId;

  /// 普通视频 URL 中的 p 参数，用于定位同一 BV 下的具体分 P。
  final int? pageNumber;

  /// 返回可用于接口请求和日志的标准文本。
  String get canonicalId => switch (kind) {
    BiliInputKind.bvid => bvid!,
    BiliInputKind.avid => 'av$numericId',
    BiliInputKind.episode => 'ep$numericId',
    BiliInputKind.season => 'ss$numericId',
  };
}

/// 将 BV/AV/EP/SS、标准网页和 b23.tv 短链接归一化。
final class BiliInputNormalizer {
  /// 使用统一网络客户端创建短链接解析器。
  const BiliInputNormalizer(this._networkClient);

  /// BVID 固定为 BV1 加九个字母或数字。
  static final RegExp _bvidPattern = RegExp(
    r'^(BV1[0-9A-Za-z]{9})$',
    caseSensitive: false,
  );

  /// AV 直接输入格式，只接受带 av 前缀的旧稿件号。
  static final RegExp _avidPattern = RegExp(
    r'^(av)(\d+)$',
    caseSensitive: false,
  );

  /// 解析页明确输入场景下允许裸数字作为 AV 稿件号。
  static final RegExp _directAvidNumberPattern = RegExp(r'^\d+$');

  /// EP 和 SS 直接输入格式。
  static final RegExp _seasonPattern = RegExp(
    r'^(ep|ss)(\d+)$',
    caseSensitive: false,
  );

  /// 标准网页路径中的 BV、AV、EP 或 SS 标识。
  static final RegExp _pathIdentifierPattern = RegExp(
    r'(BV1[0-9A-Za-z]{9}|av\d+|ep\d+|ss\d+)',
    caseSensitive: false,
  );

  /// 普通文本中的独立 BV、AV、EP 或 SS 标识。
  static final RegExp _looseIdentifierPattern = RegExp(
    r'(^|[^0-9A-Za-z])(BV1[0-9A-Za-z]{9}|av\d+|ep\d+|ss\d+)(?=$|[^0-9A-Za-z])',
    caseSensitive: false,
  );

  /// 从 App 复制的整段分享文案中查找 HTTP(S) 链接。
  static final RegExp _sharedUrlPattern = RegExp(
    r'https?://\S+',
    caseSensitive: false,
  );

  /// 分享文案中紧跟在链接后的常见中英文标点，不能作为 URL 的一部分。
  static final RegExp _sharedUrlTrailingPunctuation = RegExp(
    r'[)\]}>）】》」』，。！？；、"]+$',
  );

  /// 允许解析的 B 站网页域名。
  static const Set<String> _allowedHosts = <String>{
    'bilibili.com',
    'www.bilibili.com',
    'm.bilibili.com',
  };

  /// 统一网络客户端，仅用于受信任短链接跳转。
  final BiliNetworkClient _networkClient;

  /// 解析用户输入并返回标准目标。
  Future<BiliInputTarget> normalize(
    String input, {
    CancelToken? cancelToken,
  }) async {
    // 去除粘贴时携带的首尾空白。
    final normalizedInput = input.trim();
    // 空输入立即返回明确格式错误。
    if (normalizedInput.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '请输入 BV、AV、EP、SS 或 B 站视频链接。',
      );
    }
    // B 站 App 的“复制链接”会附带标题等分享文案，先提取其中受信任的 B 站链接再走原有解析流程。
    final extractedSharedUrl = _extractSharedUrl(normalizedInput);
    final inputCandidate = extractedSharedUrl ?? normalizedInput;
    // 含有非白名单链接的文本不能回退为裸标识，避免钓鱼链接夹带伪造编号。
    final inputContainsUrl = _sharedUrlPattern.hasMatch(normalizedInput);
    // 优先匹配无需网络的直接 BVID。
    final bvidMatch = _bvidPattern.firstMatch(inputCandidate);
    if (bvidMatch != null) {
      // BVID 前缀规范化为大写 BV，主体保留接口原字符。
      final value = bvidMatch.group(1)!;
      return BiliInputTarget.bvid('BV${value.substring(2)}');
    }
    // 其次匹配旧 AV 稿件号，纯数字不解析以避免误触普通文本。
    final avidMatch = _avidPattern.firstMatch(inputCandidate);
    if (avidMatch != null) return _targetFromAvidMatch(avidMatch);
    // 再匹配直接 EP 或 SS 标识。
    final seasonMatch = _seasonPattern.firstMatch(inputCandidate);
    if (seasonMatch != null) return _targetFromSeasonMatch(seasonMatch);
    if (extractedSharedUrl == null && !inputContainsUrl) {
      // 用户在输入框里常会粘贴“BV号：xxx”或“AV号：xxx”，允许从普通文本提取独立标识。
      final looseTarget = _targetFromLooseText(inputCandidate);
      if (looseTarget != null) return looseTarget;
      // 解析输入框是明确视频目标场景，纯数字按旧 AV 稿件号处理。
      final directAvidTarget = _targetFromDirectAvidNumber(inputCandidate);
      if (directAvidTarget != null) return directAvidTarget;
    }
    // 其余输入必须是完整 HTTP(S) URL。
    final uri = Uri.tryParse(inputCandidate);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '无法识别该 B 站视频地址。',
      );
    }
    // b23.tv 的路径是随机短码，必须先展开最终地址再解析，不能把短码误当视频标识。
    if (uri.host.toLowerCase() == 'b23.tv') {
      // 普通短码通过受限网络方法解析最终地址。
      final redirected = await _networkClient.resolveShortLink(
        uri.replace(scheme: 'https'),
        cancelToken: cancelToken,
      );
      // 只允许一层短链接展开，防止循环跳转。
      return _normalizeBilibiliUri(redirected);
    }
    // 标准 B 站域名直接从路径提取标识。
    return _normalizeBilibiliUri(uri);
  }

  /// 从分享文案中提取第一个受支持的 B 站网页或短链接。
  String? _extractSharedUrl(String input) {
    // 遍历全部链接而不是直接取第一个，避免分享文案中的其他网址遮挡真正的视频链接。
    for (final match in _sharedUrlPattern.allMatches(input)) {
      // 清除中文句号、右括号等紧邻链接的文案标点，保留 URL 自身的查询参数。
      final candidate = match
          .group(0)!
          .replaceFirst(_sharedUrlTrailingPunctuation, '');
      // 仅接受可以安全解析且属于既有白名单的链接。
      final uri = Uri.tryParse(candidate);
      if (uri == null || uri.host.isEmpty) continue;
      final host = uri.host.toLowerCase();
      // b23.tv 交由受限短链解析器展开，标准站点继续从路径读取视频标识。
      if (host == 'b23.tv' || _allowedHosts.contains(host)) return candidate;
    }
    // 没有受支持链接时保留原输入，让调用方获得原有的格式错误提示。
    return null;
  }

  /// 从已经展开的 B 站网页地址解析目标。
  BiliInputTarget _normalizeBilibiliUri(Uri uri) {
    // b23.tv 在移动端可能落到 bilibili:// deep link，需要按 App 路由解析。
    if (uri.scheme.toLowerCase() == 'bilibili') {
      return _normalizeBilibiliAppUri(uri);
    }
    // 域名不在白名单中时拒绝解析，避免伪造 B 站链接。
    if (!_allowedHosts.contains(uri.host.toLowerCase())) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '链接不是受支持的哔哩哔哩域名。',
      );
    }
    // 从网页路径中提取 BV、AV、EP 或 SS，并保留普通视频的 p 参数。
    final target = _targetFromPath(
      uri.path,
      pageNumber: _pageNumberFromQuery(uri.queryParameters),
    );
    if (target == null) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: '链接中未找到 BV、AV、EP 或 SS 标识。',
      );
    }
    // 返回标准目标。
    return target;
  }

  /// 从 B 站 App deep link 中解析目标。
  BiliInputTarget _normalizeBilibiliAppUri(Uri uri) {
    // App 链接的 host 和 path 都可能承载 video、bangumi 或实际编号。
    final routeParts = <String>[
      if (uri.host.trim().isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];
    final routeText = routeParts.join('/');
    // 先从路径里找带前缀的 BV、AV、EP、SS。
    final pathTarget = _targetFromPath(
      routeText,
      pageNumber: _pageNumberFromQuery(uri.queryParameters),
    );
    if (pathTarget != null) return pathTarget;
    // 查询参数大小写不稳定，统一转小写后再读取。
    final query = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value,
    };
    // BVID 查询参数常见于 App 内部跳转。
    final bvid = query['bvid']?.trim();
    if (bvid != null && bvid.isNotEmpty) {
      final match = _bvidPattern.firstMatch(bvid);
      if (match != null) {
        return BiliInputTarget.bvid(
          'BV${bvid.substring(2)}',
          pageNumber: _pageNumberFromQuery(query),
        );
      }
    }
    // aid 或 avid 查询参数对应旧 AV 稿件号。
    final aid = query['aid'] ?? query['avid'];
    final aidTarget = _targetFromNumericText(
      aid,
      BiliInputKind.avid,
      errorMessage: 'AV 编号必须大于零。',
    );
    if (aidTarget != null) return aidTarget;
    // ep_id 或 epid 查询参数对应番剧分集。
    final episodeId = query['ep_id'] ?? query['epid'];
    final episodeTarget = _targetFromNumericText(
      episodeId,
      BiliInputKind.episode,
      errorMessage: 'EP 或 SS 编号必须大于零。',
    );
    if (episodeTarget != null) return episodeTarget;
    // season_id 或 seasonid 查询参数对应番剧季度。
    final seasonId = query['season_id'] ?? query['seasonid'];
    final seasonTarget = _targetFromNumericText(
      seasonId,
      BiliInputKind.season,
      errorMessage: 'EP 或 SS 编号必须大于零。',
    );
    if (seasonTarget != null) return seasonTarget;
    // bilibili://video/123 这类无前缀数字只在 App video 路由下视为 AV。
    if (routeParts.length >= 2 && routeParts.first.toLowerCase() == 'video') {
      final routeTarget = _targetFromNumericText(
        routeParts[1],
        BiliInputKind.avid,
        errorMessage: 'AV 编号必须大于零。',
      );
      if (routeTarget != null) return routeTarget;
    }
    // bilibili://bangumi/season/123 这类无前缀数字只在 season 路由下视为 SS。
    final seasonRouteIndex = routeParts.indexWhere(
      (String part) => part.toLowerCase() == 'season',
    );
    if (seasonRouteIndex >= 0 && seasonRouteIndex + 1 < routeParts.length) {
      final routeTarget = _targetFromNumericText(
        routeParts[seasonRouteIndex + 1],
        BiliInputKind.season,
        errorMessage: 'EP 或 SS 编号必须大于零。',
      );
      if (routeTarget != null) return routeTarget;
    }
    // App 链接可识别但没有目标编号时给出更准确的错误。
    throw const BiliApiException(
      kind: BiliApiErrorKind.invalidInput,
      message: 'B 站 App 分享链接中未找到 BV、AV、EP 或 SS 标识。',
    );
  }

  /// 从 URL 路径提取受支持标识。
  BiliInputTarget? _targetFromPath(String path, {int? pageNumber}) {
    // 在路径中查找第一个标准标识。
    final match = _pathIdentifierPattern.firstMatch(path);
    if (match == null) return null;
    final value = match.group(1)!;
    // BV 使用字符串字段创建目标，保留大小写主体。
    final bvidMatch = _bvidPattern.firstMatch(value);
    if (bvidMatch != null) {
      final bvid = bvidMatch.group(1)!;
      return BiliInputTarget.bvid(
        'BV${bvid.substring(2)}',
        pageNumber: pageNumber,
      );
    }
    // AV 使用数字字段创建目标，后续 view 接口用 aid 查询。
    final avidMatch = _avidPattern.firstMatch(value);
    if (avidMatch != null) return _targetFromAvidMatch(avidMatch);
    // 路径正则已经保证 EP/SS 格式有效。
    return _targetFromSeasonMatch(_seasonPattern.firstMatch(value)!);
  }

  /// 从普通文本提取独立标识，避免用户输入“BV号：BV...”时被当成 URL。
  BiliInputTarget? _targetFromLooseText(String text) {
    final match = _looseIdentifierPattern.firstMatch(text);
    if (match == null) return null;
    // 第二组才是实际标识，第一组只是边界字符。
    return _targetFromPath(match.group(2)!);
  }

  /// 将解析页裸数字输入转换为 AV 稿件号。
  BiliInputTarget? _targetFromDirectAvidNumber(String text) {
    final value = text.trim();
    if (!_directAvidNumberPattern.hasMatch(value)) return null;
    return _targetFromNumericText(
      value,
      BiliInputKind.avid,
      errorMessage: 'AV 编号必须大于零。',
    );
  }

  /// 从查询参数读取普通视频分 P 编号。
  int? _pageNumberFromQuery(Map<String, String> query) {
    // B 站网页和 App 链接通常使用 p 标记当前分 P，缺失时保持普通 BV 选择逻辑。
    final rawPage = query['p'] ?? query['page'];
    if (rawPage == null ||
        rawPage.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(rawPage)) {
      return null;
    }
    // 只有正数才代表有效分 P；0 和负数等异常值不参与默认选择。
    final pageNumber = int.parse(rawPage);
    if (pageNumber <= 0) return null;
    return pageNumber;
  }

  /// 将 AV 正则结果转换为旧稿件号目标。
  BiliInputTarget _targetFromAvidMatch(RegExpMatch match) {
    // 解析 av 后面的数字稿件 ID。
    final numericId = int.parse(match.group(2)!);
    // B 站稿件 ID 必须大于零，零值通常来自无效或占位输入。
    if (numericId <= 0) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: 'AV 编号必须大于零。',
      );
    }
    // 按数字目标保存，解析层使用 aid 参数请求普通视频信息。
    return BiliInputTarget.numeric(BiliInputKind.avid, numericId);
  }

  /// 把纯数字文本转换成指定数字目标，格式不匹配时返回空。
  BiliInputTarget? _targetFromNumericText(
    String? rawValue,
    BiliInputKind kind, {
    required String errorMessage,
  }) {
    // 只有 App 路由或查询参数里的纯数字才会走这里，普通用户输入仍不接受裸数字。
    final value = rawValue?.trim();
    if (value == null || value.isEmpty || !RegExp(r'^\d+$').hasMatch(value)) {
      return null;
    }
    // 数字 ID 必须大于零，零值通常代表无效占位。
    final numericId = int.parse(value);
    if (numericId <= 0) {
      throw BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: errorMessage,
      );
    }
    // 返回对应 AV、EP 或 SS 标准目标。
    return BiliInputTarget.numeric(kind, numericId);
  }

  /// 将 EP/SS 正则结果转换为数字目标。
  BiliInputTarget _targetFromSeasonMatch(RegExpMatch match) {
    // 解析 EP 或 SS 前缀和数字部分。
    final prefix = match.group(1)!.toLowerCase();
    final numericId = int.parse(match.group(2)!);
    // 数字 ID 必须大于零。
    if (numericId <= 0) {
      throw const BiliApiException(
        kind: BiliApiErrorKind.invalidInput,
        message: 'EP 或 SS 编号必须大于零。',
      );
    }
    // 按前缀创建对应目标。
    return BiliInputTarget.numeric(
      prefix == 'ep' ? BiliInputKind.episode : BiliInputKind.season,
      numericId,
    );
  }
}
