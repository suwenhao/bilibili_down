import 'package:bilibili_down/features/parser/presentation/widgets/episode_selection.dart';
import 'package:bilibili_down/services/bilibili/models/bili_media_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 验证大合集只构建视口附近卡片，防止恢复为 shrinkWrap 全量布局。
  testWidgets('分集 SliverGrid 对大合集保持懒加载', (WidgetTester tester) async {
    // 一千集足以区分 Sliver 懒加载与旧 GridView shrinkWrap 全量构建行为。
    final episodes = List<BiliEpisodeInfo>.generate(
      1000,
      (int index) => BiliEpisodeInfo(
        contentType: BiliContentType.ugc,
        bvid: 'BV-lazy',
        cid: index + 1,
        index: index,
        title: '第 $index 集',
        duration: const Duration(minutes: 1),
      ),
      growable: false,
    );

    // EpisodeGrid 必须作为 CustomScrollView 的 Sliver 使用，与解析页结构一致。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              EpisodeGrid(
                episodes: episodes,
                singleEpisodeTitle: null,
                selectedIndexes: const <int>{0},
                interactionLocked: false,
                onToggle: (int index) {
                  // 测试只验证构建数量，不改变选择状态。
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 当前测试视口只应构建少量复选框，不能一次创建全部一千张卡片。
    final builtCheckboxCount = find.byType(Checkbox).evaluate().length;
    expect(builtCheckboxCount, greaterThan(0));
    expect(builtCheckboxCount, lessThan(1000));
  });
}
