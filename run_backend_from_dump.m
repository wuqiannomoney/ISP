%% RUN_BACKEND_FROM_DUMP  直接读取保存的后端前一步 Dump (.mat)，跳过前级快速调优 UniPyr-JDE
clear; clc; close all;

root_dir = fileparts(mfilename('fullpath'));
jdef_dir = fullfile(root_dir, 'UniPyr-JDE');
dump_dir = fullfile(root_dir, 'dumps');
addpath(root_dir);
addpath(jdef_dir);

% 1. 自动选择 dumps/ 下最新的 .mat 文件（或手动指定路径）
files = dir(fullfile(dump_dir, 'dump_*.mat'));
if isempty(files), error('dumps 目录下暂无文件，请先运行 run_full_isp.m！'); end
[~, idx] = max([files.datenum]);
dump_path = fullfile(dump_dir, files(idx).name);
fprintf('正在加载 Dump 文件: %s\n', dump_path);

load(dump_path, 'RGB_gamma', 'RGB_gt_gamma', 'W_eff', 'G_LTM', 'x_lut', 'gamma_lut', 'meta');

% 2. 按该帧自带的 ISO 自动加载 UniPyr-JDE 标定库，并可在此自由微调后端参数
cfg = config.default_cfg(meta.iso, meta.sensor_name);
if isfield(meta, 'has_3dnr') && ~meta.has_3dnr
    cfg.max_3dnr_gain = 1.0;
end

% --- 你可以在这里秒级调试后端降噪与增强参数 ---
% cfg.gf_k = [2.2, 2.8, 3.5];
% cfg.alpha_c = [1.6, 2.8, 3.6];
% cfg.base_gain_l = [1.55, 1.35, 1.18];
% ----------------------------------------------

tic;
[RGB_out, dbg] = uni_pyr_jde_process(RGB_gamma, W_eff, G_LTM, x_lut, gamma_lut, cfg);
fprintf('后端单独仿真完成 (ISO=%d)，耗时: %.1f ms\n', meta.iso, toc * 1000);

if ~isempty(RGB_gt_gamma)
    roi.dark_flat = (0.25*RGB_gt_gamma(:,:,1) + 0.5*RGB_gt_gamma(:,:,2) + 0.25*RGB_gt_gamma(:,:,3)) < 0.25;
    m = utils.calc_iq_metrics(RGB_gamma, RGB_out, RGB_gt_gamma, roi);
    fprintf('指标对比: PSNR %.2f -> %.2f dB | SSIM %.4f -> %.4f | 暗部噪声下降 %.1f%%\n', ...
        m.psnr_in, m.psnr_out, m.ssim_in, m.ssim_out, m.dark_noise_drop_pct);
end

utils.visualize_pipeline(RGB_gamma, RGB_out, dbg, RGB_gt_gamma);