# ============================================================================
# Starlight: PPSSPP 정적 라이브러리 타깃 (CMakeLists.txt 끝에 append)
#
# 원본 라인을 수정하지 않고 파일 끝에 이 블록만 추가한다(가장 얕은 변경).
# ${NativeAppSource} / ${targetExtra} / ${targetExtraLibs} 는 루트 CMakeLists 에서
# 이미 채워진 변수이며 디렉토리 스코프에 유지되므로 파일 끝에서 재사용 가능하다.
#
# 앱 진입부(ios/main.mm=UIApplicationMain, ios/AppDelegate.mm)만 제외하여,
# NativeApp + PPSSPPViewControllerMetal(렌더) 를 포함하는 임베드용 정적 라이브러리를 만든다.
# (지시문 2·7항: 원본 렌더 경로를 재구현하지 않고 그대로 재사용)
# ============================================================================
if(IOS AND NOT TARGET PPSSPPCore)
    set(_sl_core_sources ${NativeAppSource})
    set(_sl_ios_glue ${targetExtra})
    list(FILTER _sl_ios_glue EXCLUDE REGEX "ios/main\\.mm$")
    list(FILTER _sl_ios_glue EXCLUDE REGEX "ios/AppDelegate\\.mm$")

    add_library(PPSSPPCore STATIC ${_sl_core_sources} ${_sl_ios_glue})

    if(TARGET ppsspp_ui)
        target_link_libraries(PPSSPPCore PUBLIC ppsspp_ui ${CMAKE_THREAD_LIBS_INIT} ${targetExtraLibs})
    else()
        target_link_libraries(PPSSPPCore PUBLIC Core ${CMAKE_THREAD_LIBS_INIT} ${targetExtraLibs})
    endif()

    set_target_properties(PPSSPPCore PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/starlight"
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")

    message(STATUS "Starlight: PPSSPPCore static library target added")
endif()
