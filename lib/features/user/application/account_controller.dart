import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_debug_log.dart';
import '../../../services/bilibili/bili_api_exception.dart';
import '../../../services/bilibili/bili_auth_service.dart';
import '../../../services/bilibili/bilibili_providers.dart';
import '../../../services/bilibili/models/bili_auth_models.dart';
import '../../downloads/application/maintenance/pending_dash_option_downgrade_service.dart';
import '../../downloads/application/maintenance/pending_dash_option_refresh_service.dart';
import '../../settings/application/app_settings_controller.dart';
import 'bili_session_invalidation_controller.dart';

/// 提供账号资料和二维码登录流程状态。
final accountControllerProvider =
    NotifierProvider<AccountController, AccountState>(AccountController.new);

/// 账号页面当前阶段。
enum AccountPhase {
  /// 正在校验本地 Cookie。
  checking,

  /// 未登录且未开始扫码。
  loggedOut,

  /// 正在请求二维码。
  generatingQr,

  /// 二维码已生成并正在轮询。
  waitingQr,

  /// 已登录并拥有账号资料。
  loggedIn,

  /// 网络或接口发生错误。
  failed,
}

/// 账号页面不可变状态。
final class AccountState {
  /// 创建账号状态快照。
  const AccountState({
    required this.phase,
    this.profile,
    this.qrRequest,
    this.qrPollResult,
    this.errorMessage,
    this.autoCloseOnLoggedIn = false,
    this.showQrCodeOnMobile = false,
  });

  /// 当前账号流程阶段。
  final AccountPhase phase;

  /// 登录成功后的账号资料。
  final BiliLoginProfile? profile;

  /// 当前二维码请求。
  final BiliQrLoginRequest? qrRequest;

  /// 最近一次扫码轮询状态。
  final BiliQrLoginPollResult? qrPollResult;

  /// 页面错误说明。
  final String? errorMessage;

  /// 本次状态进入已登录后是否需要自动关闭账号弹窗。
  final bool autoCloseOnLoggedIn;

  /// 手机端本次二维码流程是否强制展示二维码而不是自动拉起 App。
  final bool showQrCodeOnMobile;
}

/// 管理登录状态检查、二维码轮询、取消和本地退出。
final class AccountController extends Notifier<AccountState> {
  /// 当前二维码网络取消令牌。
  CancelToken? _qrCancelToken;

  /// 读取应用级登录服务。
  BiliAuthService get _authService => ref.read(biliAuthServiceProvider);

  /// 创建检查中状态并安排首次 Cookie 校验。
  @override
  AccountState build() {
    // Cookie 失效只让账号回落游客权限，解析、下载和任务记录继续独立运行。
    ref.listen<int>(biliSessionInvalidationControllerProvider, (
      int? previous,
      int next,
    ) {
      // 初始监听不触发；修订号变化代表网络层已清除一份失效会话。
      if (previous != null && next != previous) _handleSessionInvalidated();
    });
    // Provider 销毁时停止二维码生成或轮询请求。
    ref.onDispose(() {
      // 取消仍在执行的网络请求和后续轮询。
      _qrCancelToken?.cancel('账号页面已关闭');
    });
    // 延后到 build 完成后再写入状态，避免在构建期间修改 Notifier。
    Future<void>.microtask(() => refreshProfile());
    // 首帧显示登录状态检查进度。
    return const AccountState(phase: AccountPhase.checking);
  }

  /// 将已经失效的账号状态降级为游客，但不干预正在进行的扫码流程。
  void _handleSessionInvalidated() {
    // 扫码登录使用独立的一次性会话，旧 Cookie 失效不能取消用户当前扫码。
    if (state.phase == AccountPhase.generatingQr ||
        state.phase == AccountPhase.waitingQr) {
      AppDebugLog.account('Session invalidated ignored during qr flow');
      return;
    }
    AppDebugLog.account('Session invalidated; downgraded to loggedOut');
    // 清除界面中的旧账号资料，高音画质入口随账号状态立即关闭。
    state = const AccountState(phase: AccountPhase.loggedOut);
    // Cookie 失效属于被动退出，异步裁剪待下载候选以避免阻塞网络错误恢复。
    unawaited(_applyLoggedOutDownloadDefaults());
  }

