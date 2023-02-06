load("@local_config_tf//:build_defs.bzl", "CPLUSPLUS_VERSION", "D_GLIBCXX_USE_CXX11_ABI")
load("@local_config_cuda//cuda:build_defs.bzl", "if_cuda", "if_cuda_is_configured")
load("@local_config_rocm//rocm:build_defs.bzl", "if_rocm", "if_rocm_is_configured")

def custom_op_library(
        name,
        srcs = [],
        gpu_srcs = [],
        deps = [],
        gpu_deps = None,
        copts = [],
        **kwargs):
    deps = deps + [
        "@local_config_tf//:libtensorflow_framework",
        "@local_config_tf//:tf_header_lib",
    ]

    if not gpu_deps:
        gpu_deps = []

    if gpu_srcs:
        copts = copts + if_cuda(["-DGOOGLE_CUDA=1"])
        copts = copts + if_rocm(["-DTENSORFLOW_USE_ROCM=1"])
        gpu_copts = copts + if_cuda_is_configured([
            "-x cuda",
            "-nvcc_options=relaxed-constexpr",
            "-nvcc_options=ftz=true",
        ])
        gpu_deps = gpu_deps + if_cuda_is_configured([
            "@local_config_cuda//cuda:cuda_headers",
            "@local_config_cuda//cuda:cudart_static",
        ])
        basename = name.split(".")[0]
        native.cc_library(
            name = basename + "_gpu",
            srcs = gpu_srcs,
            deps = gpu_deps,
            copts = gpu_copts,
            alwayslink = 1,
            **kwargs
        )
        deps = deps + [":" + basename + "_gpu"]

    copts = copts + select({
    copts = copts + select({
        "//tensorflow_addons:windows": [
            "/DEIGEN_STRONG_INLINE=inline",
            "-DTENSORFLOW_MONOLITHIC_BUILD",
            "/D_USE_MATH_DEFINES",
            "/DPLATFORM_WINDOWS",
            "/DEIGEN_HAS_C99_MATH",
            "/DTENSORFLOW_USE_EIGEN_THREADPOOL",
            "/DEIGEN_AVOID_STL_ARRAY",
            "/Iexternal/gemmlowp",
            "/wd4018",
            "/wd4577",
            "/DNOGDI",
            "/UTF_COMPILE_LIBRARY",
        ],
        "//conditions:default": ["-pthread", CPLUSPLUS_VERSION, D_GLIBCXX_USE_CXX11_ABI],
    })

    native.cc_binary(
        name = name,
        srcs = srcs,
        copts = copts,
        linkshared = 1,
        features = select({
            "//tensorflow_addons:windows": ["windows_export_all_symbols"],
            "//conditions:default": [],
        }),
        deps = deps,
        **kwargs
    )
