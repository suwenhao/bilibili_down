#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* system_trash_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// 保存 Linux 后台回收站任务的路径副本和待回复方法调用。
typedef struct {
  // 方法调用保持引用直到主线程完成 Flutter 响应。
  FlMethodCall* method_call;
  // 路径数组拥有每个 UTF-8 字符串，后台线程不再访问 Flutter 参数对象。
  GPtrArray* paths;
} SystemTrashTaskData;

// 释放后台任务持有的方法调用和全部路径副本。
static void system_trash_task_data_free(gpointer user_data) {
  SystemTrashTaskData* data =
      static_cast<SystemTrashTaskData*>(user_data);
  g_clear_object(&data->method_call);
  g_clear_pointer(&data->paths, g_ptr_array_unref);
  g_free(data);
}

// 在线程池中执行 GIO 回收站操作，避免阻塞 GTK 和 Flutter 绘制线程。
static void system_trash_task_thread(GTask* task, gpointer source_object,
                                     gpointer task_data,
                                     GCancellable* cancellable) {
  // 当前任务不依赖源对象或取消令牌，显式忽略以保持编译警告清洁。
  (void)source_object;
  (void)cancellable;
  SystemTrashTaskData* data =
      static_cast<SystemTrashTaskData*>(task_data);
  for (guint index = 0; index < data->paths->len; index++) {
    // 路径已经在主线程完成类型和空值校验，工作线程只执行系统操作。
    const gchar* path =
        static_cast<const gchar*>(g_ptr_array_index(data->paths, index));
    g_autoptr(GFile) file = g_file_new_for_path(path);
    g_autoptr(GError) error = nullptr;
    if (!g_file_trash(file, nullptr, &error)) {
      // 把首个失败转交主线程，Dart 层将保留全部尚未清理的任务记录。
      g_task_return_error(task, g_steal_pointer(&error));
      return;
    }
  }
  // 全部路径处理完成后返回成功，完成回调会在创建任务的主上下文运行。
  g_task_return_boolean(task, TRUE);
}

// 回到 GTK 主线程响应 Flutter 平台通道，编码器不会被后台线程调用。
static void system_trash_task_complete(GObject* source_object,
                                       GAsyncResult* result,
                                       gpointer user_data) {
  // 当前完成回调的全部状态存放在 GTask 中，不使用额外上下文参数。
  (void)source_object;
  (void)user_data;
  GTask* task = G_TASK(result);
  SystemTrashTaskData* data = static_cast<SystemTrashTaskData*>(
      g_task_get_task_data(task));
  g_autoptr(GError) error = nullptr;
  if (!g_task_propagate_boolean(task, &error)) {
    // 系统错误只作为详情返回，界面会显示统一的用户可读处理建议。
    g_autoptr(FlValue) details = fl_value_new_string(error->message);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("trash_failed",
                                     "Linux 无法把下载文件移入回收站。",
                                     details));
    fl_method_call_respond(data->method_call, response, nullptr);
    return;
  }
  // 全部路径成功进入 Trash 后，Dart 层才会继续清理任务数据库记录。
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  fl_method_call_respond(data->method_call, response, nullptr);
}

// 将 Dart 传入的用户下载成品异步移动到当前 Linux 桌面环境的 Trash。
static void system_trash_method_call_cb(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  // 当前处理器不需要通道实例和用户数据，显式忽略以满足 Runner 的警告即错误规则。
  (void)channel;
  (void)user_data;
  const gchar* method = fl_method_call_get_name(method_call);
  // 平台通道只暴露回收站操作，不提供任意永久删除入口。
  if (g_strcmp0(method, "movePathsToTrash") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue* arguments = fl_method_call_get_args(method_call);
  // 参数根节点只有 Map 才能读取 paths，其他类型统一按无效参数处理。
  FlValue* paths = nullptr;
  if (arguments != nullptr &&
      fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP) {
    paths = fl_value_lookup_string(arguments, "paths");
  }
  // 参数必须是至少包含一个 UTF-8 路径的列表。
  if (paths == nullptr || fl_value_get_type(paths) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(paths) == 0) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("invalid_arguments",
                                     "文件路径列表不能为空。", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  // 工作线程不能继续读取 Flutter 参数对象，先在主线程复制并拥有全部路径。
  GPtrArray* path_copies = g_ptr_array_new_with_free_func(g_free);
  for (size_t index = 0; index < fl_value_get_length(paths); index++) {
    FlValue* path_value = fl_value_get_list_value(paths, index);
    if (fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
      g_ptr_array_unref(path_copies);
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("invalid_arguments",
                                       "文件路径格式错误。", nullptr));
      fl_method_call_respond(method_call, response, nullptr);
      return;
    }
    const gchar* path = fl_value_get_string(path_value);
    if (path == nullptr || path[0] == '\0') {
      g_ptr_array_unref(path_copies);
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("invalid_arguments",
                                       "文件路径不能为空。", nullptr));
      fl_method_call_respond(method_call, response, nullptr);
      return;
    }
    // 每个副本由数组释放函数管理，后台完成或失败都不会泄漏。
    g_ptr_array_add(path_copies, g_strdup(path));
  }
  // 任务数据持有方法调用引用，窗口退出或异步完成前对象都保持有效。
  SystemTrashTaskData* task_data = g_new0(SystemTrashTaskData, 1);
  task_data->method_call =
      FL_METHOD_CALL(g_object_ref(G_OBJECT(method_call)));
  task_data->paths = path_copies;
  // GTask 自动把完成回调派发回当前 GTK 主上下文。
  g_autoptr(GTask) task =
      g_task_new(nullptr, nullptr, system_trash_task_complete, nullptr);
  g_task_set_task_data(task, task_data, system_trash_task_data_free);
  g_task_run_in_thread(task, system_trash_task_thread);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "BiliDown");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "BiliDown");
  }

  // Linux 首次启动与其他桌面平台保持相同的默认窗口尺寸。
  gtk_window_set_default_size(window, 920, 640);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // 注册系统回收站通道，避免用户成品通过 dart:io 被直接永久删除。
  g_autoptr(FlStandardMethodCodec) trash_codec =
      fl_standard_method_codec_new();
  self->system_trash_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "bilidown/system_trash", FL_METHOD_CODEC(trash_codec));
  fl_method_channel_set_method_call_handler(
      self->system_trash_channel, system_trash_method_call_cb, nullptr,
      nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  // 与 Flutter 引擎窗口同时释放回收站通道，避免退出后保留消息处理器。
  g_clear_object(&self->system_trash_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