  /// 校验安全存储中的 Cookie 并加载账号资料。
  Future<void> refreshProfile({
    bool refreshQueuedTasksOnLoggedIn = false,
    bool autoCloseOnLoggedIn = false,
  }) async {
    // 状态检查开始时保留已知资料，避免刷新时头像闪烁。
    AppDebugLog.account('Profile refresh started');
    state = AccountState(
      phase: AccountPhase.checking,
      profile: state.profile,
      autoCloseOnLoggedIn: autoCloseOnLoggedIn,
    );
    try {
      // 调用 nav 接口验证当前会话。
      final profile = await _authService.checkLogin();
      // 根据服务返回布尔值进入已登录或未登录页面。
      state = AccountState(
        phase: profile.isLoggedIn
            ? AccountPhase.loggedIn
            : AccountPhase.loggedOut,
        profile: profile.isLoggedIn ? profile : null,
        autoCloseOnLoggedIn: profile.isLoggedIn && autoCloseOnLoggedIn,
      );
      // 首次确认账号状态时同步该登录级别对应的默认音画质。
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAccountQualityDefaults(isLoggedIn: profile.isLoggedIn);
      if (profile.isLoggedIn && refreshQueuedTasksOnLoggedIn) {
        // 扫码登录成功后使用新账号权限重新解析待下载候选，恢复登录可用档位。
        final refreshedTasks = await ref
            .read(pendingDashOptionRefreshServiceProvider)
            .refreshQueuedTasksAfterLogin();
        AppDebugLog.account(
          'Logged-in queued DASH refreshed tasks=$refreshedTasks',
        );
      }
      if (!profile.isLoggedIn) {
        // 启动时发现已是游客，也要清理上次登录留下的高权限待下载候选。
        await ref
            .read(pendingDashOptionDowngradeServiceProvider)
            .downgradeQueuedTasksForLoggedOut();
      }
      AppDebugLog.account(
        'Profile refresh completed loggedIn=${profile.isLoggedIn}',
      );
    } catch (error) {
      AppDebugLog.account('Profile refresh failed error=$error');
      if (_shouldLogoutAfterProfileRefreshError(error)) {
        AppDebugLog.account(
          'Profile refresh error treated as logout error=$error',
        );
        // 登录检查拿到异常结构或未授权时，本地 Cookie 已不可继续信任，直接退出。
        await _logoutAfterInvalidProfileSession();
        return;
      }
      // 网络失败不清除安全存储，允许用户重试状态检查。
      state = AccountState(
        phase: AccountPhase.failed,
        profile: state.profile,
        errorMessage: error.toString(),
      );
    }
  }

  /// 生成二维码并持续轮询到成功、过期或取消。
  Future<void> startQrLogin({bool showQrCodeOnMobile = false}) async {
    // 取消旧二维码请求，确保只有一条轮询链运行。
    AppDebugLog.account(
      'QR login started showQrCodeOnMobile=$showQrCodeOnMobile',
    );
    _qrCancelToken?.cancel('重新生成二维码');
    // 为本次登录创建独立取消令牌。
    final cancelToken = CancelToken();
    _qrCancelToken = cancelToken;
    // 二维码生成期间显示明确进度。
    state = AccountState(
      phase: AccountPhase.generatingQr,
      showQrCodeOnMobile: showQrCodeOnMobile,
    );
    try {
      // 请求一次性二维码内容和轮询键。
      final request = await _authService.createQrLogin(
        cancelToken: cancelToken,
      );
      AppDebugLog.account('QR login code generated');
      // 先展示二维码和等待扫码初始状态。
      state = AccountState(
        phase: AccountPhase.waitingQr,
        qrRequest: request,
        qrPollResult: const BiliQrLoginPollResult(
          status: BiliQrLoginStatus.waitingForScan,
          message: '等待扫码中…',
        ),
        showQrCodeOnMobile: showQrCodeOnMobile,
      );
      // 按服务规定的间隔持续接收扫码状态。
      await for (final result in _authService.watchQrLogin(
        request,
        cancelToken: cancelToken,
      )) {
        // 已取消的旧轮询不能覆盖当前账号状态。
        if (cancelToken.isCancelled || _qrCancelToken != cancelToken) return;
        // 保存最新扫码状态供二维码卡片展示。
        state = AccountState(
          phase: AccountPhase.waitingQr,
          qrRequest: request,
          qrPollResult: result,
          showQrCodeOnMobile: showQrCodeOnMobile,
        );
        // 登录成功后立即校验 Cookie 并展示账号资料。
        if (result.status == BiliQrLoginStatus.success) {
          AppDebugLog.account('QR login succeeded');
          await refreshProfile(
            refreshQueuedTasksOnLoggedIn: true,
            autoCloseOnLoggedIn: true,
          );
          return;
        }
        // 二维码过期后停止等待，由用户点击刷新生成新二维码。
        if (result.status == BiliQrLoginStatus.expired) {
          AppDebugLog.account('QR login expired');
          return;
        }
      }
    } catch (error) {
      // 用户取消或页面销毁属于正常流程，不显示网络错误。
      if (cancelToken.isCancelled) {
        AppDebugLog.account('QR login cancelled');
        return;
      }
      AppDebugLog.account('QR login failed error=$error');
      // 生成或轮询失败时提供重试入口。
      state = AccountState(
        phase: AccountPhase.failed,
        errorMessage: error.toString(),
      );
    } finally {
      // 只清除仍属于本次流程的取消令牌。
      if (_qrCancelToken == cancelToken) _qrCancelToken = null;
    }
  }

