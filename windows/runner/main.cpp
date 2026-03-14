#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>
#include <thread>
#include <chrono>

#include "flutter_window.h"
#include "utils.h"

std::wstring GetCommandLineFile() {
  int argc;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  std::wstring result;
  
  if (argc > 1) {
    std::wstring arg = argv[1];
    if (arg.length() > 5 && arg.substr(arg.length() - 5) == L".opus") {
      result = arg;
    }
  }
  
  LocalFree(argv);
  return result;
}

std::string WStringToString(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string result(size - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &result[0], size, nullptr, nullptr);
  return result;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"substitcher", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  std::wstring initial_file = GetCommandLineFile();
  if (!initial_file.empty()) {
    std::string file_path = WStringToString(initial_file);
    
    // Capture a pointer to the window to use in the thread
    FlutterWindow* window_ptr = &window;
    
    std::thread([file_path, window_ptr]() {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      
      auto controller = window_ptr->GetFlutterViewController();
      if (controller) {
        auto messenger = controller->engine()->messenger();
        if (messenger) {
          const flutter::StandardMethodCodec& codec = flutter::StandardMethodCodec::GetInstance();
          auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "com.substitcher/open_file", &codec);
          
          flutter::EncodableValue args(file_path);
          channel->InvokeMethod("openFile", std::make_unique<flutter::EncodableValue>(args));
        }
      }
    }).detach();
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}