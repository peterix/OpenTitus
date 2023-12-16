add_library(opl STATIC
    src/opl_internal.h
    src/opl.c
    src/opl_linux.c
    src/opl_obsd.c
    src/opl_queue.c
    src/opl_sdl.c
    src/opl_timer.c
    src/opl_win32.c
    src/ioperm_sys.c
    src/opl3.c

    include/opl/opl.h
    include/opl/opl_queue.h
    include/opl/opl_timer.h
    include/opl/ioperm_sys.h
    include/opl/opl3.h
)

target_include_directories(opl
    INTERFACE "include"
    PRIVATE "src"
)

target_link_libraries(opl SDL2::mixer)
