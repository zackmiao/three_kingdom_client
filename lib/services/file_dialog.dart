import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Windows 原生「打开文件」对话框（comdlg32!GetOpenFileNameW）。
/// 不引入第三方插件；返回 null 表示用户取消。
class FileDialog {
  FileDialog._();

  static DynamicLibrary? _comdlg;

  static DynamicLibrary get _lib => _comdlg ??= DynamicLibrary.open('comdlg32.dll');

  /// [filter] 形如 `图片|*.png;*.jpg`，返回选中的文件绝对路径。
  static String? pickOpenFile({
    String title = '选择图片',
    String filterLabel = '图片',
    String pattern = '*.png;*.jpg;*.jpeg',
    String defaultExt = 'png',
  }) {
    if (!Platform.isWindows) return null;

    // OPENFILENAMEW（Win64）共 144 字节
    const int structSize = 144;
    final buffer = calloc<Uint8>(160);
    final fileName = calloc<Uint16>(1024);
    // 过滤器必须以「标签\0通配符\0\0」结尾
    final filterPtr = '$filterLabel\u0000$pattern\u0000\u0000'.toNativeUtf16();
    final titlePtr = title.toNativeUtf16();
    final defExtPtr = defaultExt.toNativeUtf16();

    try {
      buffer.cast<Uint32>().value = structSize; // lStructSize
      _writePtr(buffer, 8, 0); // hwndOwner
      _writePtr(buffer, 16, 0); // hInstance
      _writePtr(buffer, 24, filterPtr.address); // lpstrFilter
      _writePtr(buffer, 32, 0); // lpstrCustomFilter
      (buffer.cast<Uint32>() + 10).value = 0; // nMaxCustFilter
      (buffer.cast<Uint32>() + 11).value = 1; // nFilterIndex
      _writePtr(buffer, 48, fileName.address); // lpstrFile
      (buffer.cast<Uint32>() + 14).value = 1024; // nMaxFile
      (buffer.cast<Uint32>() + 15).value = 0; // nMaxFileTitle
      _writePtr(buffer, 64, 0); // lpstrFileTitle
      _writePtr(buffer, 72, 0); // lpstrInitialDir
      _writePtr(buffer, 80, titlePtr.address); // lpstrTitle
      // OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR | OFN_EXPLORER
      (buffer.cast<Uint32>() + 22).value =
          0x00001000 | 0x00000800 | 0x00000008 | 0x00080000;
      (buffer.cast<Uint32>() + 23).value = 0; // nFileOffset + nFileExtension
      _writePtr(buffer, 96, defExtPtr.address); // lpstrDefExt

      final getOpenFileName = _lib.lookupFunction<Int32 Function(Pointer<Uint8>),
          int Function(Pointer<Uint8>)>('GetOpenFileNameW');
      if (getOpenFileName(buffer) == 0) return null;

      final path = fileName.cast<Utf16>().toDartString();
      return path.isEmpty ? null : path;
    } finally {
      calloc.free(buffer);
      calloc.free(fileName);
      calloc.free(filterPtr);
      calloc.free(titlePtr);
      calloc.free(defExtPtr);
    }
  }

  static void _writePtr(Pointer<Uint8> base, int offset, int address) {
    Pointer<Uint64>.fromAddress(base.address + offset).value = address;
  }
}
