idf_component_register(
    SRCS "main.c"
    INCLUDE_DIRS "."
    REQUIRES nvs_flash esp_driver_gpio esp_driver_rmt log
)

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    set(ZIG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../zig)
    set(ZIG_LIB ${ZIG_DIR}/zig-out/lib/libzigled.a)

    add_custom_command(
        OUTPUT ${ZIG_LIB}
        COMMAND zig build --prefix ${ZIG_DIR}/zig-out
        WORKING_DIRECTORY ${ZIG_DIR}
        COMMENT "Building Zig library"
        VERBATIM
    )
    add_custom_target(zig_build DEPENDS ${ZIG_LIB})

    add_dependencies(${COMPONENT_LIB} zig_build)
    target_link_libraries(${COMPONENT_LIB} PRIVATE ${ZIG_LIB})
endif()
