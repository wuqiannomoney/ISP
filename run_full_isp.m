%% RUN_FULL_ISP  全流程 ISP 跑图入口（当前配置：跳过 Raw 3DNR、Raw BNR、LTM，直出单帧进后端）
clear; clc; close all;

root_dir = fileparts(mfilename('fullpath'));
jdef_dir = fullfile(root_dir, 'UniPyr-JDE');
dump_dir = fullfile(root_dir, 'dumps');
addpath(root_dir);
addpath(jdef_dir);

% === 1. 配置路径与要测试的场景 ===
crvd_root = 'D:\mydata\code\matlab\datasets\CRVD';
sensor_name     = 'crvd_imx385'; % 自动加载 UniPyr-JDE/calibrated_profiles/crvd_imx385.mat
target_iso      = 3200;          % 指定要测试的 ISO 档位
target_scene    = 'scene11';      % 指定要测试的场景名 (留空则取第一个匹配的)
target_noisy_id = 3;             % CRVD noisy 序号 (如 noisy0)

% === 2. 模块使能开关（全部设为 false 表示只跑 BLC->Demosaic->AWB/CCM->Gamma->UniPyr-JDE）===
cfg_isp.enable_raw_3dnr  = false;
cfg_isp.enable_raw_bnr   = false;
cfg_isp.enable_ltm       = false;
cfg_isp.save_dump        = true;  % 保存后端前一步的数据到 dumps/
cfg_isp.only_first_frame = true;  % 未开 3DNR 时仅跑第 1 帧即可快速看结果

% 扫描 CRVD 并筛选目标序列
items = isp_io.scan_crvd_dataset(crvd_root);
mask = ([items.iso] == target_iso) & ([items.noisy_id] == target_noisy_id);
if ~isempty(target_scene)
    mask = mask & strcmp({items.scene_name}, target_scene);
end
seq = items(mask);
if isempty(seq), error('未找到匹配 ISO=%d, scene=%s 的序列！', target_iso, target_scene); end

if ~cfg_isp.enable_raw_3dnr && cfg_isp.only_first_frame
    seq = seq(1);
end

% 加载前端 Raw 标定参数（当开启 Raw 3DNR 或 Raw BNR 时使用）
cal_file = fullfile(jdef_dir, 'calibrated_profiles', [sensor_name '.mat']);
if exist(cal_file, 'file')
    S = load(cal_file, 'cal_db');
    iso_q = min(max(target_iso, S.cal_db.iso_list(1)), S.cal_db.iso_list(end));
    a_raw = interp1(S.cal_db.iso_list, S.cal_db.a_raw, iso_q, 'linear');
    b_raw = interp1(S.cal_db.iso_list, S.cal_db.b_raw, iso_q, 'linear');
else
    if cfg_isp.enable_raw_3dnr || cfg_isp.enable_raw_bnr
        warning('未找到标定文件 %s，Raw 域暂用默认估算参数，建议先运行 run_crvd_calibration！', cal_file);
    end
    a_raw = 3.5e-3; b_raw = 8.8e-6;
end

[x_lut, gamma_lut] = config.gamma_curves('srgb', 1024);
state_3dnr = [];

