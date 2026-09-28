import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/downloads/presentation/download_custom_batch_page.dart';
import '../features/downloads/presentation/download_task_detail_page.dart';
import '../features/downloads/presentation/download_tasks_page.dart';
import '../features/downloads/presentation/models/download_custom_batch_result.dart';
import '../features/parser/presentation/parse_history_page.dart';
import '../features/parser/presentation/parser_page.dart';
import '../features/parser/presentation/up_user_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/legal_document_page.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/user/presentation/user_center_page.dart';
import '../core/legal/legal_information_dialogs.dart';

/// 提供应用级声明式路由。
final appRouterProvider = Provider<GoRouter>((Ref ref) {
  // ShellRoute 让解析、任务和设置共享响应式导航外壳。
  final router = GoRouter(
    initialLocation: '/parse',
    routes: <RouteBase>[
      // 三个一级页面使用独立 Navigator 并由 IndexedStack 承载；菜单切换时页面只隐藏，
      // 因此任务页签、列表滚动、解析输入和设置滚动位置都不会被销毁。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // 外壳直接读取分支索引并展示当前分支，不再根据路径重建页面。
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/parse',
                pageBuilder: (context, state) {
                  // 解析分支首次进入时创建页面，离开后由 IndexedStack 保留状态。
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: const _OpaqueRouteContent(child: ParserPage()),
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'history',
                    pageBuilder: (context, state) {
                      // 解析历史是解析分支内的二级页面，需要保留平台默认 push 动画。
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: const _OpaqueRouteContent(
                          child: ParseHistoryPage(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'up/:mid',
                    redirect: (context, state) {
                      // UP 二级页需要有效 UID，外部错误直达时回到解析页。
                      final mid = int.tryParse(
                        state.pathParameters['mid'] ?? '',
                      );
                      return mid == null || mid <= 0 ? '/parse' : null;
                    },
                    pageBuilder: (context, state) {
                      // UP 页是解析分支二级页面，手机端保留 Shell 底部导航。
                      final mid = int.parse(state.pathParameters['mid']!);
                      final extra = state.extra is UpUserPageArguments
                          ? state.extra as UpUserPageArguments
                          : null;
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: _OpaqueRouteContent(
                          child: UpUserPage(mid: mid, name: extra?.name),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/tasks',
                pageBuilder: (context, state) {
                  // 任务分支保留本地筛选页签、操作状态和 Scrollable 位置。
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: const _OpaqueRouteContent(
                      child: DownloadTasksPage(),
                    ),
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'custom-batch',
                    redirect: (context, state) {
                      // 自定义批量页只能从任务页带参数进入，外部直达时回到任务页。
                      return state.extra is DownloadCustomBatchPageArguments
                          ? null
                          : '/tasks';
                    },
                    pageBuilder: (context, state) {
                      // 手机端自定义批量是任务分支二级页，需要保留 Shell 底部导航。
                      final arguments =
                          state.extra as DownloadCustomBatchPageArguments;
                      return MaterialPage<DownloadCustomBatchResult>(
                        key: state.pageKey,
                        child: _OpaqueRouteContent(
                          child: DownloadCustomBatchPage(
                            taskCount: arguments.taskCount,
                            availableResources: arguments.availableResources,
                            initialAudioQuality: arguments.initialAudioQuality,
                            initialVideoQuality: arguments.initialVideoQuality,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':taskId',
                    redirect: (context, state) {
                      // 任务详情需要有效任务 ID，外部空参数直达时回到任务列表。
                      final taskId = state.pathParameters['taskId'];
                      return taskId == null || taskId.isEmpty ? '/tasks' : null;
                    },
                    pageBuilder: (context, state) {
                      // 已下载详情是任务分支二级页，路径保持 /tasks/:taskId。
                      final taskId = Uri.decodeComponent(
                        state.pathParameters['taskId']!,
                      );
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: _OpaqueRouteContent(
                          child: DownloadTaskDetailPage(taskId: taskId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) {
                  // 设置分支同样禁用转场，并在其他分支显示时保留滚动位置。
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: const _OpaqueRouteContent(child: SettingsPage()),
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'copyright-usage',
                    pageBuilder: (context, state) {
                      // 版权说明作为设置分支子页面展示，桌面端保留左侧导航。
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: const _OpaqueRouteContent(
                          child: SettingsLegalDocumentPage(
                            document: copyrightUsageLegalDocument,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/user-center',
                pageBuilder: (context, state) {
                  // 桌面端账号中心作为侧栏分支显示在右侧内容区，保留侧栏和其他页面状态。
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: const _OpaqueRouteContent(
                      child: UserCenterPage(embedded: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/user',
        pageBuilder: (context, state) {
          // 用户中心由登录头像入口进入，作为一级页面上方的独立页面承载返回行为。
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: const _OpaqueRouteContent(child: UserCenterPage()),
          );
        },
      ),
    ],
  );
  // Provider 销毁时释放路由监听器。
  ref.onDispose(router.dispose);
  // 返回完成配置的路由实例。
  return router;
});

/// 为内层页面路由提供覆盖全窗口的不透明命中区域。
final class _OpaqueRouteContent extends StatelessWidget {
  /// 创建不会改变视觉布局的页面点击承载层。
  const _OpaqueRouteContent({required this.child});

  /// 当前一级路由实际展示的页面。
  final Widget child;

  /// 使用主题背景吸收页面空白点击，避免事件落到当前路由的 ModalBarrier。
  @override
  Widget build(BuildContext context) {
    // ColoredBox 使用 opaque 命中行为，颜色与 Scaffold 背景完全一致。
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
