import 'package:bilibili_down/services/bilibili/models/bili_media_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证 UGC 合集中的多 P 投稿会展开为真实分 P，而不是只显示合集投稿壳。
  test('展开 UGC 合集中的多 P 投稿', () {
    // view 接口里 ugc_season.sections[].episodes[] 是合集投稿，真实视频条目在 pages 里。
    final media = parseUgcMediaInfo(<String, Object?>{
      'bvid': 'BV16gckzzE6p',
      'title': '当前投稿标题',
      'pic': 'https://i.example/current.jpg',
      'pubdate': 1780000000,
      'owner': <String, Object?>{'mid': 42, 'name': '测试 UP'},
      'ugc_season': <String, Object?>{
        'title': 'Godot 4.5/6 2D 游戏开发',
        'cover': 'https://i.example/season.jpg',
        'sections': <Object?>[
          <String, Object?>{
            'title': '正片',
            'episodes': <Object?>[
              <String, Object?>{
                'bvid': 'BV16gckzzE6p',
                'cid': 1001,
                'title': '第一个合集投稿',
                'arc': <String, Object?>{
                  'title': '第一个合集投稿',
                  'pic': 'https://i.example/arc1.jpg',
                  'duration': 999,
                  'pubdate': 1780000001,
                },
                'pages': <Object?>[
                  <String, Object?>{
                    'cid': 1001,
                    'page': 1,
                    'part': 'A 1. 简介_dub',
                    'duration': 67,
                    'dimension': <String, Object?>{
                      'width': 1920,
                      'height': 1080,
                    },
                  },
                  <String, Object?>{
                    'cid': 1002,
                    'page': 2,
                    'part': 'A 2. 购买前必读！_dub',
                    'duration': 80,
                    'dimension': <String, Object?>{
                      'width': 1920,
                      'height': 1080,
                    },
                  },
                ],
              },
              <String, Object?>{
                'bvid': 'BV1DAwpziEEa',
                'cid': 2001,
                'title': '第二个合集投稿',
                'arc': <String, Object?>{
                  'title': '第二个合集投稿',
                  'pic': 'https://i.example/arc2.jpg',
                  'duration': 888,
                  'pubdate': 1780000002,
                },
                'pages': <Object?>[
                  <String, Object?>{
                    'cid': 2001,
                    'page': 1,
                    'part': 'L 164. 简介_dub',
                    'duration': 64,
                    'dimension': <String, Object?>{
                      'width': 1920,
                      'height': 1080,
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
    });

    expect(media.title, 'Godot 4.5/6 2D 游戏开发');
    expect(media.episodes, hasLength(3));
    expect(
      media.episodes.map((BiliEpisodeInfo episode) => episode.title),
      <String>['A 1. 简介_dub', 'A 2. 购买前必读！_dub', 'L 164. 简介_dub'],
    );
    expect(media.episodes[1].bvid, 'BV16gckzzE6p');
    expect(media.episodes[1].cid, 1002);
    expect(media.episodes[1].pageNumber, 2);
    expect(media.episodes[2].bvid, 'BV1DAwpziEEa');
    expect(media.episodes[2].pageNumber, 1);
  });
}