%% 3. 逐帧运行全流 ISP
for f = 1:numel(seq)
    it = seq(f);
    fprintf('\n--- 处理第 %d/%d 帧: %s | ISO=%d | frame%d ---\n', ...
        f, numel(seq), it.scene_name, it.iso, it.frame_id);

    raw_n = isp_io.read_crvd_tiff(it.noisy_path);
    raw_blc = isp_raw.apply_blc(raw_n, it.bl, it.wl);

    % (1) Raw 3DNR (若跳过则置 W_eff = 0)
    if cfg_isp.enable_raw_3dnr
        [raw_3d, W_eff, state_3dnr] = isp_raw.apply_raw_3dnr(raw_blc, state_3dnr, a_raw, b_raw);
    else
        raw_3d = raw_blc;
        W_eff  = zeros(size(raw_blc));
    end

    % (2) Raw 空域 BNR (若跳过则直接截断负值)
    if cfg_isp.enable_raw_bnr
        raw_bnr = isp_raw.apply_raw_bnr(raw_3d, W_eff, a_raw, b_raw, 4.0, 2.0);
    else
        raw_bnr = max(raw_3d, 0);
    end

    % (3) 去马赛克 + AWB + CCM (若有 GT 则由 GT 锁同组 WB 以便对齐)
    rgb_dem = isp_color.apply_demosaic(raw_bnr, it.bayer_pattern);
    if ~isempty(it.gt_path)
        raw_gt = max(isp_raw.apply_blc(isp_io.read_crvd_tiff(it.gt_path), it.bl, it.wl), 0);
        rgb_gt_dem = isp_color.apply_demosaic(raw_gt, it.bayer_pattern);
        [rgb_gt_lin, wb_gain, ccm] = isp_color.apply_awb_ccm(rgb_gt_dem, [], []);
        [rgb_lin, ~, ~]            = isp_color.apply_awb_ccm(rgb_dem, wb_gain, ccm);
    else
        [rgb_lin, wb_gain, ccm] = isp_color.apply_awb_ccm(rgb_dem, [], []);
        rgb_gt_lin = [];
    end

    % (4) 线性域对数 LTM (若跳过则 G_LTM 全为 1) + Gamma
    if cfg_isp.enable_ltm
        [rgb_ltm_lin, G_LTM] = isp_tone.apply_log_ltm(rgb_lin);
    else
        rgb_ltm_lin = rgb_lin;
        G_LTM       = ones(size(rgb_lin, 1), size(rgb_lin, 2));
    end
    RGB_gamma = isp_tone.apply_gamma(rgb_ltm_lin, x_lut, gamma_lut);

    if ~isempty(rgb_gt_lin)
        if cfg_isp.enable_ltm
            [rgb_gt_ltm, ~] = isp_tone.apply_log_ltm(rgb_gt_lin, G_LTM);
        else
            rgb_gt_ltm = rgb_gt_lin;
        end
        RGB_gt_gamma = isp_tone.apply_gamma(rgb_gt_ltm, x_lut, gamma_lut);
    else
        RGB_gt_gamma = [];
    end

    % (5) 保存进入后端前一步的 Dump 数据（方便后续秒级单独调优后端）
    meta.iso         = it.iso;
    meta.scene_name  = it.scene_name;
    meta.frame_id    = it.frame_id;
    meta.sensor_name = sensor_name;
    meta.wb_gain     = wb_gain;
    meta.has_3dnr    = cfg_isp.enable_raw_3dnr;
    meta.has_ltm     = cfg_isp.enable_ltm;
    if cfg_isp.save_dump
        dp = isp_io.save_backend_dump(dump_dir, it.scene_name, RGB_gamma, RGB_gt_gamma, ...
                                      W_eff, G_LTM, x_lut, gamma_lut, meta);
        fprintf('已保存后端前一步 Dump: %s\n', dp);
    end

    % (6) 送入后端 UniPyr-JDE（自动按当前帧 ISO 读取标定库）
    cfg_jde = config.default_cfg(it.iso, sensor_name);
    if ~cfg_isp.enable_raw_3dnr, cfg_jde.max_3dnr_gain = 1.0; end

    tic;
    [RGB_out, dbg] = uni_pyr_jde_process(RGB_gamma, W_eff, G_LTM, x_lut, gamma_lut, cfg_jde);
    fprintf('UniPyr-JDE 耗时: %.1f ms\n', toc * 1000);

    % 最后一帧展示完整对比视图与指标
    if f == numel(seq)
        if ~isempty(RGB_gt_gamma)
            roi.dark_flat = (0.25*RGB_gt_gamma(:,:,1) + 0.5*RGB_gt_gamma(:,:,2) + 0.25*RGB_gt_gamma(:,:,3)) < 0.25;
            m = utils.calc_iq_metrics(RGB_gamma, RGB_out, RGB_gt_gamma, roi);
            fprintf('指标: PSNR %.2f -> %.2f dB | SSIM %.4f -> %.4f | 暗部噪声下降 %.1f%%\n', ...
                m.psnr_in, m.psnr_out, m.ssim_in, m.ssim_out, m.dark_noise_drop_pct);
        end
        utils.visualize_pipeline(RGB_gamma, RGB_out, dbg, RGB_gt_gamma);
    end
    figure,imshow(RGB_gamma);
    figure,imshow(RGB_out);
    figure,imshow(RGB_gt_gamma);
end