  /// 取消当前扫码流程并回到未登录状态。
  void cancelQrLogin() {
    // 停止正在生成或轮询的网络请求。
    AppDebugLog.account('QR login cancelled by user');
    _qrCancelToken?.cancel('用户取消登录');
    // 清除二维码和错误，但不删除已有账号 Cookie。
    state = AccountState(
      phase: state.profile?.isLoggedIn == true
          ? AccountPhase.loggedIn
          : AccountPhase.loggedOut,
      profile: state.profile,
    );
  }

  /// 清除本地 Cookie 和刷新令牌并返回未登录状态。
  Future<void> logout() async {
    // 退出前停止可能仍在运行的二维码轮询。
    AppDebugLog.account('Logout started');
    _qrCancelToken?.cancel('用户退出登录');
    // 只清除当前设备保存的 Cookie 与刷新令牌，不注销 B 站账号的远端会话。
    await _authService.logout();
    // Cookie 清除后立即发布未登录状态；已下载文件和 Drift 任务不受退出影响。
    state = const AccountState(phase: AccountPhase.loggedOut);
    // 退出后同步回落设置和待下载 DASH 候选，避免继续显示或请求登录专属档位。
    await _applyLoggedOutDownloadDefaults();
    AppDebugLog.account('Logout completed locally');
  }

  /// 登录检查失败后按会话失效处理本地退出。
  Future<void> _logoutAfterInvalidProfileSession() async {
    // 只清理本地凭据和权限状态，不调用远端注销，避免异常响应期间继续请求 B 站。
    await _authService.logout();
    // 账号页立即回到游客入口，不向用户暴露底层 JSON 结构错误。
    state = const AccountState(phase: AccountPhase.loggedOut);
    // 登录状态降级后同步裁剪高权限下载候选。
    await _applyLoggedOutDownloadDefaults();
  }

  /// 应用游客默认质量并裁剪待下载任务里登录态留下的 DASH 候选。
  Future<void> _applyLoggedOutDownloadDefaults() async {
    // 先保存设置默认值，让新解析任务立即使用游客质量。
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setAccountQualityDefaults(isLoggedIn: false);
    // 再批量修正已经入库但尚未开始的任务候选和当前选择。
    final downgradedTasks = await ref
        .read(pendingDashOptionDowngradeServiceProvider)
        .downgradeQueuedTasksForLoggedOut();
    AppDebugLog.account(
      'Logged-out download defaults applied downgradedTasks=$downgradedTasks',
    );
  }
}

/// 判断账号资料刷新异常是否应当直接本地退出。
bool _shouldLogoutAfterProfileRefreshError(Object error) {
  // nav 或 cookie 刷新接口返回结构异常时，继续保留旧账号只会反复进入错误页。
  if (error is! BiliApiException) return false;
  return switch (error.kind) {
    BiliApiErrorKind.invalidResponse || BiliApiErrorKind.unauthorized => true,
    BiliApiErrorKind.invalidInput ||
    BiliApiErrorKind.network ||
    BiliApiErrorKind.forbidden ||
    BiliApiErrorKind.notFound ||
    BiliApiErrorKind.regionRestricted ||
    BiliApiErrorKind.api => false,
  };
}
