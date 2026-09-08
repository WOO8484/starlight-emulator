# ============================================================================
# Starlight: PPSSPP 정적 라이브러리 타깃 (CMakeLists.txt 끝에 append)
#
# 원본 라인 수정 없이 파일 끝에 이 블록만 추가한다(가장 얕은 변경).
# ${NativeAppSource} / ${targetExtra} / ${targetExtraLibs} 는 루트 CMakeLists 에서 채워진 변수.
#
# 핵심: ios/main.mm 은 int main() 뿐 아니라 대부분의 System_*() 플랫폼 구현을 함께 담고 있고,
#       copyDeepLinkForPath() 는 ios/AppDelegate.mm 에 있다. 따라서 두 파일을 제외하면 링크 시
#       System_*/copyDeepLinkForPath 가 undefined 가 된다.
#       → 두 파일을 모두 포함하되, main.mm 의 int main() 심볼만 per-file 매크로로 리네임하여
#         Host(SwiftUI @main)가 만드는 _main 과의 중복을 피한다(원본 소스 무편집).
# ============================================================================
if(IOS AND NOT TARGET PPSSPPCore)
    add_library(PPSSPPCore STATIC ${NativeAppSource} ${targetExtra})

    if(TARGET ppsspp_ui)
        target_link_libraries(PPSSPPCore PUBLIC ppsspp_ui ${CMAKE_THREAD_LIBS_INIT} ${targetExtraLibs})
    else()
        target_link_libraries(PPSSPPCore PUBLIC Core ${CMAKE_THREAD_LIBS_INIT} ${targetExtraLibs})
    endif()

    # PPSSPP 자체 int main() → ppsspp_ios_unused_main 으로 리네임(토큰 단위 치환).
    # System_* 구현은 그대로 유지되어 링크에 사용된다. main() 은 미사용 → dead-strip.
    set_source_files_properties("${CMAKE_SOURCE_DIR}/ios/main.mm" PROPERTIES
        COMPILE_DEFINITIONS "main=ppsspp_ios_unused_main")

    set_target_properties(PPSSPPCore PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/starlight")

    message(STATUS "Starlight: PPSSPPCore static library target added")
endif()
