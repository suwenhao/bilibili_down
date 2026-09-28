part of '../up_user_page.dart';

/// 生成视频稳定键。
String _videoIdentity(BiliUserVideoItem item) {
  final bvid = item.bvid?.trim();
  if (item.source == BiliUserVideoSource.episode) {
    final cid = item.targetCid;
    if (bvid != null && bvid.isNotEmpty && cid != null && cid > 0) {
      return 'bv:$bvid:cid:$cid';
    }
    final pageNumber = item.targetPageNumber;
    if (bvid != null && bvid.isNotEmpty && pageNumber != null) {
      return 'bv:$bvid:p:$pageNumber';
    }
  }
  if (bvid != null && bvid.isNotEmpty) return 'bv:$bvid';
  final aid = item.aid;
  if (aid != null && aid > 0) return 'av:$aid';
  return 'title:${item.title}|${item.duration.inSeconds}';
}
