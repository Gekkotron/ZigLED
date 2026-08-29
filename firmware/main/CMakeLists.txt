idf_component_register(
    SRCS "main.c" "esp_zb_endpoint.c" "lock_shim.c" "sensor.c"
    INCLUDE_DIRS "."
    REQUIRES nvs_flash esp_driver_gpio esp_driver_rmt esp_timer log espressif__led_strip espressif__esp-zigbee-lib espressif__esp-zboss-lib
)

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    set(ZIG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../zig)
    set(ZIG_LIB ${ZIG_DIR}/zig-out/lib/libzigled.a)

    file(GLOB_RECURSE ZIG_SRC CONFIGURE_DEPENDS
        "${ZIG_DIR}/build.zig"
        "${ZIG_DIR}/build.zig.zon"
        "${ZIG_DIR}/src/*.zig"
        "${ZIG_DIR}/tests/*.zig"
    )

    add_custom_command(
        OUTPUT ${ZIG_LIB}
        COMMAND zig build --prefix ${ZIG_DIR}/zig-out -Didf-build-dir=${CMAKE_BINARY_DIR}
        WORKING_DIRECTORY ${ZIG_DIR}
        DEPENDS ${ZIG_SRC}
        COMMENT "Building Zig library"
        VERBATIM
    )
    add_custom_target(zig_build DEPENDS ${ZIG_LIB})

    add_dependencies(${COMPONENT_LIB} zig_build)

    # ${ZIG_LIB} is a plain file path, not a CMake target, so linking it in
    # directly (as in Task 2-13) leaves it outside the REQUIRES dependency
    # graph that ESP-IDF's own link-line generation walks (and repeats,
    # since ESP-IDF's components can be mutually circular) to resolve
    # cross-component symbols. That left led_strip's (and transitively
    # esp_driver_rmt's) symbols undefined: nothing placed a copy of those
    # archives late enough in the link for the Zig code's references into
    # them to resolve. Wrapping the Zig archive in a real IMPORTED CMake
    # target and declaring its actual dependency on `idf::espressif__led_strip`
    # puts it on that same graph, so ESP-IDF's link-line generation carries
    # it (and everything led_strip itself needs) along correctly.
    add_library(zigled_lib STATIC IMPORTED)
    set_target_properties(zigled_lib PROPERTIES IMPORTED_LOCATION ${ZIG_LIB})
    add_dependencies(zigled_lib zig_build)
    target_link_libraries(zigled_lib INTERFACE idf::espressif__led_strip)

    target_link_libraries(${COMPONENT_LIB} PRIVATE zigled_lib)

    # zigbee_iface.zig's CommandQueue lock calls into lock_shim.c's
    # zigled_queue_lock/unlock, which live in this same `main` component's
    # own archive (libmain.a). Since libmain.a is placed on the link line
    # before zigled_lib (the PRIVATE dependency added above), and nothing
    # in libmain.a is referenced yet at the point the linker first scans
    # it, lock_shim.c's object is never pulled from the archive and the
    # symbols come up undefined when zigled_lib is processed afterward.
    # Declaring the reverse edge here — same pattern as the led_strip
    # dependency above — puts `main` and `zigled_lib` in a cycle that
    # ESP-IDF's link-line generation repeats on the link line, so the
    # second pass resolves it.
    target_link_libraries(zigled_lib INTERFACE idf::main)
endif()
