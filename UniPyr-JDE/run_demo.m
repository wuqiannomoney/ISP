%% RUN_DEMO  UniPyr-JDE 单张场景快速调试与可视化入口
clear; clc; close all;
addpath(pwd);
rng(42);

% 1. 加载配置、传感器标定与 Gamma 曲线
iso = 1600;
cfg = config.default_cfg(iso, 'default_cmos');
[x_lut, gamma_lut] = config.gamma_curves('srgb', 1024);

% 2. 构造仿真场景并模拟前级输出 (接真实数据时可跳过此模块)
[RGB_clean_lin, mask_obj, roi] = sim_frontend.gen_test_scene(480, 640);
[RGB_gamma, W_eff, G_LTM, RGB_gt_gamma] = sim_frontend.sim_3dnr_ltm_gamma( ...
    RGB_clean_lin, mask_obj, x_lut, gamma_lut, cfg);

% 3. 运行 UniPyr-JDE 核心引擎
tic;
[RGB_out, dbg] = uni_pyr_jde_process(RGB_gamma, W_eff, G_LTM, x_lut, gamma_lut, cfg);
elapsed_ms = toc * 1000;

% 4. 计算客观指标与展示可视化视图
metrics = utils.calc_iq_metrics(RGB_gamma, RGB_out, RGB_gt_gamma, roi);
fprintf('=== UniPyr-JDE 运行完成 (ISO %d, 耗时 %.1f ms) ===\n', iso, elapsed_ms);
fprintf('PSNR: 输入 %.2f dB -> 输出 %.2f dB\n', metrics.psnr_in, metrics.psnr_out);
fprintf('SSIM: 输入 %.4f -> 输出 %.4f\n', metrics.ssim_in, metrics.ssim_out);
fprintf('暗部平坦区噪声 Std: %.4f -> %.4f (下降 %.1f%%)\n', ...
    metrics.dark_noise_in, metrics.dark_noise_out, metrics.dark_noise_drop_pct);

utils.visualize_pipeline(RGB_gamma, RGB_out, dbg, RGB_gt_gamma);