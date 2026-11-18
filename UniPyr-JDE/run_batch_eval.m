%% RUN_BATCH_EVAL  多 ISO 档位自动化批量评测脚本
clear; clc; close all;
addpath(pwd);

iso_list = [100, 400, 1600, 3200, 6400];
[x_lut, gamma_lut] = config.gamma_curves('srgb', 1024);
[RGB_clean_lin, mask_obj, roi] = sim_frontend.gen_test_scene(480, 640);

fprintf('%-8s | %-10s | %-10s | %-10s | %-10s | %-14s | %-8s\n', ...
    'ISO', 'PSNR_In', 'PSNR_Out', 'SSIM_In', 'SSIM_Out', 'DarkNoiseDrop', 'Time(ms)');
fprintf('%s\n', repmat('-', 1, 86));

for k = 1:numel(iso_list)
    rng(42);
    iso = iso_list(k);
    cfg = config.default_cfg(iso, 'default_cmos');
    [RGB_gamma, W_eff, G_LTM, RGB_gt_gamma] = sim_frontend.sim_3dnr_ltm_gamma( ...
        RGB_clean_lin, mask_obj, x_lut, gamma_lut, cfg);

    tic;
    [RGB_out, ~] = uni_pyr_jde_process(RGB_gamma, W_eff, G_LTM, x_lut, gamma_lut, cfg);
    t_ms = toc * 1000;

    m = utils.calc_iq_metrics(RGB_gamma, RGB_out, RGB_gt_gamma, roi);
    fprintf('%-8d | %-10.2f | %-10.2f | %-10.4f | %-10.4f | %-13.1f%% | %-8.1f\n', ...
        iso, m.psnr_in, m.psnr_out, m.ssim_in, m.ssim_out, m.dark_noise_drop_pct, t_ms);
end